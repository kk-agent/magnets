import { createClient } from "npm:@supabase/supabase-js@2";

type CanonicalContentType = "text" | "photo" | "aiGenerated";

type AgentPostPayload = {
  magnet_id: string;
  content_type: CanonicalContentType;
  text_content: string;
  media_url: string | null;
  author_name: string | null;
};

type ValidationIssue = {
  field: string;
  message: string;
};

type IntegrationResult = {
  status: "todo" | "stored" | "sent" | "error";
  step: string;
  message: string;
  required_env: string[];
  details?: unknown;
};

type APNsAttempt = {
  token_suffix: string;
  ok: boolean;
  status: number | null;
  response: string | null;
};

const jsonHeaders = {
  "content-type": "application/json; charset=utf-8",
};

const bearerTokenEnvName = "MAGNETS_AGENT_POST_BEARER_TOKEN";
const supabaseURLEnvName = "SUPABASE_URL";
const supabaseServiceRoleKeyEnvName = "SUPABASE_SERVICE_ROLE_KEY";
const apnsKeyIDEnvName = "MAGNETS_APNS_KEY_ID";
const apnsTeamIDEnvName = "MAGNETS_APNS_TEAM_ID";
const apnsTopicEnvName = "MAGNETS_APNS_TOPIC";
const apnsPrivateKeyEnvName = "MAGNETS_APNS_P8_PRIVATE_KEY";
const apnsEnvironmentEnvName = "MAGNETS_APNS_ENV";

let cachedAPNsJWT: { token: string; expiresAtMs: number } | null = null;

function jsonResponse(
  status: number,
  body: unknown,
  headers: HeadersInit = {},
) {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: {
      ...jsonHeaders,
      ...headers,
    },
  });
}

function errorResponse(
  status: number,
  code: string,
  message: string,
  details: ValidationIssue[] | Record<string, string> | null = null,
  headers: HeadersInit = {},
) {
  return jsonResponse(
    status,
    {
      ok: false,
      error: {
        code,
        message,
        details,
      },
    },
    headers,
  );
}

function normalizeContentType(value: string): CanonicalContentType | null {
  const normalized = value.trim();

  switch (normalized) {
    case "text":
    case "photo":
    case "aiGenerated":
      return normalized;
    case "ai":
    case "ai_generated":
    case "ai-generated":
      return "aiGenerated";
    default:
      return null;
  }
}

function isLikelyURL(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "http:" || url.protocol === "https:";
  } catch {
    return false;
  }
}

function validatePayload(input: unknown):
  | { ok: true; value: AgentPostPayload }
  | { ok: false; issues: ValidationIssue[] } {
  if (input === null || typeof input !== "object" || Array.isArray(input)) {
    return {
      ok: false,
      issues: [{ field: "body", message: "Expected a JSON object payload." }],
    };
  }

  const body = input as Record<string, unknown>;
  const issues: ValidationIssue[] = [];

  const magnetID = typeof body.magnet_id === "string"
    ? body.magnet_id.trim()
    : "";
  if (!magnetID) {
    issues.push({
      field: "magnet_id",
      message: "magnet_id is required and must be a non-empty string.",
    });
  }

  const rawContentType = typeof body.content_type === "string"
    ? body.content_type
    : "";
  const contentType = normalizeContentType(rawContentType);
  if (!contentType) {
    issues.push({
      field: "content_type",
      message:
        "content_type must be one of: text, photo, aiGenerated (ai / ai_generated also normalize to aiGenerated).",
    });
  }

  if (typeof body.text_content !== "string") {
    issues.push({
      field: "text_content",
      message: "text_content is required and must be a string.",
    });
  }

  const textContent = typeof body.text_content === "string"
    ? body.text_content.trim()
    : "";

  const mediaURL = body.media_url == null
    ? null
    : typeof body.media_url === "string"
    ? body.media_url.trim()
    : "__invalid__";

  if (mediaURL === "__invalid__") {
    issues.push({
      field: "media_url",
      message: "media_url must be a string when provided.",
    });
  } else if (mediaURL && !isLikelyURL(mediaURL)) {
    issues.push({
      field: "media_url",
      message: "media_url must be an absolute http(s) URL when provided.",
    });
  }

  const authorName = body.author_name == null
    ? null
    : typeof body.author_name === "string"
    ? body.author_name.trim()
    : "__invalid__";

  if (authorName === "__invalid__") {
    issues.push({
      field: "author_name",
      message: "author_name must be a string when provided.",
    });
  } else if (authorName && authorName.length > 80) {
    issues.push({
      field: "author_name",
      message: "author_name must be 80 characters or fewer.",
    });
  }

  if (textContent.length > 4_000) {
    issues.push({
      field: "text_content",
      message: "text_content must be 4000 characters or fewer.",
    });
  }

  if (contentType === "photo" && !mediaURL && !textContent) {
    issues.push({
      field: "media_url",
      message:
        "photo posts must include media_url or a non-empty text_content.",
    });
  }

  if (contentType && contentType !== "photo" && !textContent) {
    issues.push({
      field: "text_content",
      message: `${contentType} posts must include a non-empty text_content.`,
    });
  }

  if (issues.length > 0 || !contentType) {
    return { ok: false, issues };
  }

  return {
    ok: true,
    value: {
      magnet_id: magnetID,
      content_type: contentType,
      text_content: textContent,
      media_url: mediaURL,
      author_name: authorName || null,
    },
  };
}

