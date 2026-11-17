// Offline PWA lifecycle checks. No browser service, app, database, or npm packages.
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const source = name => fs.readFileSync(path.join(__dirname, "../main/www", name), "utf8");
const A = "a".repeat(64), B = "b".repeat(64);
const root = "https://example.test/field/main/";
const flush = () => new Promise(resolve => setImmediate(resolve));

function events(target = {}) {
  const handlers = new Map();
  target.addEventListener = (name, callback) => {
    if (!handlers.has(name)) handlers.set(name, new Set());
    handlers.get(name).add(callback);
  };
  target.emit = (name, event = {}) => {
    for (const callback of handlers.get(name) || []) callback(event);
  };
  return target;
}
function worker(build = B, state = "installed") {
  return events({state, scriptURL: root + "service-worker.js?build=" + build,
    messages: [], postMessage(message) {this.messages.push(message);}});
}
function browser(options = {}) {
  const nodes = Object.fromEntries([
    "install_mobile", "install_help", "install_mobile_label", "pwa_update_notice",
    "pwa_update", "pwa_update_later", "pwa_check_updates", "pwa_update_detail", "pwa_update_status"
  ].map(id => [id, {id, hidden: true, disabled: false, textContent: ""}]));
  const state = {reloads: 0, fetches: [], registrations: [], storage: new Map(), timers: [], now: 100000};
  const document = events({readyState: "loading", hidden: false,
    getElementById: id => nodes[id],
    querySelector: selector => selector.startsWith("meta") ? {content: options.current || A} : {href: root + "manifest.webmanifest"},
    querySelectorAll: () => [{dataset: {value: "nest_map"}, click: () => {state.restoredTab = "nest_map";}}]
  });
  const media = events({matches: !!options.standalone});
  const registration = events({waiting: options.waiting || null, installing: options.installing || null,
    updates: 0, async update() {this.updates++;}});
  const serviceWorker = events({controller: options.controller === null ? null : (options.controller || worker(A)),
    async register(url, settings) {
      state.registrations.push({url, settings});
      return registration;
    }
  });
  const navigator = {serviceWorker, userAgent: options.ios ? "iPhone" : "Android Chrome", platform: "Linux", maxTouchPoints: 1};
  const window = events({navigator, isSecureContext: true,
    location: {href: root, reload: () => {state.reloads++;}},
    matchMedia: () => media,
    setTimeout: callback => {state.timers.push(callback); return state.timers.length;},
    clearTimeout: () => {},
    sessionStorage: {
      setItem(key, value) {if (options.blockStorage) throw Error("disabled"); state.storage.set(key, value);},
      getItem(key) {if (options.blockStorage) throw Error("disabled"); return state.storage.get(key);}
    },
    jQuery: () => ({on: (name, callback) => document.addEventListener(name, callback)})
  });
  vm.runInNewContext(source("pwa_install.js"), {
    window, document, navigator, URL, WeakSet, Promise, AbortController, Date: {now: () => state.now},
    console: {warn() {}},
    fetch: async (url, settings) => {
      state.fetches.push({url: String(url), settings});
      if (options.hanging) return new Promise((resolve, reject) => {
        settings.signal.addEventListener("abort", () => reject(Error("timeout")));
      });
      if (options.offline) throw Error("offline");
      return {ok: !options.noStamp, json: async () => ({id: options.latest || A})};
    }
  });
  document.emit("DOMContentLoaded");
  state.start = async () => {window.emit("load"); await flush();};
  state.click = async id => {document.emit("click", {target: nodes[id], preventDefault() {}}); await flush();};
  return Object.assign(state, {nodes, document, window, serviceWorker, registration, media});
}

test("native prompt is offered only when available; menu help is inline", async () => {
  const app = browser();
  assert.equal(app.nodes.install_mobile.hidden, true);
  assert.match(app.nodes.install_help.textContent, /Chrome/);
  let calls = 0;
  app.window.emit("beforeinstallprompt", {preventDefault() {},
    prompt() {calls++; app.window.emit("appinstalled"); return Promise.resolve();},
    userChoice: Promise.resolve({outcome: "accepted"})});
  assert.equal(app.nodes.install_mobile.hidden, false);
  await app.click("install_mobile");
  assert.equal(calls, 1);
  assert.equal(app.nodes.install_mobile.hidden, true);
  assert.match(app.nodes.install_help.textContent, /ready/);
});

test("standalone and iOS get appropriate installation guidance", () => {
  assert.equal(browser({standalone: true}).nodes.install_mobile.hidden, true);
  assert.match(browser({ios: true}).nodes.install_help.textContent, /Safari.*Share/);
});

