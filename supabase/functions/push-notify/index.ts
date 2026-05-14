// ============================================================================
// push-notify — Supabase Edge Function (Deno runtime)
//
// Triggered by a database webhook on INSERT to public.notifications.
// Fans out APNs push to every device_token row belonging to the recipient.
//
// REQUIRED secrets:
//   APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_KEY_P8, APNS_USE_SANDBOX
// Auto-injected:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//
// JWT signed with built-in WebCrypto (no external deps) — keeps the cold-start
// fast and avoids fetching deno.land at boot.
// ============================================================================

const APNS_HOST = (Deno.env.get("APNS_USE_SANDBOX") || "false").toLowerCase() === "true"
  ? "https://api.sandbox.push.apple.com"
  : "https://api.push.apple.com";

let cachedJwt: { token: string; expiresAt: number } | null = null;
let cachedKey: CryptoKey | null = null;

// base64url-encode a Uint8Array (no padding, +/ → -_)
function b64url(bytes: Uint8Array | ArrayBuffer): string {
  const arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  let s = "";
  for (let i = 0; i < arr.length; i++) s += String.fromCharCode(arr[i]);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importApnsKey(): Promise<CryptoKey> {
  if (cachedKey) return cachedKey;
  const p8 = Deno.env.get("APNS_KEY_P8");
  if (!p8) throw new Error("APNS_KEY_P8 secret missing");
  // Strip PEM markers + all whitespace, decode base64 → DER bytes
  const pem = p8.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  if (!pem) throw new Error("APNS_KEY_P8 looks empty after stripping PEM markers");
  let der: Uint8Array;
  try {
    der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  } catch (e) {
    throw new Error("APNS_KEY_P8 base64 decode failed — paste the full .p8 contents including BEGIN/END lines");
  }
  cachedKey = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  return cachedKey;
}

async function getApnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && cachedJwt.expiresAt > now + 60) return cachedJwt.token;

  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  if (!keyId) throw new Error("APNS_KEY_ID secret missing");
  if (!teamId) throw new Error("APNS_TEAM_ID secret missing");

  const key = await importApnsKey();

  const header = { alg: "ES256", kid: keyId, typ: "JWT" };
  const payload = { iss: teamId, iat: now };
  const headerB64 = b64url(new TextEncoder().encode(JSON.stringify(header)));
  const payloadB64 = b64url(new TextEncoder().encode(JSON.stringify(payload)));
  const signingInput = `${headerB64}.${payloadB64}`;

  // ECDSA P-256 with SHA-256 → JOSE format (raw r || s, 64 bytes total)
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  const token = `${signingInput}.${b64url(sig)}`;

  cachedJwt = { token, expiresAt: now + 50 * 60 };
  return token;
}

function buildAlert(row: any, actorName: string): { title: string; body: string } {
  const courseLine = row.course_id ? "your rating" : "you";
  switch (row.type) {
    case "follow":
      return { title: "New follower", body: `${actorName} started following you on Pure.` };
    case "reaction":
      return { title: "New reaction", body: `${actorName} reacted ${row.emoji || "🔥"} to ${courseLine}.` };
    case "comment":
      return { title: `${actorName} commented`, body: (row.text || "").slice(0, 140) };
    case "tag":
      return { title: "Tagged in a round", body: `${actorName} tagged you in their round.` };
    default:
      return { title: "Pure", body: "You have a new notification." };
  }
}

async function sendPush(token: string, payload: unknown, jwt: string, bundleId: string) {
  const res = await fetch(`${APNS_HOST}/3/device/${token}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  return { status: res.status, body: res.status === 200 ? null : await res.text(), token };
}

Deno.serve(async (req) => {
  // Step-by-step error reporting: if anything throws, the message comes back to
  // the caller (and shows in the webhook log) so we don't have to guess.
  let stage = "init";
  try {
    stage = "parse_body";
    const body = await req.json();
    const row = body?.record ?? body;
    if (!row?.user_id || !row?.type) {
      return new Response(JSON.stringify({ error: "missing record (need user_id and type)", got: row }), { status: 400 });
    }

    stage = "env_check";
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const bundleId = Deno.env.get("APNS_BUNDLE_ID");
    if (!supabaseUrl) throw new Error("SUPABASE_URL not auto-injected (unexpected)");
    if (!serviceKey) throw new Error("SUPABASE_SERVICE_ROLE_KEY not auto-injected — set it as a secret manually");
    if (!bundleId) throw new Error("APNS_BUNDLE_ID secret missing");

    stage = "fetch_tokens";
    // Use the SECURITY DEFINER RPC instead of direct table read — bypasses RLS safely.
    const tokensRes = await fetch(`${supabaseUrl}/rest/v1/rpc/get_ios_device_tokens`, {
      method: "POST",
      headers: { apikey: serviceKey, authorization: `Bearer ${serviceKey}`, "content-type": "application/json" },
      body: JSON.stringify({ p_user_id: row.user_id }),
    });
    if (!tokensRes.ok) {
      const detail = await tokensRes.text();
      throw new Error(`get_ios_device_tokens RPC ${tokensRes.status}: ${detail}`);
    }
    const tokenRows: { token: string }[] = await tokensRes.json();
    if (tokenRows.length === 0) {
      console.log("[push-notify] no ios tokens for user", row.user_id);
      return new Response(JSON.stringify({ ok: true, sent: 0, reason: "no ios tokens" }), { status: 200 });
    }

    stage = "fetch_actor";
    let actorName = "Someone";
    if (row.actor_id) {
      const r = await fetch(`${supabaseUrl}/rest/v1/rpc/get_actor_display_name`, {
        method: "POST",
        headers: { apikey: serviceKey, authorization: `Bearer ${serviceKey}`, "content-type": "application/json" },
        body: JSON.stringify({ p_user_id: row.actor_id }),
      });
      if (r.ok) {
        const name = await r.json();
        if (typeof name === "string" && name.length) actorName = name.split(" ")[0];
      }
    }

    stage = "build_payload";
    const { title, body: alertBody } = buildAlert(row, actorName);
    const apnsPayload = {
      aps: { alert: { title, body: alertBody }, sound: "default", "thread-id": row.type, badge: 1 },
      pure: { type: row.type, course_id: row.course_id, actor_id: row.actor_id, notification_id: row.id },
    };

    stage = "sign_jwt";
    const jwt = await getApnsJwt();

    stage = "send_apns";
    const results = await Promise.all(tokenRows.map((t) => sendPush(t.token, apnsPayload, jwt, bundleId)));
    console.log("[push-notify] APNs results:", JSON.stringify(results.map((r) => ({ status: r.status, body: r.body }))));

    stage = "prune_dead";
    const dead = results.filter((r) => r.status === 410).map((r) => r.token);
    if (dead.length) {
      await fetch(`${supabaseUrl}/rest/v1/device_tokens?token=in.(${dead.map((t) => `"${t}"`).join(",")})`, {
        method: "DELETE",
        headers: { apikey: serviceKey, authorization: `Bearer ${serviceKey}` },
      });
    }

    return new Response(JSON.stringify({ ok: true, sent: results.length, dead: dead.length, results: results.map((r) => ({ status: r.status, body: r.body })) }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  } catch (err) {
    const msg = String((err as Error)?.message || err);
    console.error(`[push-notify] failed at stage=${stage}: ${msg}`);
    return new Response(JSON.stringify({ error: msg, stage }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
