// Web performance benchmark: exports the "Web Benchmark" preset (the game with
// tests/perf_benchmark.tscn as its main scene), serves it locally, plays it in a
// fresh Edge or Chrome window and prints the frame-time report together with
// audio gaps and WebGL resource churn.
//
//   node tools/web_benchmark.mjs [--rounds=3] [--gpu=default|high] [--label=name]
//        [--godot=<Godot console exe>] [--browser=<msedge/chrome exe>]
//        [--out=<folder>] [--no-export] [--port=8765]
//        [--map-pan | --map-pan-cache-only | --cloud-transition | --ui-effects] [--headless]
// Map modes measure the title-to-map camera move only, with component ablations
// or retained island drawing commands. No duels or balance simulations run.
//
// Needs Node 22 or later and the Godot Web export templates. The browser runs
// with background throttling off and autoplay on, so the sound plays as for a
// player. Laptops usually give browsers the integrated GPU: that is the default
// here (--gpu=default); --gpu=high asks for the high-performance GPU instead.
//
// Audio gaps: the exported audio worklet is patched (in the output copy only) to
// count the 128-sample blocks it plays as silence because the main thread had
// not mixed them in time; perf_benchmark.gd reads the count each frame.

import { spawn, spawnSync } from "node:child_process";
import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const options = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...v] = a.replace(/^--/, "").split("=");
  return [k, v.length ? v.join("=") : true];
}));
const rounds = Number(options.rounds ?? 3);
const port = Number(options.port ?? 8765);
const label = String(options.label ?? (options.gpu === "high" ? "high_gpu" : "default_gpu"));
const out = path.resolve(String(options.out ?? path.join(os.tmpdir(), "shapeshifters_web_benchmark")));
const web = path.join(out, "web");
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function findGodot() {
  if (options.godot) return String(options.godot);
  if (process.env.GODOT) return process.env.GODOT;
  const roots = [path.join(os.homedir(), "Tools", "Godot"), ...fs.readdirSync("C:/").filter((d) => d.startsWith("Godot")).map((d) => path.join("C:/", d))];
  const found = [];
  for (const root of roots) {
    const walk = (dir, depth) => {
      if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) return;
      for (const f of fs.readdirSync(dir)) {
        const p = path.join(dir, f);
        if (/^Godot_v4.*_console\.exe$/.test(f)) found.push(p);
        else if (depth > 0) walk(p, depth - 1);
      }
    };
    walk(root, 1);
  }
  found.sort();
  if (!found.length) throw new Error("Godot 4 not found: pass --godot=<Godot console exe> or set GODOT.");
  return found[found.length - 1];
}

function findBrowser() {
  if (options.browser) return String(options.browser);
  const candidates = [
    "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
    "C:/Program Files/Microsoft/Edge/Application/msedge.exe",
    "C:/Program Files/Google/Chrome/Application/chrome.exe",
    path.join(process.env.LOCALAPPDATA ?? "", "Google/Chrome/Application/chrome.exe"),
  ];
  const found = candidates.find((p) => fs.existsSync(p));
  if (!found) throw new Error("No Edge or Chrome found: pass --browser=<path>.");
  return found;
}

function patch(file, from, to) {
  const text = fs.readFileSync(file, "utf8");
  if (!text.includes(from)) throw new Error(`Cannot instrument ${path.basename(file)}: pattern not found (Godot version change?)`);
  fs.writeFileSync(file, text.replace(from, to));
}

function exportBuild() {
  fs.rmSync(web, { recursive: true, force: true });
  fs.mkdirSync(web, { recursive: true });
  const godot = findGodot();
  console.log(`Exporting with ${godot} ...`);
  const r = spawnSync(godot, ["--headless", "--audio-driver", "Dummy", "--path", project, "--export-release", "Web Benchmark", path.join(web, "index.html")], { encoding: "utf8" });
  if (r.status !== 0 || !fs.existsSync(path.join(web, "index.pck"))) {
    console.log(r.stdout, r.stderr);
    throw new Error("Web export failed.");
  }
  patch(path.join(web, "index.audio.worklet.js"),
    "// this.port.postMessage('Output buffer has not enough frames! Skipping output frame.');",
    "this.port.postMessage({ 'cmd': 'underrun', 'data': 1 });");
  patch(path.join(web, "index.js"),
    '}else if(event.data["cmd"]==="input"){',
    '}else if(event.data["cmd"]==="underrun"){window.__audioUnderruns=(window.__audioUnderruns||0)+event.data["data"]}else if(event.data["cmd"]==="input"){');
}

