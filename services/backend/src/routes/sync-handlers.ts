import { SyncService } from "../domain/sync-service";
import { PullRequest, PushRequest } from "../domain/types";

export async function handlePush(service: SyncService, request: PushRequest) {
  return service.push(request);
}

export async function handlePull(service: SyncService, request: PullRequest) {
  return service.pull(request);
}
