/* Precompile the inline JSX in index.html to plain JavaScript so iOS doesn't have
   to JIT-compile 7000+ lines of Babel on every cold start. Cuts boot from ~5s to
   ~0.3s on real iPhone hardware.

   Strategy:
     1. Read index.html
     2. Extract every <script type="text/babel">...</script>
     3. Compile each block with @babel/core + preset-react
     4. Write a sibling www/index.html where those scripts are <script>...</script>
        (plain JS) and the babel-standalone <script> tag is REMOVED entirely.

   The web preview keeps using the original index.html with babel-standalone since
   browsers handle JIT differently (and a static dev server can't run Babel inline). */

const fs = require("fs");
const path = require("path");
const babel = require("@babel/core");

const ROOT = path.resolve(__dirname, "..");
const SRC = path.join(ROOT, "index.html");
const OUT_DIR = path.join(ROOT, "www");
const OUT = path.join(OUT_DIR, "index.html");

if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true });

let html = fs.readFileSync(SRC, "utf8");

/* Strip the babel-standalone <script src=...> — no longer needed in the iOS bundle. */
html = html.replace(
  /<script src="https:\/\/cdnjs\.cloudflare\.com\/ajax\/libs\/babel-standalone[^"]+"><\/script>\s*/,
  ""
);

/* Rewrite every remote img URL that we've prefetched to its local bundled path.
   Manifest is produced by scripts/prefetch-remote-images.js. URLs not in the manifest
   stay remote (will load over network at runtime — fine for newly added courses
   before next prefetch run). */
const MANIFEST_PATH = path.join(ROOT, "scripts", "remote-image-manifest.json");
let imageRewrites = 0;
if (fs.existsSync(MANIFEST_PATH)) {
  const manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf8"));
  for (const [remote, local] of Object.entries(manifest)) {
    /* Replace inside img:"..." occurrences. Use split/join for exact-match (regex would
       require escaping every special character in the URL — these URLs have lots of them). */
    const before = html.length;
    html = html.split(`img:"${remote}"`).join(`img:"${local}"`);
    if (html.length !== before) imageRewrites++;
  }
}

/* Compile every <script type="text/babel">...</script> block in place. */
const re = /<script type="text\/babel">([\s\S]*?)<\/script>/g;
let blockCount = 0;
let totalIn = 0, totalOut = 0;
html = html.replace(re, (_, code) => {
  blockCount++;
  totalIn += code.length;
  const result = babel.transformSync(code, {
    presets: [["@babel/preset-react", { runtime: "classic" }]],
    babelrc: false,
    configFile: false,
    sourceType: "script",
    /* Keep modern syntax — Capacitor WKWebView is current Safari. No need to transpile
       arrow functions, template literals, etc. — that would just bloat the output. */
    plugins: [],
  });
  totalOut += result.code.length;
  return `<script>${result.code}</script>`;
});

/* Inject a window.onerror handler BEFORE any other script so uncaught errors during
   boot surface visibly in the UI instead of leaving the user stuck on the splash.
   Adds a red banner at the bottom of the screen with message + stack. */
const errBanner = `
<script>
window.addEventListener('error',function(e){
  try{
    var dbg=document.createElement('pre');
    dbg.style.cssText='position:fixed;left:8px;right:8px;bottom:env(safe-area-inset-bottom,8px);background:#fff;color:#b91c1c;font-size:11px;padding:10px;border-radius:8px;z-index:10000;max-height:50vh;overflow:auto;white-space:pre-wrap;font-family:monospace;border:1px solid #b91c1c';
    dbg.textContent='BOOT ERROR: '+(e.message||e.error&&e.error.message||'unknown')+'\\nat '+(e.filename||'?')+':'+(e.lineno||'?')+':'+(e.colno||'?')+'\\n\\n'+(e.error&&e.error.stack||'');
    (document.body||document.documentElement).appendChild(dbg);
    var splash=document.getElementById('pure-splash');
    if(splash){var tag=splash.querySelector('.pure-tagline');if(tag){tag.textContent='Boot error \u2014 see banner';tag.style.color='#b91c1c';tag.style.opacity='1';}}
  }catch(_){}
});
</script>`;
html = html.replace("</head>", errBanner + "\n</head>");

fs.writeFileSync(OUT, html);

const sizeKb = (n) => (n / 1024).toFixed(1) + "kb";
console.log(`Precompiled ${blockCount} babel block(s)`);
console.log(`  in:  ${sizeKb(totalIn)} JSX`);
console.log(`  out: ${sizeKb(totalOut)} plain JS`);
console.log(`Rewrote ${imageRewrites} remote image URL(s) → local bundled paths`);
console.log(`Wrote ${path.relative(ROOT, OUT)}`);
