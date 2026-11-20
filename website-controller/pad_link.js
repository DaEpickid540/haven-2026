// host
import {
  auth, db, ready, ref, child, set, remove, onValue, onDisconnect, PAIRS, RELAY, ICE, gathered,
} from "./firebase.js";

const ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 5;
const LIFETIME = 10 * 60 * 1000;
const QR_LIB = "https://cdn.jsdelivr.net/npm/qrcode-generator@1.4.4/+esm";
// stable
const CONTROLLER_URL = "https://deathbounce.web.app/controller.html";

// bridge
const link = (window.padLink = {
  buttons: 0,
  connected: false,
  prompt: "null",
  choices: [],
  takeChoice() {
    return this.choices.length ? this.choices.shift() : "";
  },
  sendPrompt(text) {
    this.prompt = text;
    if (channel && channel.readyState === "open") channel.send(text);
    if (relay) set(child(relay, "prompt"), text).catch(() => {});
  },
});

let channel = null;
let relay = null;

// overlay
const box = document.createElement("div");
box.id = "pad-code";
box.innerHTML = `
  <style>
    @font-face { font-family: PadPixel; src: url("fonts/PressStart2P-Regular.ttf"); }
    #pad-code { position: fixed; right: 12px; top: 50%; transform: translateY(-50%); z-index: 10;
      box-sizing: border-box; width: 188px; padding: 18px 12px 10px; background: #212b5ecc; color: #fff;
      font: 8px/1.6 PadPixel, monospace; border: 2px solid #fff; border-radius: 4px;
      text-align: center; overflow-wrap: anywhere; pointer-events: auto; }
    #pad-code b { display: block; font-size: 18px; letter-spacing: 3px; margin-right: -3px; }
    #pad-code button { all: unset; cursor: pointer; position: absolute; top: 4px; left: 8px; }
    #pad-qr { display: block; margin: 6px auto; max-width: 100%;
      image-rendering: pixelated; background: #fff; }
    #pad-code[hidden], #pad-qr[hidden] { display: none; }
  </style>
  <button type="button" aria-label="Hide">x</button>
  <span id="pad-status">Phone pad: connecting...</span>
  <img id="pad-qr" alt="Scan to join" hidden>
  <b id="pad-value"></b>
  <span>${CONTROLLER_URL.replace("https://", "").replace("/", "/<wbr>")}</span>`;
document.body.appendChild(box);
box.querySelector("button").onclick = () => (box.hidden = true);
const statusEl = box.querySelector("#pad-status");
const valueEl = box.querySelector("#pad-value");
const qrEl = box.querySelector("#pad-qr");

// qr
const qrLib = import(QR_LIB).then((m) => m.default).catch(() => null);

async function showQr(code) {
  const url = new URL(CONTROLLER_URL);
  url.search = `?code=${code}`;
  const qrcode = await qrLib;
  if (!qrcode || valueEl.textContent !== code) return;
  const qr = qrcode(0, "M");
  qr.addData(url.href);
  qr.make();
  qrEl.src = qr.createDataURL(3, 2);
  qrEl.hidden = false;
}

function randomCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(CODE_LENGTH));
  return Array.from(bytes, (b) => ALPHABET[b % ALPHABET.length]).join("");
}

// claim
async function publish(offer) {
  for (let tries = 0; tries < 5; tries++) {
    const code = randomCode();
    const node = ref(db, `${PAIRS}/${code}`);
    try {
      await set(node, { hostUid: auth.currentUser.uid, offer, expiresAt: Date.now() + LIFETIME });
      onDisconnect(node).remove();
      return { code, node };
    } catch {
      // taken
    }
  }
  throw new Error("No free pairing code");
}

async function host() {
  link.connected = false;
  link.buttons = 0;
  const pc = new RTCPeerConnection(ICE);
  channel = pc.createDataChannel("pad");
  channel.binaryType = "arraybuffer";

  let node = null;
  let spot = null;
  let relayOn = false;
  let keep = 0;
  let expiry = 0;
  let stopAnswer = () => {};
  let stopRelay = () => {};
  let restarted = false;
  const restart = () => {
    if (restarted) return;
    restarted = true;
    clearTimeout(expiry);
    clearInterval(keep);
    stopAnswer();
    stopRelay();
    if (node) remove(node).catch(() => {});
    if (spot) remove(spot).catch(() => {});
    if (relay === spot) relay = null;
    pc.close();
    setTimeout(start, 1000);
  };

  channel.onopen = () => {
    link.connected = true;
    stopAnswer();
    if (node) remove(node).catch(() => {});
    node = null;
    channel.send(link.prompt);
    statusEl.textContent = "Phone pad connected";
    valueEl.textContent = "";
    qrEl.hidden = true;
    box.hidden = true;
  };
  channel.onmessage = (e) => {
    if (typeof e.data === "string") link.choices.push(e.data);
    else {
      const data = new Uint8Array(e.data);
      link.buttons = (data[0] || 0) | ((data[3] || 0) << 8);
    }
  };
  channel.onclose = () => {
    if (relayOn) return;
    box.hidden = false;
    restart();
  };
  pc.onconnectionstatechange = () => {
    if (pc.connectionState === "failed" && !relayOn) restart();
  };

  await pc.setLocalDescription(await pc.createOffer());
  await gathered(pc);
  const claimed = await publish(pc.localDescription.sdp);
  node = claimed.node;
  statusEl.textContent = "Scan or enter code";
  valueEl.textContent = claimed.code;
  qrEl.hidden = true;
  showQr(claimed.code);

  // relay
  const mine = ref(db, `${RELAY}/${claimed.code}`);
  try {
    await set(mine, { hostUid: auth.currentUser.uid, expiresAt: Date.now() + LIFETIME, prompt: link.prompt });
    onDisconnect(mine).remove();
    spot = relay = mine;
    keep = setInterval(() => {
      set(child(mine, "expiresAt"), Date.now() + LIFETIME).catch(() => {});
    }, LIFETIME / 2);
    const stopPad = onValue(child(mine, "pad"), (snap) => {
      if (snap.exists()) {
        link.buttons = snap.val();
        if (relayOn) return;
        relayOn = true;
        link.connected = true;
        statusEl.textContent = "Phone pad connected";
        valueEl.textContent = "";
        qrEl.hidden = true;
        box.hidden = true;
      } else if (relayOn) {
        relayOn = false;
        if (channel.readyState === "open") return;
        box.hidden = false;
        restart();
      }
    });
    const stopChoice = onValue(child(mine, "choice"), (snap) => {
      const pick = snap.val();
      if (typeof pick === "string") link.choices.push(pick.slice(pick.indexOf(":") + 1));
    });
    stopRelay = () => {
      stopPad();
      stopChoice();
    };
  } catch {
    // direct
  }

  expiry = setTimeout(() => {
    if (!link.connected) restart();
  }, LIFETIME - 5000);

  stopAnswer = onValue(child(node, "answer"), (snap) => {
    if (!snap.exists() || pc.signalingState !== "have-local-offer") return;
    stopAnswer();
    pc.setRemoteDescription({ type: "answer", sdp: snap.val() }).catch(restart);
  });
}

function start() {
  ready.then(host).catch((err) => {
    console.warn("Pad pairing unavailable:", err);
    statusEl.textContent = "Phone pad unavailable";
  });
}

start();