function serve() {
  const types = { ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm", ".png": "image/png" };
  const server = http.createServer((req, res) => {
    const name = decodeURIComponent(req.url.split("?")[0]).replace(/^\/+/, "") || "index.html";
    const file = path.resolve(web, name);
    if (!file.startsWith(web) || !fs.existsSync(file)) { res.writeHead(404); return res.end(); }
    let data = fs.readFileSync(file);
    if (name === "index.html") {
      const gameArgs = ["--", `--rounds=${rounds}`];
      if (options["map-pan"]) gameArgs.push("--map-pan");
      if (options["cloud-transition"]) gameArgs.push("--cloud-transition");
      if (options["ui-effects"]) gameArgs.push("--ui-effects");
      if (options["map-pan-cache-only"]) gameArgs.push("--map-pan", "--map-pan-cache-only");
      data = Buffer.from(data.toString().replace('"args":[]', `"args":${JSON.stringify(gameArgs)}`));
    }
    res.writeHead(200, { "Content-Type": types[path.extname(file)] ?? "application/octet-stream", "Cache-Control": "no-store" });
    res.end(data);
  });
  return new Promise((r) => server.listen(port, "127.0.0.1", () => r(server)));
}

// Counts WebGL resource churn and draw calls; installed before the page runs.
const GL_COUNTER = `
  window.__gl = { frames: 0, calls: {} };
  const P = WebGL2RenderingContext.prototype;
  for (const name of ["createBuffer", "deleteBuffer", "createVertexArray", "deleteVertexArray", "bufferData", "bufferSubData",
      "drawArrays", "drawElements", "drawArraysInstanced", "drawElementsInstanced", "texImage2D", "texSubImage2D"]) {
    const f = P[name];
    P[name] = function (...a) { window.__gl.calls[name] = (window.__gl.calls[name] || 0) + 1; return f.apply(this, a); };
  }
  const raf = window.requestAnimationFrame.bind(window);
  window.requestAnimationFrame = (cb) => raf((t) => { window.__gl.frames++; cb(t); });
`;

async function run() {
  if (!options["no-export"]) exportBuild();
  const server = await serve();
  const profile = path.join(out, "browser_profile");
  fs.rmSync(profile, { recursive: true, force: true });
  const debugPort = port + 1000;
  const flags = [`--user-data-dir=${profile}`, `--remote-debugging-port=${debugPort}`, "--no-first-run", "--no-default-browser-check",
    "--autoplay-policy=no-user-gesture-required", "--disable-background-timer-throttling", "--disable-renderer-backgrounding",
    "--disable-backgrounding-occluded-windows", "--window-size=1300,820", "--new-window", "about:blank"];
  if (options.gpu === "high") flags.unshift("--force_high_performance_gpu");
  if (options.headless) flags.unshift("--headless=new");
  const browser = spawn(findBrowser(), flags, { stdio: "ignore" });
  try {
    let page;
    for (let i = 0; i < 60 && !page; i++) {
      await sleep(500);
      try { page = (await (await fetch(`http://127.0.0.1:${debugPort}/json`)).json()).find((t) => t.type === "page"); } catch {}
    }
    if (!page) throw new Error("The browser did not open a debuggable page.");
    const ws = new WebSocket(page.webSocketDebuggerUrl);
    await new Promise((r) => ws.addEventListener("open", r));
    let id = 0;
    const pending = new Map();
    const lines = [];
    let done = false;
    ws.addEventListener("message", (e) => {
      const m = JSON.parse(e.data);
      if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result); pending.delete(m.id); }
      if (m.method === "Runtime.consoleAPICalled") {
        const text = m.params.args.map((a) => a.value ?? a.description ?? "").join(" ");
        lines.push(...text.split("\n"));
        if (text.includes("Report written")) done = true;
        if (/SCRIPT ERROR|Parse Error/.test(text)) console.log(text);
      }
    });
    const send = (method, params = {}) => new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
    await send("Runtime.enable");
    await send("Page.enable");
    await send("Page.addScriptToEvaluateOnNewDocument", { source: GL_COUNTER });
    await send("Page.navigate", { url: `http://127.0.0.1:${port}/index.html` });
    console.log(options["ui-effects"] ? "Measuring shop and tutorial effects in the browser ..." : options["cloud-transition"] ? "Measuring map/level cloud transitions in the browser ..." : options["map-pan"] || options["map-pan-cache-only"]
      ? "Measuring title-to-map transitions in the browser ..."
      : `Playing ${rounds} round(s) in the browser ...`);
    const deadline = Date.now() + 15 * 60 * 1000;
    while (!done && Date.now() < deadline) await sleep(1000);
    if (!done) throw new Error("Timed out waiting for the benchmark report.");
    const info = (await send("Runtime.evaluate", { returnByValue: true, expression: `(() => {
      const gl = document.querySelector("canvas").getContext("webgl2");
      const ext = gl && gl.getExtension("WEBGL_debug_renderer_info");
      return { gpu: ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : "unknown", gl: window.__gl };
    })()` })).result.value;
    ws.close();
    const start = lines.findIndex((l) => l.includes("Performance benchmark"));
    const report = lines.slice(start, lines.findIndex((l, i) => i > start && l.includes("Report written")));
    const frames = Math.max(1, info.gl.frames);
    const churn = Object.entries(info.gl.calls).sort((a, b) => b[1] - a[1])
      .map(([k, n]) => `  ${(n / frames).toFixed(1).padStart(8)} per frame  ${k}`);
    const text = [`Web benchmark "${label}" — browser GPU: ${info.gpu}`, ...report, "", `WebGL calls (${frames} frames):`, ...churn].join("\n");
    const file = path.join(out, `web_report_${label}.txt`);
    fs.writeFileSync(file, text + "\n");
    console.log(text + `\n\nReport written to ${file}`);
  } finally {
    browser.kill();
    spawnSync("powershell.exe", ["-NoProfile", "-Command",
      `Get-CimInstance Win32_Process -Filter "Name='msedge.exe' or Name='chrome.exe'" | Where-Object { $_.CommandLine -like '*${profile.replace(/'/g, "''")}*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }`]);
    server.closeAllConnections();
    server.close();
  }
}

run().catch((e) => { console.error(e.message); process.exit(1); });
