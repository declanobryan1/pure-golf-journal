/* Pre-fetch every remote course image (Wikimedia, etc.) referenced from index.html
   and bundle it locally under images/courses/remote/. Once cached, subsequent runs
   skip URLs that are already on disk so this is idempotent and incremental.

   Why we do this: in Capacitor's WKWebView, remote image loads are sometimes slow,
   serialized, or fail outright (rate-limited host, transient DNS, etc.). Local
   images via the puregolfjournal:// scheme are always instant. Bundling all photos
   gives a consistent UX and makes the app fully usable offline.

   Output:
     - images/courses/remote/<hash>.jpg  (resized to 1200px wide, JPEG q=80)
     - scripts/remote-image-manifest.json  (URL → local path)

   Run via: npm run prefetch-images
   Wired into: npm run cap:sync (called automatically before build)

   Re-run to add newly-introduced courses' images. Old entries that 404 are reported
   in the summary so you can replace the URL.

   Source `index.html` is NEVER mutated — the URL→local-path rewrite happens during
   the precompile step that produces www/index.html. This keeps the source clean and
   means web preview (which doesn't precompile) still works against the original URLs. */

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const https = require("https");
const { execSync } = require("child_process");

const ROOT = path.resolve(__dirname, "..");
const SRC = path.join(ROOT, "index.html");
const OUT_DIR = path.join(ROOT, "images", "courses", "remote");
const MANIFEST = path.join(ROOT, "scripts", "remote-image-manifest.json");
const REL_LOCAL_BASE = "images/courses/remote";

if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true });

const manifest = fs.existsSync(MANIFEST)
  ? JSON.parse(fs.readFileSync(MANIFEST, "utf8"))
  : {};

const html = fs.readFileSync(SRC, "utf8");
const urlSet = new Set();
for (const m of html.matchAll(/img:"(https?:\/\/[^"]+)"/g)) {
  urlSet.add(m[1]);
}
console.log(`Scanned index.html — found ${urlSet.size} unique remote image URLs`);

function fetchOnce(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(
      url,
      { timeout: 30000, headers: { "User-Agent": "PureGolfJournalBuild/1.0 (support@puregolfjournal.com)" } },
      (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          fetchOnce(new URL(res.headers.location, url).toString()).then(resolve, reject);
          return;
        }
        if (res.statusCode !== 200) {
          reject(new Error(`HTTP ${res.statusCode}`));
          return;
        }
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => resolve(Buffer.concat(chunks)));
        res.on("error", reject);
      }
    );
    req.on("timeout", () => {
      req.destroy(new Error("timeout"));
    });
    req.on("error", reject);
  });
}

async function fetchWithRetry(url, attempts = 4) {
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fetchOnce(url);
    } catch (e) {
      lastErr = e;
      /* HTTP 429 = rate-limited. Wait longer (Wikimedia recommends 1+ requests/sec).
         Other errors get a quicker retry. */
      const isRateLimit = String(e.message).includes("429");
      const wait = isRateLimit ? 5000 + i * 5000 : 1000 * (i + 1);
      await new Promise((r) => setTimeout(r, wait));
    }
  }
  throw lastErr;
}

async function main() {
  let downloaded = 0;
  let cached = 0;
  let failed = [];
  let i = 0;

  for (const url of urlSet) {
    i++;
    const hash = crypto.createHash("sha1").update(url).digest("hex").slice(0, 12);
    const filename = `${hash}.jpg`;
    const filepath = path.join(OUT_DIR, filename);
    const relLocal = `${REL_LOCAL_BASE}/${filename}`;

    if (manifest[url] === relLocal && fs.existsSync(filepath)) {
      cached++;
      continue;
    }

    /* Throttle: 600ms between requests so Wikimedia doesn't rate-limit us.
       Wikimedia's User-Agent policy asks for ≤1 request/sec from non-bots. */
    await new Promise((r) => setTimeout(r, 600));
    try {
      const buf = await fetchWithRetry(url);
      fs.writeFileSync(filepath, buf);
      /* Resize to <=1200px wide, re-encode as JPEG q=80 to keep bundle size reasonable.
         Course tiles never need more than 1200px. sips is built into macOS. */
      try {
        execSync(
          `sips -Z 1200 -s formatOptions 80 -s format jpeg "${filepath}" --out "${filepath}"`,
          { stdio: "pipe" }
        );
      } catch (e) {
        /* sips failure isn't fatal — keep original bytes */
      }
      manifest[url] = relLocal;
      downloaded++;
      if (downloaded % 10 === 0) {
        process.stdout.write(`  downloaded ${i}/${urlSet.size}…\n`);
        fs.writeFileSync(MANIFEST, JSON.stringify(manifest, null, 2));
      }
    } catch (e) {
      failed.push({ url, error: e.message });
      console.warn(`  FAIL [${i}/${urlSet.size}] ${url.substring(0, 80)}…  ${e.message}`);
    }
  }

  fs.writeFileSync(MANIFEST, JSON.stringify(manifest, null, 2));
  console.log("");
  console.log(`Done: ${downloaded} downloaded, ${cached} cached, ${failed.length} failed`);
  if (failed.length) {
    console.log("\nFailed URLs (consider replacing):");
    for (const f of failed) console.log(`  ${f.error}: ${f.url}`);
  }
  const manifestSize = (fs.statSync(MANIFEST).size / 1024).toFixed(1);
  const dirSize = execSync(`du -sh "${OUT_DIR}" | awk '{print $1}'`).toString().trim();
  console.log(`Manifest: ${path.relative(ROOT, MANIFEST)} (${manifestSize}kb)`);
  console.log(`Cache dir: ${path.relative(ROOT, OUT_DIR)} (${dirSize})`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
