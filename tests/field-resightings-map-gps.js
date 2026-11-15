// Map GPS lifecycle checks with invented positions and a minimal Leaflet host.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function mapBrowser() {
  const state = {visible: true, buttons: [], watches: [], gets: [], clears: [], draws: 0,
    events: {}, lines: [], layers: new Set()};
  const document = {
    hidden: false,
    addEventListener: (name, callback) => {state.events[name] = callback;},
    removeEventListener: name => {delete state.events[name];}
  };
  const layer = {addTo() {state.layers.add(this); return this;}, setLatLng() {},
    setRadius() {}, bindPopup() {},
    setLatLngs(points) {this.points = points.map(segment => segment.slice());}};
  const domEvents = {disableClickPropagation() {}, disableScrollPropagation() {}, stop() {},
    on(target, name, callback) {target.handlers[name] = callback; return this;}};
  const leaflet = {
    DomEvent: domEvents,
    DomUtil: {
      addClass() {}, removeClass() {},
      create(tag, className) {
        const node = {className, handlers: {}, setAttribute() {}, removeAttribute() {}};
        if (tag === "a") state.buttons.push(node);
        return node;
      }
    },
    Control: {extend: definition => class {
      addTo() {Object.assign(this, definition); this.onAdd();}
    }},
    latLng: (lat, lon) => ({lat, lon,
      distanceTo: other => Math.hypot(lat - other.lat, lon - other.lon) * 111195}),
    circle: () => Object.create(layer),
    circleMarker: () => {state.draws += 1; return Object.create(layer);},
    polyline: points => {
      const line = Object.create(layer);
      line.setLatLngs(points);
      state.lines.push(line);
      return line;
    }
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
  const map = {getZoom: () => 15, setView() {},
    on: (name, callback) => {state.events[name] = callback;},
    off: name => {delete state.events[name];},
    removeControl: control => control.onRemove(),
    hasLayer: target => state.layers.has(target),
    removeLayer: target => state.layers.delete(target)};
  const el = {id: "nest_map_show", getClientRects: () => state.visible ? [{}] : []};
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, "../main/www/live_nest_leaflet.js"), "utf8"),
    {window, document, navigator, Date});
  state.render = () => {
    state.buttons = [];
    window.liveNestLeafletGpsControl.call(map, el);
  };
  state.render();
  state.follow = () => state.buttons[1].handlers.click();
  state.locate = () => state.buttons[0].handlers.click();
  state.toggleTrail = () => state.buttons[2].handlers.click();
  state.clearTrail = () => state.buttons[3].handlers.click();
  state.line = () => state.lines[state.lines.length - 1];
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

function trailFix(seconds, latitude = 0.001, accuracy = 7.5) {
  return {coords: {latitude, longitude: 0.002, accuracy}, timestamp: 1000000 + seconds * 1000};
}

