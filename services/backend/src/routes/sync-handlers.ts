import { SyncService } from "../domain/sync-service";
import { PullRequest, PushRequest, ValidationErrorPayload } from "../domain/types";
import { PullHttpResult, PushHttpResult } from "./http-types";
import { validatePullRequestShape, validatePushRequestShape } from "./request-validation";

function isValidationErrorPayload(value: unknown): value is ValidationErrorPayload {
  return typeof value === "object" && value !== null && "code" in value;
}

export async function handlePush(service: SyncService, request: PushRequest): Promise<PushHttpResult> {
  const requestError = validatePushRequestShape(request);
  if (requestError) {
    return { statusCode: 400, body: requestError };
  }

  const result = await service.push(request);
  if (isValidationErrorPayload(result)) {
    return { statusCode: 422, body: result };
  }

  return { statusCode: 200, body: result };
}

export async function handlePull(service: SyncService, request: PullRequest): Promise<PullHttpResult> {
  const requestError = validatePullRequestShape(request);
  if (requestError) {
    return { statusCode: 400, body: requestError };
  }

  return {
    statusCode: 200,
    body: await service.pull(request),
  };
}
