const BITS = [
  "left",
  "right",
  "up",
  "down",
  "attack",
  "dash",
  "interact",
  "pause",
];

const params = new URLSearchParams(location.search);
const PAIRING = /\.(web\.app|firebaseapp\.com)$/.test(location.hostname) || params.has("pair") || params.has("code");

const GAME_URL = location.protocol === "https:"
  ? `wss://${location.host}/ws`
  : `ws://${location.hostname || "localhost"}:5512`;

const link = document.querySelector("#link");
const linkLabel = document.querySelector("#link-label");

let socket = null;
let channel = null;
let relay = null;
let packet = new Uint8Array(3);
const FALLBACK = 3000;

function setLink(mode, label) {
  link.dataset.state = mode;
  linkLabel.textContent = label;
}

function send(data) {
  if (channel && channel.readyState === "open") {
    channel.send(data);
  } else if (relay) {
    relaySend(data);
  } else if (socket && socket.readyState === WebSocket.OPEN) {
    socket.send(data);
  }
}

function connect() {
  socket = new WebSocket(GAME_URL);
  socket.onopen = () => {
    setLink("on", "Connected");
    socket.send(packet);
  };
  socket.onmessage = (e) => showPrompt(JSON.parse(e.data));
  socket.onclose = () => {
    setLink("connecting", "Searching");
    showPrompt(null);
    setTimeout(connect, 1000);
  };
}

// pairing
const pairForm = document.querySelector("#pair");
const pairInput = document.querySelector("#pair-code");
const pairMsg = document.querySelector("#pair-msg");

function askCode(message) {
  setLink("connecting", "Not paired");
  showPrompt(null);
  pairMsg.textContent = message;
  pairForm.hidden = false;
  pairInput.focus();
}

// relay
function relaySend(data) {
  const { fb, spot, pad } = relay;
  if (typeof data === "string") {
    fb.set(fb.child(spot, "choice"), `${++relay.picks}:${data}`).catch(() => {});
  } else if (data[0] !== relay.sent) {
    relay.sent = data[0];
    fb.set(pad, data[0]).catch(() => {});
  }
}

async function openRelay(fb, code) {
  if (relay) return true;
  const spot = fb.ref(fb.db, `${fb.RELAY}/${code}`);
  const pad = fb.child(spot, "pad");
  const sent = packet[0];
  try {
    await fb.set(pad, sent);
  } catch {
    return false;
  }
  if (relay) return true;
  fb.onDisconnect(pad).remove();
  const mine = (relay = { fb, spot, pad, sent, picks: 0 });
  const stop = fb.onValue(spot, (snap) => {
    if (relay !== mine) return stop();
    const direct = channel && channel.readyState === "open";
    const room = snap.val();
    if (!room || !room.hostUid) {
      relay = null;
      stop();
      if (!direct) askCode("Disconnected");
    } else if (!direct && room.prompt !== mine.shown) {
      mine.shown = room.prompt;
      showPrompt(JSON.parse(room.prompt || "null"));
    }
  });
  if (!(channel && channel.readyState === "open")) setLink("on", "Connected");
  relaySend(packet);
  return true;
}

async function join(code) {
  const fb = await import("./firebase.js");
  await fb.ready;
  const node = fb.ref(fb.db, `${fb.PAIRS}/${code}`);
  const snap = await fb.get(node);
  const pair = snap.val();
  if (!pair || pair.answer || pair.expiresAt < Date.now()) {
    throw new Error("Code not found");
  }

  const pc = new RTCPeerConnection(fb.ICE);
  let falling = false;
  pc.ondatachannel = (e) => {
    channel = e.channel;
    channel.binaryType = "arraybuffer";
    channel.onopen = () => {
      setLink("on", "Connected");
      channel.send(packet);
    };
    channel.onmessage = (msg) => showPrompt(JSON.parse(msg.data));
    channel.onclose = () => {
      channel = null;
      pc.close();
      if (relay) relaySend(packet);
      else if (!falling) askCode("Disconnected");
    };
  };
  pc.onconnectionstatechange = () => {
    if (pc.connectionState === "failed") {
      falling = true;
      pc.close();
      openRelay(fb, code).then((ok) => ok || askCode("Couldn't reach the game"));
    }
  };

  await pc.setRemoteDescription({ type: "offer", sdp: pair.offer });
  await pc.setLocalDescription(await pc.createAnswer());
  await fb.gathered(pc);
  await fb.set(fb.child(node, "answer"), pc.localDescription.sdp);
  setTimeout(() => {
    if (!(channel && channel.readyState === "open")) openRelay(fb, code);
  }, FALLBACK);
}

pairForm.onsubmit = (e) => {
  e.preventDefault();
  const code = pairInput.value.trim().toUpperCase();
  if (code.length !== 5) return;
  pairForm.hidden = true;
  setLink("connecting", "Pairing");
  join(code).catch((err) => askCode(err.message === "Code not found" ? "Code not found" : "Pairing failed"));
};

function sendState(state) {
  const bits = BITS.reduce((acc, name, i) => acc | (state[name] << i), 0);
  const next = new Uint8Array([
    bits,
    Math.round(state.x * 127),
    Math.round(state.y * 127),
  ]);
  if (next.join() === packet.join()) return;
  packet = next;
  send(packet);
}

function sendChoice(index) {
  send(String(index));
}

if (PAIRING) {
  pairInput.value = (params.get("code") || "").toUpperCase();
  addEventListener("DOMContentLoaded", () => {
    if (pairInput.value.length === 5) pairForm.requestSubmit();
    else askCode("Shown on the game screen");
  });
} else {
  connect();
}
