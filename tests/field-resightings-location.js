// Deterministic browser GPS, UI, and save tests using invented coordinates.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const source = fs.readFileSync(path.join(__dirname, "../main/www/field_resightings_location.js"), "utf8");
const uuid = "00000000-0000-4000-8000-000000000001";

function browser(options = {}) {
  const state = {
    now: 100000, cell: null, form: null, visible: true, events: {}, handlers: {},
    messages: [], watches: [], gets: [], clears: [], timers: new Map(), ids: 0,
    generated: 0, storage: options.storage || new Map()
  };
  function action(className) {
    const attrs = {};
    const node = {
      classList: {contains: name => name === className},
      closest: selector => selector === ".field-resightings-save-form" ? state.form : node,
      setAttribute: (name, value) => {attrs[name] = value;},
      getAttribute: name => attrs[name]
    };
    return node;
  }
  const document = {
    readyState: "complete", hidden: false,
    getElementById: id => id === "field_resightings_combo" ? {value: state.combo || "RROR"} : {
      querySelector: selector => selector === ".field-resightings-distance" ? state.cell : state.form
    },
    createElement: () => action("field-resightings-behaviour-chip"),
    addEventListener: (name, callback) => {state.events[name] = callback;}
  };
  const window = {
    localStorage: {
      getItem: key => {if (options.blockStorage) throw Error("blocked"); return state.storage.get(key) || null;},
      setItem: (key, value) => {if (options.blockStorage) throw Error("blocked"); state.storage.set(key, value);}
    },
    crypto: options.noCrypto ? null : {randomUUID: () => {
      if (options.cryptoThrows) throw Error("crypto unavailable");
      state.generated += 1;
      return uuid;
    }},
    Shiny: {
      addCustomMessageHandler: (name, callback) => {state.handlers[name] = callback;},
      setInputValue: (name, value) => {state.messages.push({name, value});}
    },
    addEventListener: (name, callback) => {state.events[name] = callback;},
    setInterval: (callback, ms) => {state.tick = callback; state.interval = ms;},
    setTimeout: (callback, ms) => {const id = ++state.ids; state.timers.set(id, {callback, due: state.now + ms}); return id;},
    clearTimeout: id => state.timers.delete(id),
    jQuery: () => ({on: (names, callback) => {names.split(" ").forEach(name => {state.events[name] = callback;});}})
  };
  const navigator = {geolocation: options.noGps ? null : {
    watchPosition: (success, error, settings) => {
      if (options.watchThrows) throw Error("watch unavailable");
      const id = state.watches.length;
      state.watches.push({success, error, settings});
      return id;
    },
    clearWatch: id => state.clears.push(id),
    getCurrentPosition: (success, error, settings) => {
      if (options.getThrows) throw Error("GPS unavailable");
      state.gets.push({success, error, settings});
    }
  }};
  vm.runInNewContext(source, {document, window, navigator, Date: {now: () => state.now},
    MutationObserver: class {constructor(callback) {state.refresh = callback;} observe() {}}
  });
  state.fix = (lat = 0, lon = 0, timestamp = state.now, accuracy = 7.5) => ({coords: {latitude: lat, longitude: lon, accuracy}, timestamp});
  state.emit = fix => state.watches.at(-1).success(fix || state.fix());
  state.error = code => state.watches.at(-1).error({code});
  state.getSuccess = fix => state.gets.at(-1).success(fix || state.fix());
  state.getError = code => state.gets.at(-1).error({code});
  state.advance = ms => {
    state.now += ms;
    for (const [id, timer] of [...state.timers]) {
      if (timer.due <= state.now) {state.timers.delete(id); timer.callback();}
    }
    state.tick();
  };
  state.result = (withNest = true, withSave = true) => {
    state.cell = withNest ? {
      textContent: "—", getClientRects: () => state.visible ? [{}] : [],
      getAttribute: name => name === "data-nest-lat" ? "0" : "0.001"
    } : null;
    const attrs = {"data-search-token": String(++state.ids), "data-combo": "RROR"};
    const button = {disabled: false, textContent: "Save resighting"};
    const status = {textContent: ""};
    const fieldset = {disabled: false};
    const inputs = ["FA", "PR", "RS"].map(value => ({
      value, checked: false, getAttribute: () => value, matches: () => true,
      closest: () => state.form
    }));
    const sheet = {open: false, showModal() {this.open = true;}, close() {this.open = false;}};
    const selected = {children: [], replaceChildren() {this.children = [];}, appendChild(child) {this.children.push(child);}};
    state.form = withSave ? {
      button, status, fieldset, inputs, sheet, selected,
      matches: selector => selector === ".field-resightings-save-form",
      getClientRects: () => state.visible ? [{}] : [],
      getAttribute: name => attrs[name], setAttribute: (name, value) => {attrs[name] = value;},
      querySelectorAll: selector => selector.endsWith(":checked") ? inputs.filter(input => input.checked) : inputs,
      querySelector: selector => selector === "fieldset" ? fieldset :
        selector === ".field-resightings-save-status" ? status :
        selector === ".field-resightings-behaviour-sheet" ? sheet :
        selector === ".field-resightings-behaviour-selected" ? selected : button
    } : null;
    state.refresh();
    return state.form;
  };
  state.choose = (...codes) => state.form.inputs.forEach(input => {input.checked = codes.includes(input.value);});
  state.submit = () => state.events.submit({target: state.form, preventDefault() {}});
  state.click = name => state.events.click({target: typeof name === "string" ? action(name) : name});
  state.changed = input => state.events.change({target: input});
  state.reply = (saved, token = state.form.getAttribute("data-search-token")) => {
    state.handlers.field_resightings_save_result({token, saved, message: saved ? "Saved" : "Couldn’t save. Try again."});
  };
  state.hide = () => {document.hidden = true; state.events.visibilitychange();};
  state.show = () => {document.hidden = false; state.events.visibilitychange();};
  return state;
}

