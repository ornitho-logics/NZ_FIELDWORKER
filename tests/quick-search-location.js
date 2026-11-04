// Browser behavior with invented coordinates; run with node.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

let now = 100000;
let cell = null;
let visible = true;
let refresh;
let tick;
let success;
let failure;
let watches = 0;
let clears = 0;
const events = {};
const document = {
  readyState: "complete",
  hidden: false,
  getElementById: () => ({querySelector: () => cell}),
  addEventListener: (name, handler) => {events[name] = handler;}
};
const window = {
  addEventListener: (name, handler) => {events[name] = handler;},
  setInterval: handler => {tick = handler;},
  jQuery: () => ({on: (names, handler) => {
    names.split(" ").forEach(name => {events[name] = handler;});
  }})
};
const navigator = {geolocation: {
  watchPosition: (onSuccess, onError) => {
    watches += 1;
    success = onSuccess;
    failure = onError;
    return watches;
  },
  clearWatch: () => {clears += 1;}
}};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, "../main/www/quick_search_location.js"), "utf8"), {
  document, window, navigator, Date: {now: () => now},
  MutationObserver: class {constructor(handler) {refresh = handler;} observe() {}}
});
assert.equal(watches, 0, "No nest means no location request");
function nest(lat, lon) {
  return {
    textContent: "—",
    getClientRects: () => visible ? [{}] : [],
    getAttribute: name => name === "data-nest-lat" ? lat : lon
  };
}
function fix(lat, lon, timestamp = now) {
  success({coords: {latitude: lat, longitude: lon}, timestamp});
}
cell = nest("0", "0.001");
refresh();
assert.equal(watches, 1);
fix(0, 0);
assert.equal(cell.textContent, "111 m");
cell = nest("0", "0.02");
refresh();
assert.equal(cell.textContent, "2.22 km", "Changing nests recalculates distance");
assert.equal(watches, 1, "Rendering does not create duplicate watches");
fix(0, 0.02);
assert.equal(cell.textContent, "0 m");
now += 16000;
tick();
assert.equal(cell.textContent, "—", "Old device fixes expire");
fix(0, 0);
failure({code: 1});
assert.equal(cell.textContent, "—", "Permission and GPS errors clear the distance");
fix(91, 0);
assert.equal(cell.textContent, "—", "Invalid coordinates never produce a distance");
const oldSuccess = success;
document.hidden = true;
events.visibilitychange();
assert.equal(clears, 1);
document.hidden = false;
events.visibilitychange();
assert.equal(watches, 2);
oldSuccess({coords: {latitude: 0, longitude: 0}, timestamp: now});
assert.equal(cell.textContent, "—", "Stopped watches cannot publish late positions");
fix(0, 0);
visible = false;
events["hidden.bs.tab"]();
assert.equal(clears, 2);
assert.equal(cell.textContent, "—");
visible = true;
cell = nest(null, null);
events["shown.bs.tab"]();
assert.equal(watches, 2, "Missing coordinates do not trigger GPS");
cell = nest("0", "0.001");
refresh();
fix(0, 0);
events["shiny:disconnected"]();
assert.equal(cell.textContent, "—");
assert.equal(clears, 3);
events["shiny:connected"]();
assert.equal(watches, 4);
cell = null;
refresh();
assert.equal(clears, 4, "A search with no nest stops tracking");
console.log("Quick-search distance and location lifecycle checks passed.");
