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

const GAME_URL = location.protocol === "https:"
  ? `wss://${location.host}/ws`
  : `ws://${location.hostname || "localhost"}:5512`;

const link = document.querySelector("#link");
const linkLabel = document.querySelector("#link-label");

let socket = null;
let packet = new Uint8Array(3);

function setLink(mode, label) {
  link.dataset.state = mode;
  linkLabel.textContent = label;
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

function sendState(state) {
  const bits = BITS.reduce((acc, name, i) => acc | (state[name] << i), 0);
  const next = new Uint8Array([
    bits,
    Math.round(state.x * 127),
    Math.round(state.y * 127),
  ]);
  if (next.join() === packet.join()) return;
  packet = next;
  if (socket.readyState === WebSocket.OPEN) {
    socket.send(packet);
  }
}

function sendChoice(index) {
  if (socket.readyState === WebSocket.OPEN) {
    socket.send(String(index));
  }
}

connect();
