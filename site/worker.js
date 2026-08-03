import { EmailMessage } from "cloudflare:email";

const CONTACT_PATH = "/api/contact";
const PUBLIC_CONTACT = "contact@lafayette-consulting.us";
const DELIVERY_ADDRESS = "david.demri@gmail.com";
const SENDER_ADDRESS = "website@lafayette-consulting.us";
const ALLOWED_ORIGINS = new Set([
  "https://lafayette-consulting.us",
  "https://www.lafayette-consulting.us",
]);
const PROJECTS = new Set([
  "Digital product",
  "Business transformation",
  "CRM or ERP",
  "Commerce or website",
  "Integration or automation",
  "Something else",
]);

function json(body, status = 200) {
  return Response.json(body, {
    status,
    headers: {
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

function cleanLine(value, maxLength) {
  return String(value ?? "")
    .replace(/[\r\n\0]+/g, " ")
    .trim()
    .slice(0, maxLength);
}

function cleanMessage(value) {
  return String(value ?? "")
    .replace(/\0/g, "")
    .replace(/\r\n?/g, "\n")
    .trim()
    .slice(0, 4000);
}

function isEmail(value) {
  return value.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function utf8Base64(value) {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function foldBase64(value) {
  return utf8Base64(value).match(/.{1,76}/g)?.join("\r\n") ?? "";
}

function encodedHeader(value) {
  return `=?UTF-8?B?${utf8Base64(value)}?=`;
}

function makeEmail({ name, email, company, project, message }) {
  const subject = `Lafayette website inquiry — ${project} — ${name}`;
  const text = [
    "New inquiry from lafayette-consulting.us",
    "",
    `Name: ${name}`,
    `Email: ${email}`,
    `Company: ${company || "Not provided"}`,
    `Project: ${project}`,
    "",
    "Message:",
    message,
  ].join("\n");

  const raw = [
    `From: Lafayette Website <${SENDER_ADDRESS}>`,
    `To: Lafayette Consulting <${PUBLIC_CONTACT}>`,
    `Reply-To: ${email}`,
    `Subject: ${encodedHeader(subject)}`,
    `Date: ${new Date().toUTCString()}`,
    `Message-ID: <${crypto.randomUUID()}@lafayette-consulting.us>`,
    "MIME-Version: 1.0",
    "Content-Type: text/plain; charset=UTF-8",
    "Content-Transfer-Encoding: base64",
    "X-Lafayette-Contact: website",
    "",
    foldBase64(text),
  ].join("\r\n");

  // The envelope goes to the verified Gmail destination. The visible To header
  // remains the public Lafayette address so existing Gmail labels keep working.
  return new EmailMessage(SENDER_ADDRESS, DELIVERY_ADDRESS, raw);
}

async function handleContact(request, env) {
  if (request.method !== "POST") {
    return json({ ok: false, error: "Method not allowed" }, 405);
  }

  const origin = request.headers.get("Origin");
  const url = new URL(request.url);
  const localDevelopment = ["localhost", "127.0.0.1"].includes(url.hostname);
  if ((!localDevelopment && !ALLOWED_ORIGINS.has(origin)) || (localDevelopment && origin !== url.origin)) {
    return json({ ok: false, error: "Forbidden" }, 403);
  }

  if (!request.headers.get("Content-Type")?.toLowerCase().startsWith("application/json")) {
    return json({ ok: false, error: "Unsupported content type" }, 415);
  }

  const contentLength = Number(request.headers.get("Content-Length") || 0);
  if (contentLength > 16_000) {
    return json({ ok: false, error: "Request too large" }, 413);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return json({ ok: false, error: "Invalid request" }, 400);
  }

  if (cleanLine(body.website, 200)) {
    return json({ ok: true });
  }

  const startedAt = Number(body.formStartedAt);
  const elapsed = Date.now() - startedAt;
  if (!Number.isFinite(startedAt) || elapsed < 1_500 || elapsed > 86_400_000) {
    return json({ ok: false, error: "Invalid request" }, 400);
  }

  const submission = {
    name: cleanLine(body.name, 80),
    email: cleanLine(body.email, 254).toLowerCase(),
    company: cleanLine(body.company, 120),
    project: cleanLine(body.project, 80),
    message: cleanMessage(body.message),
  };

  if (
    submission.name.length < 2 ||
    !isEmail(submission.email) ||
    !PROJECTS.has(submission.project) ||
    submission.message.length < 10
  ) {
    return json({ ok: false, error: "Please check the form fields" }, 422);
  }

  try {
    await env.CONTACT_EMAIL.send(makeEmail(submission));
    return json({ ok: true });
  } catch (error) {
    console.error("Contact email failed", error?.code || "EMAIL_SEND_FAILED", error?.message || "Unknown email error");
    const status = error?.code === "E_RATE_LIMIT_EXCEEDED" ? 429 : 503;
    return json({ ok: false, error: "Email delivery failed" }, status);
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === CONTACT_PATH) return handleContact(request, env);
    return env.ASSETS.fetch(request);
  },
};
