// host
import {
  auth, db, ready, ref, child, set, remove, onValue, onDisconnect, PAIRS, ICE, gathered,
} from "./firebase.js";

const ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 5;
const LIFETIME = 10 * 60 * 1000;

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
  },
});

let channel = null;

// overlay
const box = document.createElement("div");
box.id = "pad-code";
box.innerHTML = `
  <style>
    @font-face { font-family: PadPixel; src: url("fonts/PressStart2P-Regular.ttf"); }
    #pad-code { position: fixed; right: 12px; bottom: 12px; z-index: 10; padding: 10px 12px;
      background: #212b5ecc; color: #fff; font: 10px/1.6 PadPixel, monospace; border: 2px solid #fff;
      border-radius: 4px; text-align: right; pointer-events: auto; }
    #pad-code b { display: block; font-size: 18px; letter-spacing: 3px; }
    #pad-code button { all: unset; cursor: pointer; position: absolute; top: 2px; left: 6px; }
    #pad-code[hidden] { display: none; }
  </style>
  <button type="button" aria-label="Hide">x</button>
  <span id="pad-status">Phone pad: connecting...</span>
  <b id="pad-value"></b>
  <span>${location.host}/controller.html</span>`;
document.body.appendChild(box);
box.querySelector("button").onclick = () => (box.hidden = true);
const statusEl = box.querySelector("#pad-status");
const valueEl = box.querySelector("#pad-value");

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
  let expiry = 0;
  let stopAnswer = () => {};
  let restarted = false;
  const restart = () => {
    if (restarted) return;
    restarted = true;
    clearTimeout(expiry);
    stopAnswer();
    if (node) remove(node).catch(() => {});
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
    box.hidden = true;
  };
  channel.onmessage = (e) => {
    if (typeof e.data === "string") link.choices.push(e.data);
    else link.buttons = new Uint8Array(e.data)[0] || 0;
  };
  channel.onclose = () => {
    box.hidden = false;
    restart();
  };
  pc.onconnectionstatechange = () => {
    if (pc.connectionState === "failed") restart();
  };

  await pc.setLocalDescription(await pc.createOffer());
  await gathered(pc);
  const claimed = await publish(pc.localDescription.sdp);
  node = claimed.node;
  statusEl.textContent = "Phone pad code";
  valueEl.textContent = claimed.code;

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