test("dismissed and rejected install prompts return to useful inline guidance", async () => {
  for (const rejects of [false, true]) {
    const app = browser();
    app.window.emit("beforeinstallprompt", {preventDefault() {},
      prompt: () => rejects ? Promise.reject(Error("unavailable")) : Promise.resolve(),
      userChoice: Promise.resolve({outcome: "dismissed"})});
    await app.click("install_mobile");
    assert.equal(app.nodes.install_mobile.hidden, true);
    assert.equal(app.nodes.install_mobile.disabled, false);
    assert.match(app.nodes.install_help.textContent, /Chrome/);
  }
});

test("new worker waits for an explicit update; only the consenting window reloads", async () => {
  const waiting = worker();
  const app = browser({waiting, latest: B});
  await app.start();
  assert.equal(waiting.messages.length, 0);
  assert.equal(app.reloads, 0);
  assert.equal(app.nodes.pwa_update_notice.hidden, false);
  assert.match(app.registrations[0].url, new RegExp("build=" + B));
  assert.equal(app.registrations[0].settings.scope, root);
  assert.equal(app.fetches[0].settings.cache, "no-store");
  await app.click("pwa_update");
  assert.equal(waiting.messages.length, 1);
  assert.equal(waiting.messages[0].type, "FIELDWORKER_APPLY_UPDATE");
  assert.equal(waiting.messages[0].build, B);
  assert.equal(app.reloads, 0);
  app.serviceWorker.emit("controllerchange");
  assert.equal(app.reloads, 1);

  const other = browser();
  other.serviceWorker.controller = worker(B);
  other.serviceWorker.emit("controllerchange");
  assert.equal(other.reloads, 0);
  assert.equal(other.nodes.pwa_update_notice.hidden, false);
});

test("Later persists for automatic checks; manual checking offers the update again", async () => {
  const app = browser({waiting: worker(), latest: B});
  await app.start();
  await app.click("pwa_update_later");
  assert.equal(app.nodes.pwa_update_notice.hidden, true);
  app.now += 61000;
  app.document.emit("visibilitychange");
  await flush();
  assert.equal(app.nodes.pwa_update_notice.hidden, true);
  await app.click("pwa_check_updates");
  assert.equal(app.nodes.pwa_update_notice.hidden, false);
});

test("first worker installation does not request a reload or advertise an update", async () => {
  const installing = worker(A, "installing");
  const app = browser({controller: null, installing});
  await app.start();
  installing.state = "installed";
  installing.emit("statechange");
  app.serviceWorker.controller = installing;
  app.serviceWorker.emit("controllerchange");
  assert.equal(app.nodes.pwa_update_notice.hidden, true);
  assert.equal(app.reloads, 0);
  assert.equal(installing.messages.length, 0);
});

test("a failed build check never claims the app is up to date", async () => {
  for (const options of [{offline: true}, {noStamp: true}]) {
    const app = browser(options);
    await app.start();
    assert.match(app.nodes.pwa_update_status.textContent, /Could not check/);
    assert.equal(app.reloads, 0);
  }
});

test("a stalled metadata fetch times out without leaving the update button busy", async () => {
  const app = browser({hanging: true});
  await app.start();
  assert.equal(app.nodes.pwa_check_updates.disabled, true);
  app.timers[0]();
  await flush();
  assert.equal(app.nodes.pwa_check_updates.disabled, false);
  assert.match(app.nodes.pwa_update_status.textContent, /Could not check/);
});

test("a replaced worker cannot leave the user stuck in an applying state", async () => {
  const waiting = worker();
  waiting.postMessage = () => {throw Error("worker replaced");};
  const app = browser({waiting, latest: B});
  await app.start();
  await app.click("pwa_update");
  assert.equal(app.nodes.pwa_update.disabled, false);
  assert.match(app.nodes.pwa_update_detail.textContent, /Check for updates/);
  assert.equal(app.reloads, 0);
});

test("a known offline connection defers activation and keeps the current page open", async () => {
  const waiting = worker();
  const app = browser({waiting, latest: B});
  await app.start();
  app.window.navigator.onLine = false;
  app.window.emit("offline");
  await app.click("pwa_update");
  assert.equal(app.nodes.pwa_update.disabled, true);
  assert.match(app.nodes.pwa_update_detail.textContent, /Reconnect before updating/);
  assert.equal(waiting.messages.length, 0);
  assert.equal(app.reloads, 0);
});

test("tab restoration is scoped to the app and tolerates disabled storage", () => {
  for (const blockStorage of [false, true]) {
    const app = browser({blockStorage});
    app.document.emit("shiny:inputchanged", {name: "main", value: "nest_map"});
    app.document.emit("shiny:sessioninitialized");
    assert.equal(app.restoredTab, blockStorage ? undefined : "nest_map");
  }
});