{
  const b = mapBrowser(); b.follow();
  b.watches[0].success(trailFix(0));
  b.watches[0].success(trailFix(10, 0.0011));
  assert.equal(b.line().points[0].length, 2, "Walking fixes form a line");
  b.watches[0].success(trailFix(11, 0.00111));
  b.watches[0].success(trailFix(12, 0.0012, 100));
  b.watches[0].success(trailFix(9, 0.0012));
  b.watches[0].success(trailFix(13, NaN));
  assert.equal(b.line().points[0].length, 2, "Jitter, poor, stale, and invalid fixes are ignored");
  b.toggleTrail();
  assert.equal(b.layers.has(b.line()), false, "Trail can be hidden");
  b.watches[0].success(trailFix(20, 0.0012));
  assert.equal(b.line().points[0].length, 3, "Hidden trails keep collecting fixes");
  assert.equal(b.clears.length, 0, "Hiding the trail leaves tracking active");
  b.toggleTrail();
  assert.equal(b.layers.has(b.line()), true);
  b.clearTrail();
  assert.equal(b.line().points.length, 0, "Clear removes the entire trail");
  b.watches[0].success(trailFix(30, 0.0013));
  assert.equal(b.line().points[0].length, 1, "Tracking continues after clear");
}
{
  const b = mapBrowser(); b.follow();
  b.watches[0].success(trailFix(0));
  b.watches[0].success(trailFix(180, 0.0011));
  b.watches[0].success(trailFix(181, 0.01));
  assert.equal(b.line().points.length, 3, "Signal gaps and large jumps start separate segments");
  b.follow(); b.follow();
  b.watches[1].success(trailFix(190, 0.0101));
  assert.equal(b.line().points.length, 4, "Restarting tracking does not join separate walks");
}
{
  const b = mapBrowser(); b.follow();
  b.watches[0].success(trailFix(0));
  b.watches[0].success(trailFix(10, 0.0011));
  const oldLine = b.line();
  b.toggleTrail(); b.render();
  assert.equal(b.line().points[0].length, 2, "Shiny redraws retain the trail");
  assert.equal(b.layers.has(b.line()), false, "Redraws retain trail visibility");
  assert.equal(b.layers.has(oldLine), false, "Redraws remove old trail layers");
  assert.equal(b.watches.length, 2, "Visible redraws resume active following");
  b.watches[0].success(trailFix(20, 0.0012));
  assert.equal(b.line().points[0].length, 2, "Old watch callbacks stay cancelled");
  b.watches[1].success(trailFix(20, 0.0012));
  assert.equal(b.line().points[0].length, 3, "Redraws preserve the current segment");
  b.hide(); b.render();
  assert.equal(b.watches.length, 2, "Hidden redraws do not restart tracking");
  assert.equal(mapBrowser().line().points.length, 0, "A new page starts without a trail");
}
{
  const b = mapBrowser(); b.locate(); b.gets[0].success(trailFix(0));
  assert.equal(b.line().points.length, 0, "One-time location requests do not record a walk");
  b.follow();
  for (let i = 0; i < 12005; i++) {
    b.watches[0].success(trailFix(i * 10, 0.001 + i * 0.0001));
  }
  assert.equal(b.line().points[0].length, 12000, "Long walks retain a bounded trail");
}
console.log("Map GPS lifecycle and trail checks passed.");

// Legend display choices use only local Leaflet groups, without a Shiny request.
{
  const window = {L: {DomEvent: {
    disableClickPropagation() {}, disableScrollPropagation() {}
  }}};
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, "../main/www/live_nest_leaflet.js"), "utf8"),
    {window});
  function render(groups) {
    const layers = Object.fromEntries(groups.map(group => [group, {group}]));
    const visible = new Set(Object.values(layers));
    const checkboxes = groups.map(group => ({getAttribute: () => group}));
    const legend = {querySelectorAll: () => checkboxes};
    const el = {id: "nest_map_show", querySelector: () => legend};
    const map = {
      layerManager: {getLayerGroup: group => layers[group]},
      hasLayer: layer => visible.has(layer),
      addLayer: layer => visible.add(layer),
      removeLayer: layer => visible.delete(layer)
    };
    window.liveNestLeafletLegendControl.call(map, el);
    return {checkboxes, visible, layers};
  }
  const groups = ["Nest state: I", "Nest state: brood"];
  const first = render(groups);
  assert.equal(first.visible.size, 2, "Both categories start visible");
  first.checkboxes[0].checked = false;
  first.checkboxes[0].onchange();
  assert.equal(first.visible.has(first.layers[groups[0]]), false);
  assert.equal(first.visible.has(first.layers[groups[1]]), true,
    "Hiding a nest state leaves the brood group visible");
  const redraw = render(groups);
  assert.equal(redraw.checkboxes[0].checked, false, "Redraws remember hidden categories");
  assert.equal(redraw.visible.has(redraw.layers[groups[0]]), false);
  redraw.checkboxes[0].checked = true;
  redraw.checkboxes[0].onchange();
  assert.equal(redraw.visible.size, 2, "Checking the state restores its group");
  render(["Nest state: brood"]);
  assert.equal(render(groups).checkboxes[0].checked, true,
    "Choices survive a category temporarily disappearing from the map");
  window.liveNestLeafletLegendControl.call({}, {querySelector: () => null});
  console.log("Nest legend visibility checks passed.");
}
