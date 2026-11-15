// personal-suite
import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.5/firebase-app.js";
import { getAuth, signInAnonymously } from "https://www.gstatic.com/firebasejs/10.12.5/firebase-auth.js";
import {
  getDatabase, ref, child, get, set, remove, onValue, onDisconnect,
} from "https://www.gstatic.com/firebasejs/10.12.5/firebase-database.js";

const app = initializeApp({
  apiKey: "AIzaSyAtRLYEN30W1eL4EwiRGN4x_oOzI-HlJZQ",
  authDomain: "personal-suite-ca587.firebaseapp.com",
  databaseURL: "https://personal-suite-ca587-default-rtdb.firebaseio.com",
  projectId: "personal-suite-ca587",
  appId: "1:894530323591:web:7eaa581c5d2b4474fc6422",
});

export const auth = getAuth(app);
export const db = getDatabase(app);
export const ready = signInAnonymously(auth);
export { ref, child, get, set, remove, onValue, onDisconnect };

export const PAIRS = "deathbounce/pairs";
export const ICE = { iceServers: [{ urls: "stun:stun.l.google.com:19302" }] };

// gather
export function gathered(pc) {
  if (pc.iceGatheringState === "complete") return Promise.resolve();
  return new Promise((done) => {
    const timer = setTimeout(done, 4000);
    pc.addEventListener("icegatheringstatechange", () => {
      if (pc.iceGatheringState === "complete") {
        clearTimeout(timer);
        done();
      }
    });
  });
}
