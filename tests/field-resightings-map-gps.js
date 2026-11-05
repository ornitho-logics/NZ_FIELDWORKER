// Map GPS lifecycle checks with invented positions and a minimal Leaflet host.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function mapBrowser() {
  const state = {visible: true, buttons: [], watches: [], gets: [], clears: [], draws: 0, events: {}};
  const document = {
    hidden: false,
    addEventListener: (name, callback) => {state.events[name] = callback;},
    removeEventListener: name => {delete state.events[name];}
  };
  const layer = {addTo() {return this;}, setLatLng() {}, setRadius() {}, bindPopup() {}};
  const domEvents = {disableClickPropagation() {}, disableScrollPropagation() {}, stop() {},
    on(target, name, callback) {target.handlers[name] = callback; return this;}};
  const leaflet = {
    DomEvent: domEvents,
    DomUtil: {
      addClass() {}, removeClass() {},
      create(tag, className) {
        const node = {className, handlers: {}, setAttribute() {}};
        if (tag === "a") state.buttons.push(node);
        return node;
      }
    },
    Control: {extend: definition => class {
      addTo() {Object.assign(this, definition); this.onAdd();}
    }},
    latLng: (lat, lon) => {state.draws += 1; return {lat, lon};},
    circle: () => Object.create(layer), circleMarker: () => Object.create(layer)
  };
  const window = {
    L: leaflet,
    addEventListener: (name, callback) => {state.events[name] = callback;},
    removeEventListener: name => {delete state.events[name];},
    jQuery: () => ({on: (name, callback) => {state.events[name] = callback;},
      off: name => {delete state.events[name];}})
  };
  const navigator = {geolocation: {
    watchPosition: (success, error) => {state.watches.push({success, error}); return state.watches.length;},
    clearWatch: id => state.clears.push(id),
    getCurrentPosition: (success, error) => state.gets.push({success, error})
  }};
  const map = {getZoom: () => 15, setView() {}, on: (name, callback) => {state.events[name] = callback;}};
  const el = {getClientRects: () => state.visible ? [{}] : []};
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, "../main/www/live_nest_leaflet.js"), "utf8"),
    {window, document, navigator, Date});
  window.liveNestLeafletGpsControl.call(map, el);
  state.follow = () => state.buttons[1].handlers.click();
  state.locate = () => state.buttons[0].handlers.click();
  state.fix = {coords: {latitude: 0.001, longitude: 0.002, accuracy: 7.5}, timestamp: Date.now()};
  state.hide = () => {document.hidden = true; state.events.visibilitychange();};
  return state;
}

for (const leave of [b => b.hide(), b => {b.visible = false; b.events["hidden.bs.tab"]();},
    b => b.events.pagehide({type: "pagehide"})]) {
  const b = mapBrowser(); b.follow();
  b.watches[0].success(b.fix);
  assert.equal(b.draws, 1);
  leave(b);
  assert.equal(b.clears.length, 1, "Leaving the map stops GPS following");
  b.watches[0].success(b.fix);
  assert.equal(b.draws, 1, "Late watch callbacks cannot redraw a hidden map");
}
{
  const b = mapBrowser(); b.locate(); b.events.pagehide({type: "pagehide"});
  b.gets[0].success(b.fix);
  assert.equal(b.draws, 0, "Late one-time fixes are cancelled when leaving");
}
{
  const b = mapBrowser(); b.follow(); b.locate(); b.events.unload();
  b.watches[0].success(b.fix); b.gets[0].success(b.fix);
  assert.equal(b.draws, 0, "Unloaded maps ignore all late GPS callbacks");
  assert.equal(b.clears.length, 1);
  assert.equal(b.events.visibilitychange, undefined);
}
{
  const b = mapBrowser(); b.follow(); b.watches[0].error({code: 1});
  assert.equal(b.clears.length, 1);
  b.follow(); b.watches[1].success(b.fix);
  assert.equal(b.draws, 1, "GPS following can be retried after an error");
}
console.log("6 map GPS lifecycle checks passed.");
