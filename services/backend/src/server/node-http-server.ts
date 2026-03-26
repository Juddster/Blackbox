import { createServer, IncomingMessage, ServerResponse } from "node:http";
import { SyncService } from "../domain/sync-service.js";
import { EnvelopeStore, SyncFeedStore } from "../storage/interfaces.js";
import { InMemoryEnvelopeStore, InMemorySyncFeedStore } from "../storage/memory.js";
import { handlePull, handlePush } from "../routes/sync-handlers.js";
import { parseJsonRequestBody } from "./request-body.js";

function sendJson(response: ServerResponse, statusCode: number, body: unknown): void {
  response.writeHead(statusCode, { "content-type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(body, null, 2));
}

async function handlePushRequest(
  request: IncomingMessage,
  response: ServerResponse,
  service: SyncService
): Promise<void> {
  let body: unknown;

  try {
    body = await parseJsonRequestBody(request);
  } catch {
    sendJson(response, 400, { code: "invalidPayload", message: "Malformed JSON" });
    return;
  }

  const result = await handlePush(service, body as never);
  sendJson(response, result.statusCode, result.body);
}

async function handlePullRequest(
  request: IncomingMessage,
  response: ServerResponse,
  service: SyncService
): Promise<void> {
  let body: unknown;

  try {
    body = await parseJsonRequestBody(request);
  } catch {
    sendJson(response, 400, { code: "invalidPayload", message: "Malformed JSON" });
    return;
  }

  const result = await handlePull(service, body as never);
  sendJson(response, result.statusCode, result.body);
}

export function createNodeHttpServer(
  service = new SyncService(new InMemoryEnvelopeStore(), new InMemorySyncFeedStore())
) {
  return createServer(async (request, response) => {
    if (request.method === "POST" && request.url === "/v1/sync/push") {
      await handlePushRequest(request, response, service);
      return;
    }

    if (request.method === "POST" && request.url === "/v1/sync/pull") {
      await handlePullRequest(request, response, service);
      return;
    }

    if (request.method === "GET" && request.url === "/health") {
      sendJson(response, 200, { ok: true });
      return;
    }

    sendJson(response, 404, { code: "notFound", message: "Route not found" });
  });
}

export function createDefaultNodeHttpServer(
  envelopeStore: EnvelopeStore = new InMemoryEnvelopeStore(),
  feedStore: SyncFeedStore = new InMemorySyncFeedStore()
) {
  return createNodeHttpServer(new SyncService(envelopeStore, feedStore));
}
