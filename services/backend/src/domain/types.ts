export type ActivityClass =
  | "stationary"
  | "walking"
  | "running"
  | "cycling"
  | "hiking"
  | "vehicle"
  | "flight"
  | "waterActivity"
  | "unknown";

export type SegmentLifecycleState = "active" | "unsettled" | "settled" | "deleted";
export type SegmentOriginType = "system" | "userCreated" | "merged" | "splitResult";
export type ObservationSourceDevice = "iPhone" | "watch";
export type InterpretationOrigin = "system" | "user" | "mixed";
export type AmbiguityState = "clear" | "mixed" | "uncertain";

export interface SegmentPayload {
  id: string;
  startTime: string;
  endTime: string;
  lifecycleState: SegmentLifecycleState;
  originType: SegmentOriginType;
  primaryDeviceHint: ObservationSourceDevice;
  title: string;
  createdAt: string;
  updatedAt: string;
}

export interface SegmentInterpretationPayload {
  id: string;
  segmentID: string;
  visibleClass: ActivityClass;
  userSelectedClass: string | null;
  confidence: number;
  ambiguityState: AmbiguityState;
  needsReview: boolean;
  interpretationOrigin: InterpretationOrigin;
  updatedAt: string;
}

export interface SegmentSummaryPayload {
  id: string;
  segmentID: string;
  durationSeconds: number;
  distanceMeters: number | null;
  elevationGainMeters: number | null;
  averageSpeedMetersPerSecond: number | null;
  maxSpeedMetersPerSecond: number | null;
  pauseCount: number;
  updatedAt: string;
}

export interface SyncMetadataPayload {
  lastModifiedByDeviceID: string;
  lastModifiedAt: string;
  syncVersion: number;
  isDeleted: boolean;
}

export interface SegmentEnvelope {
  segment: SegmentPayload;
  interpretation?: SegmentInterpretationPayload | null;
  summary?: SegmentSummaryPayload | null;
  sync: SyncMetadataPayload;
}

export interface PushChange {
  segmentEnvelope: SegmentEnvelope;
  baseSyncVersion?: number;
}

export interface PushRequest {
  deviceID: string;
  accountID: string;
  changes: PushChange[];
}

export interface AcceptedPush {
  segmentID: string;
  syncVersion: number;
  updatedAt: string;
}

export type ConflictReason = "versionMismatch" | "deletedOnServer";

export interface PushConflict {
  segmentID: string;
  reason: ConflictReason;
  serverEnvelope: SegmentEnvelope;
}

export interface PushResponse {
  accepted: AcceptedPush[];
  conflicts: PushConflict[];
}

export interface PullRequest {
  deviceID: string;
  accountID: string;
  cursor?: string;
}

export interface PullResponse {
  changes: Array<{ segmentEnvelope: SegmentEnvelope }>;
  nextCursor: string;
  hasMore: boolean;
}

export interface ValidationErrorPayload {
  code: "invalidPayload";
  message: string;
  field?: string;
}

export interface SyncFeedEntry {
  accountID: string;
  feedPosition: number;
  segmentID: string;
  syncVersion: number;
  changedAt: string;
  isDeleted: boolean;
}