function pemToPKCS8Buffer(pem: string): ArrayBuffer {
  const normalized = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");

  const binary = atob(normalized);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes.buffer.slice(
    bytes.byteOffset,
    bytes.byteOffset + bytes.byteLength,
  );
}

async function importAPNsPrivateKey(pem: string): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "pkcs8",
    pemToPKCS8Buffer(pem),
    {
      name: "ECDSA",
      namedCurve: "P-256",
    },
    false,
    ["sign"],
  );
}

function bytesToBase64URL(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function utf8ToBase64URL(value: string): string {
  return bytesToBase64URL(new TextEncoder().encode(value));
}

async function getAPNsJWT(teamID: string, keyID: string, pem: string) {
  const nowMs = Date.now();
  if (cachedAPNsJWT && cachedAPNsJWT.expiresAtMs > nowMs + 60_000) {
    return cachedAPNsJWT.token;
  }

  const header = {
    alg: "ES256",
    kid: keyID,
    typ: "JWT",
  };
  const payload = {
    iss: teamID,
    iat: Math.floor(nowMs / 1000),
  };

  const encodedHeader = utf8ToBase64URL(JSON.stringify(header));
  const encodedPayload = utf8ToBase64URL(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const privateKey = await importAPNsPrivateKey(pem);
  const signature = await crypto.subtle.sign(
    {
      name: "ECDSA",
      hash: "SHA-256",
    },
    privateKey,
    new TextEncoder().encode(signingInput),
  );

  const token = `${signingInput}.${
    bytesToBase64URL(new Uint8Array(signature))
  }`;
  cachedAPNsJWT = {
    token,
    expiresAtMs: nowMs + 50 * 60 * 1_000,
  };

  return token;
}

function normalizeAPNsEnvironment(
  value: string | undefined,
): "production" | "development" {
  const normalized = (value ?? "development").trim().toLowerCase();
  if (normalized === "production" || normalized === "prod") {
    return "production";
  }
  return "development";
}

function getAPNsHost(environment: "production" | "development") {
  return environment === "production"
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";
}

function dedupeStrings(values: string[]) {
  return [...new Set(values)];
}

function getSupabaseAdminClient() {
  const supabaseURL = Deno.env.get(supabaseURLEnvName)?.trim();
  const serviceRoleKey = Deno.env.get(supabaseServiceRoleKeyEnvName)?.trim();
  const missingEnv = [
    !supabaseURL ? supabaseURLEnvName : null,
    !serviceRoleKey ? supabaseServiceRoleKeyEnvName : null,
  ].filter((value): value is string => Boolean(value));

  if (missingEnv.length > 0) {
    return {
      ok: false as const,
      required_env: missingEnv,
    };
  }

  return {
    ok: true as const,
    client: createClient(supabaseURL!, serviceRoleKey!, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    }),
  };
}

async function getWidgetPushTokens(
  magnetID: string,
): Promise<
  | { ok: true; deviceTokens: string[] }
  | { ok: false; required_env: string[]; details: unknown }
> {
  const supabaseAdmin = getSupabaseAdminClient();
  if (!supabaseAdmin.ok) {
    return {
      ok: false,
      required_env: supabaseAdmin.required_env,
      details: { reason: "missing_supabase_env" },
    };
  }

  const { data, error } = await supabaseAdmin.client
    .from("widget_push_tokens")
    .select("device_token")
    .eq("magnet_id", magnetID)
    .order("updated_at", { ascending: false });

  if (error) {
    return {
      ok: false,
      required_env: [supabaseURLEnvName, supabaseServiceRoleKeyEnvName],
      details: {
        code: error.code,
        message: error.message,
        details: error.details,
        hint: error.hint,
      },
    };
  }

  return {
    ok: true,
    deviceTokens: dedupeStrings(
      (data ?? []).flatMap((row) => {
        if (
          typeof row.device_token !== "string" ||
          row.device_token.trim().length === 0
        ) {
          return [];
        }
        return [row.device_token.trim()];
      }),
    ),
  };
}

function buildAPNsPayload(payload: AgentPostPayload) {
  return {
    aps: {
      "content-available": 1,
    },
    widget_refresh: true,
    magnet_id: payload.magnet_id,
    content_type: payload.content_type,
    text_content: payload.text_content,
    media_url: payload.media_url,
    author_name: payload.author_name,
  };
}

function tokenSuffix(token: string) {
  return token.slice(-8);
}

async function writePostToBackend(
  payload: AgentPostPayload,
): Promise<IntegrationResult> {
  const supabaseAdmin = getSupabaseAdminClient();
  if (!supabaseAdmin.ok) {
    return {
      status: "error",
      step: "backend_write",
      message:
        "Supabase admin client is not configured. Provide SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.",
      required_env: supabaseAdmin.required_env,
    };
  }

  const postRecord = {
    magnet_id: payload.magnet_id,
    content_type: payload.content_type,
    text_content: payload.text_content,
    media_url: payload.media_url,
    author_name: payload.author_name,
    created_at: new Date().toISOString(),
  };

  const { data, error } = await supabaseAdmin.client
    .from("posts")
    .insert(postRecord)
    .select(
      "magnet_id, content_type, text_content, media_url, author_name, created_at",
    )
    .single();

  if (error) {
    return {
      status: "error",
      step: "backend_write",
      message: "Failed to persist the post to the Supabase posts table.",
      required_env: [supabaseURLEnvName, supabaseServiceRoleKeyEnvName],
      details: {
        code: error.code,
        message: error.message,
        details: error.details,
        hint: error.hint,
      },
    };
  }

  return {
    status: "stored",
    step: "backend_write",
    message: "Post persisted to the Supabase posts table.",
    required_env: [supabaseURLEnvName, supabaseServiceRoleKeyEnvName],
    details: data ?? postRecord,
  };
}

async function sendWidgetPush(
  payload: AgentPostPayload,
): Promise<IntegrationResult> {
  const keyID = Deno.env.get(apnsKeyIDEnvName);
  const teamID = Deno.env.get(apnsTeamIDEnvName);
  const topic = Deno.env.get(apnsTopicEnvName);
  const privateKey = Deno.env.get(apnsPrivateKeyEnvName);
  const supabaseAdmin = getSupabaseAdminClient();
  const requiredEnv = dedupeStrings([
    !keyID ? apnsKeyIDEnvName : "",
    !teamID ? apnsTeamIDEnvName : "",
    !topic ? apnsTopicEnvName : "",
    !privateKey ? apnsPrivateKeyEnvName : "",
    ...(supabaseAdmin.ok ? [] : supabaseAdmin.required_env),
  ].filter((value): value is string => value.length > 0));

  if (requiredEnv.length > 0) {
    return {
      status: "todo",
      step: "widget_push",
      message:
        "APNs delivery or Supabase token lookup is not fully configured yet. Provide the missing env vars as hosted or local secrets.",
      required_env: requiredEnv,
    };
  }

  const tokenLookup = await getWidgetPushTokens(payload.magnet_id);
  if (!tokenLookup.ok) {
    return {
      status: "error",
      step: "widget_push",
      message:
        "Failed to load widget push tokens from the Supabase widget_push_tokens table.",
      required_env: tokenLookup.required_env,
      details: {
        magnet_id: payload.magnet_id,
        ...(
          typeof tokenLookup.details === "object" &&
            tokenLookup.details !== null
            ? tokenLookup.details
            : { details: tokenLookup.details }
        ),
      },
    };
  }

  const deviceTokens = tokenLookup.deviceTokens;

  if (deviceTokens.length === 0) {
    return {
      status: "todo",
      step: "widget_push",
      message:
        "APNs signing is wired, but no widget_push_tokens rows are registered for this magnet_id yet.",
      required_env: [supabaseURLEnvName, supabaseServiceRoleKeyEnvName],
      details: {
        magnet_id: payload.magnet_id,
      },
    };
  }

  const environment = normalizeAPNsEnvironment(
    Deno.env.get(apnsEnvironmentEnvName),
  );
  const host = getAPNsHost(environment);
  const jwt = await getAPNsJWT(teamID!, keyID!, privateKey!);
  const body = JSON.stringify(buildAPNsPayload(payload));

  const attempts: APNsAttempt[] = [];
  for (const token of deviceTokens) {
    try {
      const response = await fetch(`${host}/3/device/${token}`, {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": topic!,
          "apns-push-type": "background",
          "apns-priority": "5",
          "content-type": "application/json",
        },
        body,
      });

      attempts.push({
        token_suffix: tokenSuffix(token),
        ok: response.ok,
        status: response.status,
        response: await response.text(),
      });
    } catch (error) {
      attempts.push({
        token_suffix: tokenSuffix(token),
        ok: false,
        status: null,
        response: error instanceof Error ? error.message : String(error),
      });
    }
  }

  const sentCount = attempts.filter((attempt) => attempt.ok).length;
  if (sentCount === 0) {
    return {
      status: "error",
      step: "widget_push",
      message:
        "APNs send was attempted but every request failed. Check token freshness, APNs environment, topic, and the exact payload contract expected by WidgetPushHandler.",
      required_env: [
        apnsKeyIDEnvName,
        apnsTeamIDEnvName,
        apnsTopicEnvName,
        apnsPrivateKeyEnvName,
        apnsEnvironmentEnvName,
        supabaseURLEnvName,
        supabaseServiceRoleKeyEnvName,
      ],
      details: {
        environment,
        attempts,
      },
    };
  }

  return {
    status: "sent",
    step: "widget_push",
    message:
      "APNs requests were signed and sent using widget/device tokens loaded from Supabase. Final WidgetPushHandler payload semantics may still need refinement.",
    required_env: [
      apnsKeyIDEnvName,
      apnsTeamIDEnvName,
      apnsTopicEnvName,
      apnsPrivateKeyEnvName,
      apnsEnvironmentEnvName,
      supabaseURLEnvName,
      supabaseServiceRoleKeyEnvName,
    ],
    details: {
      environment,
      sent_count: sentCount,
      attempted_count: attempts.length,
      attempts,
    },
  };
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return errorResponse(
      405,
      "method_not_allowed",
      "Only POST is supported for this endpoint.",
      null,
      { allow: "POST" },
    );
  }

  const expectedBearerToken = Deno.env.get(bearerTokenEnvName);
  if (!expectedBearerToken) {
    return errorResponse(
      500,
      "server_misconfigured",
      `${bearerTokenEnvName} is not configured.`,
    );
  }

  const authorization = request.headers.get("authorization") ?? "";
  const [scheme, token] = authorization.split(/\s+/, 2);
  if (scheme !== "Bearer" || !token) {
    return errorResponse(401, "unauthorized", "Missing Bearer token.");
  }

  if (token !== expectedBearerToken) {
    return errorResponse(401, "unauthorized", "Bearer token did not match.");
  }

  const contentTypeHeader = request.headers.get("content-type") ?? "";
  if (!contentTypeHeader.toLowerCase().includes("application/json")) {
    return errorResponse(
      415,
      "unsupported_media_type",
      "Content-Type must include application/json.",
    );
  }

  let parsedBody: unknown;
  try {
    parsedBody = await request.json();
  } catch {
    return errorResponse(
      400,
      "invalid_json",
      "Request body must be valid JSON.",
    );
  }

  const validation = validatePayload(parsedBody);
  if (!validation.ok) {
    return errorResponse(
      422,
      "validation_failed",
      "Request payload is invalid.",
      validation.issues,
    );
  }

  const backendWrite = await writePostToBackend(validation.value);
  const widgetPush = await sendWidgetPush(validation.value);

  return jsonResponse(202, {
    ok: true,
    accepted: true,
    received_at: new Date().toISOString(),
    request: validation.value,
    integrations: {
      backend_write: backendWrite,
      widget_push: widgetPush,
    },
    notes: [
      "Backend persistence now inserts into the Supabase posts table.",
      "Widget/device tokens are loaded from the Supabase widget_push_tokens table before APNs delivery.",
      "The APNs payload is currently a generic silent push scaffold and may need refinement for the exact WidgetPushHandler contract.",
      "Do not store secrets in the repo.",
    ],
  });
});
