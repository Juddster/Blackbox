import { createServer } from "node:http";
import { createDemoBackend } from "./demo-lib.mjs";

const backend = createDemoBackend();

function sendJson(res, statusCode, body) {
  res.writeHead(statusCode, { "content-type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(body, null, 2));
}

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (chunk) => {
      data += chunk;
    });
    req.on("end", () => {
      try {
        resolve(data ? JSON.parse(data) : {});
      } catch (error) {
        reject(error);
      }
    });
    req.on("error", reject);
  });
}

async function handlePush(req, res) {
  let body;
  try {
    body = await parseBody(req);
  } catch {
    sendJson(res, 400, { code: "invalidPayload", message: "Malformed JSON" });
    return;
  }

  const result = backend.push(body);
  sendJson(res, result.statusCode, result.body);
}

async function handlePull(req, res) {
  let body;
  try {
    body = await parseBody(req);
  } catch {
    sendJson(res, 400, { code: "invalidPayload", message: "Malformed JSON" });
    return;
  }

  const result = backend.pull(body);
  sendJson(res, result.statusCode, result.body);
}

const server = createServer(async (req, res) => {
  if (req.method === "POST" && req.url === "/v1/sync/push") {
    await handlePush(req, res);
    return;
  }

  if (req.method === "POST" && req.url === "/v1/sync/pull") {
    await handlePull(req, res);
    return;
  }

  if (req.method === "GET" && req.url === "/health") {
    sendJson(res, 200, { ok: true });
    return;
  }

  sendJson(res, 404, { code: "notFound", message: "Route not found" });
});

const port = Number.parseInt(process.env.PORT || "8787", 10);
const host = process.env.HOST || "127.0.0.1";
server.listen(port, host, () => {
  console.log(`Blackbox demo backend listening on http://${host}:${port}`);
});