let checks = 0;
function check(name, run) {run(); checks += 1;}

check("distance refresh and expiry", () => {
  const b = browser();
  assert.equal(b.watches.length, 0);
  assert.equal(b.interval, 5000);
  b.result(true, false);
  b.emit();
  assert.equal(b.cell.textContent, "—", "GPS callbacks do not bypass the five-second refresh");
  b.advance(5000);
  assert.equal(b.cell.textContent, "111 m");
  b.emit(b.fix(0, 0.001));
  b.refresh();
  assert.equal(b.cell.textContent, "111 m", "UI mutations do not bypass the refresh either");
  b.advance(5000);
  assert.equal(b.cell.textContent, "0 m");
  b.advance(16000);
  assert.equal(b.cell.textContent, "—");
  assert.equal(b.messages.length, 0, "Distance never transmits device coordinates");
  assert.equal(b.watches.length, 1);
});
check("transient GPS errors retain a fresh fix", () => {
  const b = browser(); b.result(); b.emit(); b.advance(5000);
  b.error(3); b.error(2);
  assert.equal(b.cell.textContent, "111 m");
  b.choose("FA"); b.submit();
  assert.equal(b.messages.length, 1);
  assert.equal(b.gets.length, 0);
});
check("permission denial stops tracking and a save can retry", () => {
  const b = browser(); b.result(); b.emit(); b.advance(5000); b.error(1);
  assert.equal(b.cell.textContent, "—");
  assert.equal(b.clears.length, 1);
  b.refresh();
  assert.equal(b.watches.length, 1, "Denied permission cannot cause a retry loop");
  b.choose("FA"); b.submit();
  assert.equal(b.watches.length, 2);
  b.emit();
  assert.equal(b.messages.length, 1);
});
check("watch and one-time fixes share one pending save", () => {
  const b = browser(); b.result(false); b.choose("FA", "PR"); b.submit(); b.submit();
  assert.equal(b.form.button.disabled, true);
  assert.equal(b.watches.length, 1, "Save leaves the watcher running");
  assert.equal(b.gets.length, 1);
  b.emit();
  assert.equal(b.messages.length, 1, "A background fix saves immediately");
  b.getError(3); b.getSuccess();
  assert.equal(b.messages.length, 1, "Late one-time callbacks cannot save twice");
  assert.equal(b.timers.size, 0);
  assert.deepEqual(Array.from(b.messages[0].value.behaviours), ["FA", "PR"]);
  b.reply(true); b.submit();
  assert.equal(b.messages.length, 1);
});
check("one-time GPS also updates the cached position", () => {
  const b = browser(); b.result(); b.choose("FA"); b.submit(); b.getSuccess();
  b.advance(5000);
  assert.equal(b.cell.textContent, "111 m");
  b.reply(false); b.submit();
  assert.equal(b.messages.length, 2);
  assert.equal(b.gets.length, 1, "Retry uses the fresh cached fix");
});
check("out-of-order positions do not replace newer positions", () => {
  const b = browser(); b.result(); b.emit(b.fix(0, 0.001));
  b.emit(b.fix(0, 0, b.now - 2000)); b.advance(5000);
  assert.equal(b.cell.textContent, "0 m");
});
check("incomplete, malformed, old, and future GPS fixes block saving", () => {
  for (const invalid of [null, {}, {timestamp: 100000},
    {timestamp: 100000, coords: {latitude: false, longitude: 0}},
    {timestamp: 100000, coords: {latitude: 0}},
    {timestamp: 100000, coords: {longitude: 0}},
    {timestamp: 100000, coords: {latitude: 91, longitude: 0}},
    {timestamp: 100000, coords: {latitude: 0, longitude: Infinity}},
    {timestamp: 84000, coords: {latitude: 0, longitude: 0}},
    {timestamp: 106000, coords: {latitude: 0, longitude: 0}}]) {
    const b = browser(); b.result(); b.choose("RS"); b.submit();
    b.gets.at(-1).success(invalid);
    assert.equal(b.messages.length, 0);
    assert.equal(b.form.status.textContent, "GPS unavailable.");
    assert.equal(b.form.button.disabled, false);
    assert.equal(b.form.fieldset.disabled, false);
  }
});
check("missing or invalid accuracy stays nullable", () => {
  const b = browser(); b.result(); b.choose("RS"); b.submit(); b.getSuccess(b.fix(0, 0, b.now, ""));
  assert.equal(b.messages[0].value.location.accuracy, null);
  assert.equal(b.messages[0].value.location.latitude, 0);
});
check("application deadline bounds a browser that never replies", () => {
  const b = browser(); b.result(); b.choose("FA"); b.submit();
  assert.equal(b.form.button.disabled, true);
  b.advance(10000);
  assert.equal(b.form.button.disabled, false);
  assert.equal(b.form.status.textContent, "GPS unavailable.");
  b.getSuccess();
  assert.equal(b.messages.length, 0, "A late fix cannot revive an expired save");
});
check("hiding the page, leaving the tab, and pagehide cancel pending GPS saves", () => {
  for (const leave of [b => b.hide(), b => {b.visible = false; b.events["hidden.bs.tab"]();}, b => b.events.pagehide()]) {
    const b = browser(); b.result(); b.choose("FA"); b.submit();
    const oldWatcher = b.watches[0];
    leave(b);
    assert.equal(b.clears.length, 1);
    assert.equal(b.timers.size, 0);
    assert.equal(b.form.button.disabled, false);
    b.visible = true; b.show(); b.events.pageshow();
    b.getSuccess(); oldWatcher.success(b.fix());
    assert.equal(b.messages.length, 0);
    assert.equal(b.watches.length, 2, "Returning starts one new watcher");
  }
});
check("new results cancel old GPS requests", () => {
  const b = browser(); b.result(); b.choose("FA"); b.submit(); b.result(); b.choose("RS");
  b.getSuccess();
  assert.equal(b.messages.length, 0);
  b.submit(); b.getSuccess();
  assert.equal(b.messages.length, 1);
  assert.deepEqual(Array.from(b.messages[0].value.behaviours), ["RS"]);
});
check("disconnect cancels pending requests", () => {
  const b = browser(); b.result(); b.choose("FA"); b.submit(); b.events["shiny:disconnected"]();
  b.getSuccess();
  assert.equal(b.messages.length, 0);
  assert.equal(b.form.button.disabled, true);
  assert.equal(b.timers.size, 0);
});
check("permission denial during Save recovers the controls", () => {
  const b = browser(); b.result(); b.choose("FA"); b.submit(); b.error(1); b.getSuccess();
  assert.equal(b.messages.length, 0);
  assert.equal(b.form.button.disabled, false);
  assert.equal(b.form.status.textContent, "GPS unavailable.");
});
check("unsupported GPS and synchronous browser failures do not hang Save", () => {
  for (const options of [{noGps: true}, {getThrows: true}, {watchThrows: true}]) {
    const b = browser(options); b.result(); b.choose("FA"); b.submit();
    assert.equal(b.form.button.disabled, false);
    assert.equal(b.messages.length, 0);
    assert.equal(b.timers.size, 0);
  }
});
check("browser IDs persist across browser reloads", () => {
  const storage = new Map();
  for (let visit = 0; visit < 2; visit++) {
    const b = browser({storage}); b.result(); b.choose("FA"); b.emit(); b.submit();
    assert.equal(b.messages[0].value.browser_id, uuid);
    assert.equal(b.generated, visit === 0 ? 1 : 0);
  }
});
check("blocked storage reuses the page-session ID", () => {
  const b = browser({blockStorage: true}); b.result(); b.choose("FA"); b.emit(); b.submit(); b.reply(false); b.submit();
  assert.equal(b.messages[0].value.browser_id, b.messages[1].value.browser_id);
  assert.equal(b.generated, 1);
});
check("unavailable crypto does not hang Save", () => {
  for (const options of [{noCrypto: true}, {cryptoThrows: true}]) {
    const b = browser(options); b.result(); b.choose("FA"); b.emit(); b.submit();
    assert.equal(b.form.button.disabled, false);
    assert.equal(b.form.status.textContent, "Browser ID unavailable.");
    assert.equal(b.messages.length, 0);
  }
});
check("behaviour picker, chips, and displayed-combo protection", () => {
  const b = browser(); b.result(); b.submit();
  assert.equal(b.form.status.textContent, "Choose a behaviour.");
  b.click("field-resightings-behaviour-open"); b.choose("FA", "PR"); b.changed(b.form.inputs[0]);
  assert.equal(b.form.sheet.open, true);
  assert.equal(b.form.selected.children.length, 2);
  b.click("field-resightings-behaviour-done");
  assert.equal(b.form.sheet.open, false);
  b.click(b.form.selected.children[0]);
  assert.equal(b.form.inputs[0].checked, false);
  assert.equal(b.form.selected.children.length, 1);
  b.combo = "BYGB"; b.submit();
  assert.equal(b.form.status.textContent, "Search this combo first.");
  assert.equal(b.gets.length, 0);
  b.combo = "RROR"; b.submit(); b.click(b.form.selected.children[0]);
  assert.equal(b.form.selected.children.length, 1, "Pending saves lock the selection");
});
console.log(checks + " device GPS, distance, save, browser-ID, and picker checks passed.");
