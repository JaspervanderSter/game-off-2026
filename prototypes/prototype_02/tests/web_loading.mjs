// Exercise an exported Web shell in headless Edge/Chrome, including the real game.
// node tests/web_loading.mjs --dir=<temporary Web export> [--browser=<exe>]
// Screenshots and the isolated browser profile stay in that temporary directory.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';

const args = Object.fromEntries(process.argv.slice(2).map(arg => {
  const [key, ...value] = arg.replace(/^--/, '').split('='); return [key, value.join('=')];
}));
assert(args.dir, 'Pass --dir=<temporary Web export>');
const directory = path.resolve(args.dir);
const browserPath = args.browser || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const html = fs.readFileSync(path.join(directory, 'index.html'));
const profile = fs.mkdtempSync(path.join(directory, 'loader-browser-'));
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const stub = `globalThis.Engine = class {
  static getMissingFeatures() { return location.pathname.startsWith('/missing/') ? ['WebGL 2'] : []; }
  startGame(options) { return new Promise((resolve, reject) => {
    globalThis.__probe = { report: options.onProgress, resolve, reject, starts:0, audio:new AudioContext() };
    window.shapeshifterLoading.registerGame(() => { __probe.starts++; __probe.startedAt = performance.now(); });
  }); }
};`;
const types = { '.html':'text/html', '.js':'text/javascript', '.wasm':'application/wasm', '.png':'image/png' };
const server = http.createServer((request, response) => {
  const url = new URL(request.url, 'http://localhost');
  const fixture = /^\/(fixture|missing|broken)\//.test(url.pathname);
  if (fixture && url.pathname.endsWith('/index.html')) {
    response.writeHead(200, { 'Content-Type':'text/html', 'Cache-Control':'no-store' }); return response.end(html);
  }
  if (fixture && url.pathname.endsWith('/index.js')) {
    response.writeHead(url.pathname.startsWith('/broken/') ? 404 : 200, { 'Content-Type':'text/javascript' });
    return response.end(url.pathname.startsWith('/broken/') ? '' : stub);
  }
  const filename = path.resolve(directory, '.' + decodeURIComponent(url.pathname));
  if (!filename.startsWith(directory + path.sep) || !fs.existsSync(filename) || !fs.statSync(filename).isFile()) {
    response.writeHead(404); return response.end();
  }
  response.writeHead(200, { 'Content-Type':types[path.extname(filename)] || 'application/octet-stream', 'Cache-Control':'no-store' });
  fs.createReadStream(filename).pipe(response);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const base = `http://127.0.0.1:${server.address().port}`;
const browser = spawn(browserPath, ['--headless=new', '--hide-scrollbars', '--no-first-run', '--no-default-browser-check',
  '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--window-size=1280,800', 'about:blank'],
  { stdio:'ignore', windowsHide:true });
let ws;
try {
  const portFile = path.join(profile, 'DevToolsActivePort');
  for (let i = 0; i < 100 && !fs.existsSync(portFile); i++) await sleep(200);
  assert(fs.existsSync(portFile), 'Browser debugging endpoint did not start');
  const debugPort = Number(fs.readFileSync(portFile, 'utf8').split('\n')[0]);
  const pages = await (await fetch(`http://127.0.0.1:${debugPort}/json`)).json();
  ws = new WebSocket(pages.find(page => page.type === 'page').webSocketDebuggerUrl);
  await new Promise(resolve => ws.addEventListener('open', resolve));
  let serial = 0;
  const pending = new Map(), exceptions = [];
  ws.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id); pending.delete(message.id);
      message.error ? reject(new Error(JSON.stringify(message.error))) : resolve(message.result);
    }
    if (message.method === 'Runtime.exceptionThrown') exceptions.push(message.params.exceptionDetails);
  });
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++serial; pending.set(id, { resolve, reject }); ws.send(JSON.stringify({ id, method, params }));
  });
  const evaluate = async expression => {
    const result = await send('Runtime.evaluate', { expression, returnByValue:true, awaitPromise:true });
    if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
    return result.result.value;
  };
  async function until(expression, timeout = 15000) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) { if (await evaluate(expression)) return; await sleep(100); }
    throw new Error(`Timed out: ${expression}`);
  }
  async function navigate(route) {
    await send('Page.navigate', { url:base + route });
    await until(`location.pathname === ${JSON.stringify(route)} && document.readyState === 'complete'`);
  }
  async function screenshot(name) {
    const image = await send('Page.captureScreenshot', { format:'png' });
    fs.writeFileSync(path.join(directory, name + '.png'), Buffer.from(image.data, 'base64'));
  }
  async function clickPlay(touch = false) {
    const point = await evaluate(`(() => {
      const box = document.getElementById('loading-play').getBoundingClientRect();
      return { x:box.x + box.width / 2, y:box.y + box.height / 2 };
    })()`);
    if (touch) {
      await send('Input.dispatchTouchEvent', { type:'touchStart', touchPoints:[point] });
      await send('Input.dispatchTouchEvent', { type:'touchEnd', touchPoints:[] });
    } else {
      await send('Input.dispatchMouseEvent', { type:'mousePressed', button:'left', clickCount:1, ...point });
      await send('Input.dispatchMouseEvent', { type:'mouseReleased', button:'left', clickCount:1, ...point });
    }
  }
  await send('Page.enable'); await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', { width:1280, height:800, deviceScaleFactor:1, mobile:false });
  await navigate('/fixture/index.html');
  await until('typeof __probe === "object"');
  await evaluate('__probe.report(0, 0)');
  assert.equal(await evaluate('document.getElementById("loading").hasAttribute("aria-valuenow")'), false);
  await evaluate('__probe.report(0, 100)');
  assert.equal(await evaluate('document.getElementById("loading").getAttribute("aria-valuenow")'), '0');
  await evaluate('__probe.report(62, 100)');
  assert.equal(await evaluate('document.getElementById("loading").getAttribute("aria-valuenow")'), '62');
  await sleep(400); await screenshot('loader-desktop');
  await send('Emulation.setDeviceMetricsOverride', { width:390, height:844, deviceScaleFactor:2, mobile:true });
  await sleep(200); await screenshot('loader-mobile');
  assert.equal(await evaluate('document.documentElement.scrollWidth <= innerWidth'), true);
  await evaluate('__probe.report(100, 100)');
  assert.equal(await evaluate('document.getElementById("loading").getAttribute("aria-valuetext")'), 'Starting game.');
  assert.equal(await evaluate('!!document.getElementById("loading")'), true);
  await evaluate('__probe.resolve()');
  await until('!document.getElementById("loading-play").hidden');
  await sleep(1100);
  assert.equal(await evaluate('!!document.getElementById("loading")'), true, 'Ready screen must wait for the player');
  assert.equal(await evaluate('__probe.starts'), 0);
  await screenshot('loader-ready-mobile');
  await evaluate('__probe.clickedAt = performance.now()');
  await clickPlay(true);
  await until('__probe.audio.state === "running"');
  await until('!document.getElementById("loading")');
  assert.equal(await evaluate('__probe.starts'), 0, 'White fade must not start the title early');
  await until('__probe.starts === 1');
  assert.ok(await evaluate('__probe.startedAt - __probe.clickedAt >= 1700'), 'Title must wait for both fades and its one-second pause');
  assert.equal(await evaluate('!!document.getElementById("loading-white")'), false);
  assert.equal(await evaluate('document.activeElement.id'), 'canvas');
  // Keyboard and reduced-motion users get the same single launch, without a white flash.
  await send('Emulation.setEmulatedMedia', { features:[{ name:'prefers-reduced-motion', value:'reduce' }] });
  await navigate('/fixture/index.html'); await until('typeof __probe === "object"');
  await evaluate('__probe.resolve()');
  await until('!document.getElementById("loading-play").hidden');
  await send('Input.dispatchKeyEvent', { type:'keyDown', key:'Enter', code:'Enter', windowsVirtualKeyCode:13 });
  await send('Input.dispatchKeyEvent', { type:'keyUp', key:'Enter', code:'Enter', windowsVirtualKeyCode:13 });
  await until('!document.getElementById("loading")');
  assert.equal(await evaluate('__probe.starts'), 0);
  await until('__probe.starts === 1');
  assert.equal(await evaluate('document.activeElement.id'), 'canvas');
  await navigate('/fixture/index.html'); await until('typeof __probe === "object"');
  await evaluate('__probe.report(40, 100)');
  assert.equal(await evaluate('document.getElementById("loading").getAttribute("aria-valuenow")'), '40');
  await evaluate('__probe.reject(new Error("Test download failure"))');
  await until('!document.getElementById("loading-notice").hidden');
  assert.equal(await evaluate('document.getElementById("loading-notice").textContent'), 'Test download failure');
  await navigate('/missing/index.html');
  assert.match(await evaluate('document.getElementById("loading-notice").textContent'), /WebGL 2/);
  await navigate('/broken/index.html');
  assert.equal(await evaluate('document.getElementById("loading-notice").hidden'), false);
  await send('Emulation.setEmulatedMedia', { features:[] });
  await send('Emulation.setDeviceMetricsOverride', { width:1280, height:800, deviceScaleFactor:1, mobile:false });
  console.log('Loader checks passed: progress, persistent Play screen, one touch/key launch, audio unlock, white fades and delayed title, reduced motion and errors.');
  await send('Page.addScriptToEvaluateOnNewDocument', { source:`
    window.__testAudioContexts = [];
    const OriginalAudioContext = window.AudioContext;
    window.AudioContext = new Proxy(OriginalAudioContext, { construct(target, args) {
      const context = Reflect.construct(target, args); window.__testAudioContexts.push(context); return context;
    } });
  ` });
  await navigate('/index.html');
  await until('document.getElementById("loading-play") && !document.getElementById("loading-play").hidden', 90000);
  await sleep(1100); await screenshot('game-ready-to-play');
  assert.equal(await evaluate('!!document.getElementById("loading")'), true);
  await clickPlay();
  await until('!document.getElementById("loading")');
  await screenshot('game-white-transition');
  await until('!document.getElementById("loading-white")');
  assert.equal(await evaluate('__testAudioContexts.every(context => context.state === "running")'), true);
  await sleep(1800); await screenshot('game-after-loading');
  assert.equal(await evaluate('document.activeElement.id'), 'canvas');
  assert.equal(exceptions.length, 0, JSON.stringify(exceptions));
  console.log('Real exported game started successfully with no JavaScript exceptions. Screenshots: ' + directory);
} finally {
  ws?.close(); browser.kill(); server.closeAllConnections(); server.close();
}
