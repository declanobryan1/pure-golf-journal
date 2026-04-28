// Generate the JWT secret Supabase needs for Sign in with Apple.
// Usage: node scripts/gen-apple-jwt.js /path/to/AuthKey_K4F69888L9.p8
//
// Output: a JWT — paste it into Supabase → Auth → Providers → Apple → Secret Key.
// Apple JWTs expire every 6 months. Re-run this script every ~5 months and paste the new JWT.

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const TEAM_ID = "L95DKW9826";
const KEY_ID = "K4F69888L9";
const SERVICES_ID = "com.declanobryan.puregolfjournal.signin";

const keyPath = process.argv[2];
if (!keyPath) {
  console.error("Usage: node gen-apple-jwt.js /path/to/AuthKey_K4F69888L9.p8");
  process.exit(1);
}
if (!fs.existsSync(keyPath)) {
  console.error("File not found:", keyPath);
  process.exit(1);
}

const privateKey = fs.readFileSync(path.resolve(keyPath), "utf8");

const header = { alg: "ES256", kid: KEY_ID, typ: "JWT" };
const now = Math.floor(Date.now() / 1000);
const SIX_MONTHS = 60 * 60 * 24 * 180;
const payload = {
  iss: TEAM_ID,
  iat: now,
  exp: now + SIX_MONTHS,
  aud: "https://appleid.apple.com",
  sub: SERVICES_ID,
};

const b64url = (obj) =>
  Buffer.from(JSON.stringify(obj))
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

const signingInput = `${b64url(header)}.${b64url(payload)}`;

const sign = crypto.createSign("SHA256");
sign.update(signingInput);
sign.end();
const signature = sign.sign({ key: privateKey, dsaEncoding: "ieee-p1363" });
const sigB64 = signature
  .toString("base64")
  .replace(/=/g, "")
  .replace(/\+/g, "-")
  .replace(/\//g, "_");

const jwt = `${signingInput}.${sigB64}`;
console.log("\n=== Apple Sign-In JWT (paste into Supabase Secret Key field) ===\n");
console.log(jwt);
console.log("\nExpires:", new Date((now + SIX_MONTHS) * 1000).toISOString());
console.log("Set a calendar reminder for ~5 months to regenerate.\n");
