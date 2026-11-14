const DEADZONE = 0.3;
const DIAGONAL = 0.383;
const TRAVEL = 0.27;

const state = {
  x: 0,
  y: 0,
  left: false,
  right: false,
  up: false,
  down: false,
  attack: false,
  dash: false,
  interact: false,
  pause: false,
};

const zone = document.querySelector("#stick-zone");
const gate = document.querySelector("#gate");
const knob = document.querySelector("#knob");
const arrows = document.querySelectorAll(".arrow");
const buttons = document.querySelectorAll("[data-btn]");
const fsBtn = document.querySelector("#fs-btn");
const promptEl = document.querySelector("#prompt");
const promptPanel = document.querySelector(".prompt-panel");
const promptLines = document.querySelector("#prompt-lines");
const promptButtons = document.querySelector("#prompt-buttons");

function update() {
  knob.style.setProperty("--sx", state.x);
  knob.style.setProperty("--sy", state.y);
  for (const el of arrows) {
    el.classList.toggle("on", state[el.dataset.dir]);
  }
  for (const el of buttons) {
    el.classList.toggle("is-down", state[el.dataset.btn]);
  }
  sendState(state);
}

function markLast(el) {
  document.querySelector(".last")?.classList.remove("last");
  el.classList.add("last");
}

let stickPointer = null;

function setStick(x, y) {
  const mag = Math.hypot(x, y);
  if (mag > 1) {
    x /= mag;
    y /= mag;
  }
  const lean = mag > DEADZONE ? Math.min(mag, 1) * DIAGONAL : Infinity;
  Object.assign(state, {
    x,
    y,
    left: x < -lean,
    right: x > lean,
    up: y < -lean,
    down: y > lean,
  });
  update();
}

function stickTo(e) {
  const r = gate.getBoundingClientRect();
  const reach = r.width * TRAVEL;
  setStick(
    (e.clientX - (r.left + r.width / 2)) / reach,
    (e.clientY - (r.top + r.height / 2)) / reach,
  );
}

function releaseStick(e) {
  if (e.pointerId !== stickPointer) return;
  stickPointer = null;
  zone.classList.remove("held");
  setStick(0, 0);
}

zone.addEventListener("pointerdown", (e) => {
  if (stickPointer !== null) return;
  stickPointer = e.pointerId;
  zone.setPointerCapture(e.pointerId);
  zone.classList.add("held");
  markLast(gate);
  stickTo(e);
});
zone.addEventListener("pointermove", (e) => {
  if (e.pointerId === stickPointer) {
    stickTo(e);
  }
});
zone.addEventListener("pointerup", releaseStick);
zone.addEventListener("pointercancel", releaseStick);

for (const el of buttons) {
  const press = (down) => {
    state[el.dataset.btn] = down;
    update();
  };
  el.addEventListener("pointerdown", (e) => {
    el.setPointerCapture(e.pointerId);
    markLast(el);
    navigator.vibrate?.(12);
    press(true);
  });
  el.addEventListener("pointerup", () => press(false));
  el.addEventListener("pointercancel", () => press(false));
}

fsBtn.hidden = !document.fullscreenEnabled;
fsBtn.addEventListener("pointerdown", () => markLast(fsBtn));
fsBtn.addEventListener("click", async () => {
  if (document.fullscreenElement) return document.exitFullscreen();
  await document.documentElement.requestFullscreen();
  screen.orientation.lock?.("landscape").catch(() => {});
});

function label(line) {
  const el = document.createElement("p");
  el.className = line.style;
  el.textContent = line.text;
  return el;
}

function showPrompt(menu) {
  promptEl.hidden = !menu;
  if (!menu) return;
  promptEl.dataset.panel = menu.panel;
  promptPanel.style.width = menu.panel ? `calc(var(--px) * ${menu.width})` : "";
  promptPanel.style.height = menu.panel ? `calc(var(--px) * ${menu.height})` : "";
  promptLines.replaceChildren(...menu.lines.map(label));
  promptButtons.replaceChildren(...menu.buttons.map((button, index) => {
    const el = document.createElement("button");
    el.textContent = button.text;
    el.disabled = button.disabled;
    el.classList.toggle("focus", button.focused);
    el.style.width = `calc(var(--px) * ${button.width})`;
    el.onclick = () => sendChoice(index);
    if (button.labels.length === 0) return el;
    const row = document.createElement("div");
    row.className = "row";
    row.append(...button.labels.map(label), el);
    return row;
  }));
}

function keepAwake() {
  navigator.wakeLock?.request("screen").catch(() => {});
}
keepAwake();
document.addEventListener("visibilitychange", keepAwake);

document.addEventListener("contextmenu", (e) => e.preventDefault());
