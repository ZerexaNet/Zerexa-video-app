/**
 * Catch-all proxy to the Zerexa Video API.
 *
 * The remote API (https://video.zerexa.net) does not enable CORS,
 * so browser requests fail with "Failed to fetch". This route
 * forwards requests from /api/zerexa/<path> to the upstream and
 * streams the response back to the browser with the appropriate
 * CORS headers.
 *
 * Method, body, query string, and Authorization header are all
 * preserved. Non-JSON responses (e.g. images via /api/s3/object)
 * are passed through verbatim with their original content-type.
 */

import { NextRequest, NextResponse } from "next/server";

const UPSTREAM = "https://video.zerexa.net";

const ALLOWED_HEADERS = new Set([
  "authorization",
  "content-type",
  "accept",
  "user-agent",
  "x-requested-with",
]);

const EXPOSED_HEADERS = [
  "content-type",
  "cache-control",
  "etag",
  "last-modified",
  "content-length",
  "content-disposition",
];

export async function GET(
  req: NextRequest,
  ctx: { params: Promise<{ path?: string[] }> },
) {
  return handle(req, ctx);
}

export async function POST(
  req: NextRequest,
  ctx: { params: Promise<{ path?: string[] }> },
) {
  return handle(req, ctx);
}

export async function PUT(
  req: NextRequest,
  ctx: { params: Promise<{ path?: string[] }> },
) {
  return handle(req, ctx);
}

export async function DELETE(
  req: NextRequest,
  ctx: { params: Promise<{ path?: string[] }> },
) {
  return handle(req, ctx);
}

export async function PATCH(
  req: NextRequest,
  ctx: { params: Promise<{ path?: string[] }> },
) {
  return handle(req, ctx);
}

async function handle(
  req: NextRequest,
  ctx: { params: Promise<{ path?: string[] }> },
) {
  const { path = [] } = await ctx.params;
  const joined = Array.isArray(path) ? path.join("/") : "";
  const search = req.nextUrl.search ?? "";
  // The client passes paths like "/api/videos" through the proxy,
  // so we end up with `["api", "videos"]` here. We forward to
  // `${UPSTREAM}/${joined}` (no extra `/api` prefix) so the upstream
  // receives the same path the client originally intended.
  const target = `${UPSTREAM}/${joined}${search}`;

  // Build headers from the inbound request, filtering to a safe allowlist.
  const headers: Record<string, string> = {};
  req.headers.forEach((v, k) => {
    if (ALLOWED_HEADERS.has(k.toLowerCase())) headers[k] = v;
  });

  // Read body for non-GET requests
  let body: BodyInit | undefined;
  if (req.method !== "GET" && req.method !== "HEAD") {
    body = await req.text();
  }

  let upstream: Response;
  try {
    upstream = await fetch(target, {
      method: req.method,
      headers,
      body,
      // Do not follow redirects automatically; we want the client to see them.
      redirect: "manual",
    });
  } catch (e) {
    return NextResponse.json(
      {
        error: "upstream_unreachable",
        message: e instanceof Error ? e.message : "Failed to reach upstream",
        target,
      },
      { status: 502 },
    );
  }

  // Pass response back. We use a manual Response construction so
  // that binary content (images, videos) is forwarded intact without
  // trying to JSON.parse it.
  const respHeaders = new Headers();
  upstream.headers.forEach((v, k) => {
    if (EXPOSED_HEADERS.includes(k.toLowerCase()) || k.toLowerCase().startsWith("x-")) {
      respHeaders.set(k, v);
    }
  });
  // Add CORS header for the browser
  respHeaders.set("Access-Control-Allow-Origin", "*");
  respHeaders.set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS");
  respHeaders.set("Access-Control-Allow-Headers", "Authorization, Content-Type, Accept");

  // For redirects, also expose Location.
  const location = upstream.headers.get("location");
  if (location) respHeaders.set("location", location);

  const buffer = await upstream.arrayBuffer();
  return new Response(buffer, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers: respHeaders,
  });
}

export async function OPTIONS() {
  return new Response(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, PATCH, OPTIONS",
      "Access-Control-Allow-Headers": "Authorization, Content-Type, Accept",
      "Access-Control-Max-Age": "86400",
    },
  });
}
