import { PullRequest, PushRequest, ValidationErrorPayload } from "../domain/types";

function invalid(message: string, field?: string): ValidationErrorPayload {
  return field ? { code: "invalidPayload", message, field } : { code: "invalidPayload", message };
}

export function validatePushRequestShape(request: PushRequest): ValidationErrorPayload | null {
  if (!request.deviceID) return invalid("deviceID is required", "deviceID");
  if (!request.accountID) return invalid("accountID is required", "accountID");
  if (Array.isArray(request.changes) === false) return invalid("changes must be an array", "changes");
  return null;
}

export function validatePullRequestShape(request: PullRequest): ValidationErrorPayload | null {
  if (!request.deviceID) return invalid("deviceID is required", "deviceID");
  if (!request.accountID) return invalid("accountID is required", "accountID");
  return null;
}