function serviceWorker(options = {}) {
  const state = {waits: [], skips: 0, claims: 0, fetches: [], stores: new Map()};
  const self = events({location: {href: root + "service-worker.js?build=" + B},
    registration: {scope: root}, clients: {claim: async () => {state.claims++;}},
    skipWaiting: async () => {state.skips++;}});
  const caches = {
    async keys() {return [...state.stores.keys()];},
    async delete(key) {return state.stores.delete(key);},
    async open(key) {
      if (!state.stores.has(key)) state.stores.set(key, new Map());
      const cache = state.stores.get(key);
      return {put: async (url, response) => cache.set(url, response),
        match: async url => cache.get(url), keys: async () => [...cache.keys()].map(url => ({url}))};
    }
  };
  vm.runInNewContext(source("service-worker.js"), {self, caches, URL, Response,
    fetch: async (request, settings) => {
      state.fetches.push({url: request.url || request, settings});
      if (options.offline) throw Error("offline");
      return {ok: !options.badOfflinePage, type: "basic", marker: "network"};
    }});
  state.dispatch = async (name, extra = {}) => {
    let response;
    const waits = [];
    self.emit(name, Object.assign({waitUntil: promise => waits.push(promise), respondWith: value => {response = value;}}, extra));
    await Promise.all(waits);
    return response === undefined ? undefined : await response;
  };
  return Object.assign(state, {self});
}

test("worker caches only offline fallback and never activates automatically", async () => {
  const sw = serviceWorker();
  await sw.dispatch("install");
  assert.deepEqual(sw.fetches.map(x => x.url), [root + "offline.html"]);
  assert.equal(sw.skips, 0);
  assert.equal([...sw.stores.values()][0].size, 1);
  await sw.dispatch("message", {data: {type: "SKIP_WAITING"}});
  await sw.dispatch("message", {data: {type: "FIELDWORKER_APPLY_UPDATE", build: A}});
  assert.equal(sw.skips, 0);
  await sw.dispatch("message", {data: {type: "FIELDWORKER_APPLY_UPDATE", build: B}});
  assert.equal(sw.skips, 1);
});

test("worker passes scripts, manifests, downloads, and session requests through", async () => {
  const sw = serviceWorker();
  for (const request of [
    {url: root + "style.css", method: "GET", mode: "cors"},
    {url: root + "manifest.webmanifest", method: "GET", mode: "cors"},
    {url: root + "session/test/download/file", method: "GET", mode: "cors"},
    {url: root + "session/test", method: "POST", mode: "navigate"},
    {url: "https://example.test/other/", method: "GET", mode: "navigate"}
  ]) assert.equal(await sw.dispatch("fetch", {request}), undefined);
  const response = await sw.dispatch("fetch", {request: {url: root, method: "GET", mode: "navigate"}});
  assert.equal(response.marker, "network");
  assert.equal(sw.fetches[0].settings.cache, "no-store");
  assert.equal(sw.stores.size, 0);
});

test("offline navigation uses only this scope's fallback cache", async () => {
  const sw = serviceWorker({offline: true});
  const name = "nz-fieldworker-offline-" + encodeURIComponent(root) + "-" + B;
  sw.stores.set(name, new Map([[root + "offline.html", {marker: "offline-page"}]]));
  const response = await sw.dispatch("fetch", {request: {url: root, method: "GET", mode: "navigate"}});
  assert.equal(response.marker, "offline-page");
});

test("cache migration removes this app's old entries and preserves other scopes", async () => {
  const sw = serviceWorker();
  const prefix = "nz-fieldworker-offline-" + encodeURIComponent(root) + "-";
  sw.stores.set(prefix + A, new Map());
  sw.stores.set(prefix + B, new Map());
  sw.stores.set("nz-fieldworker-precache-old", new Map([[root + "style.css", {}]]));
  sw.stores.set("nz-fieldworker-runtime-other", new Map([["https://example.test/other/icon.png", {}]]));
  sw.stores.set("unrelated-cache", new Map());
  await sw.dispatch("activate");
  assert.equal(sw.stores.has(prefix + A), false);
  assert.equal(sw.stores.has(prefix + B), true);
  assert.equal(sw.stores.has("nz-fieldworker-precache-old"), false);
  assert.equal(sw.stores.has("nz-fieldworker-runtime-other"), true);
  assert.equal(sw.stores.has("unrelated-cache"), true);
  assert.equal(sw.claims, 1);
});

test("a missing offline page fails installation instead of activating an incomplete worker", async () => {
  const sw = serviceWorker({badOfflinePage: true});
  await assert.rejects(sw.dispatch("install"), /Offline page unavailable/);
  assert.equal(sw.skips, 0);
});
