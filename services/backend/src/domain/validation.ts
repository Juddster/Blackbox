import {
  ActivityClass,
  AmbiguityState,
  InterpretationOrigin,
  ObservationSourceDevice,
  PushChange,
  SegmentEnvelope,
  SegmentLifecycleState,
  SegmentOriginType,
  ValidationErrorPayload,
} from "./types.js";

const activityClasses = new Set<ActivityClass>([
  "stationary",
  "walking",
  "running",
  "cycling",
  "hiking",
  "vehicle",
  "flight",
  "waterActivity",
  "unknown",
]);

const lifecycleStates = new Set<SegmentLifecycleState>(["active", "unsettled", "settled", "deleted"]);
const originTypes = new Set<SegmentOriginType>(["system", "userCreated", "merged", "splitResult"]);
const devices = new Set<ObservationSourceDevice>(["iPhone", "watch"]);
const interpretationOrigins = new Set<InterpretationOrigin>(["system", "user", "mixed"]);
const ambiguityStates = new Set<AmbiguityState>(["clear", "mixed", "uncertain"]);

function makeError(message: string, field?: string): ValidationErrorPayload {
  return field
    ? { code: "invalidPayload", message, field }
    : { code: "invalidPayload", message };
}

function isIsoDateString(value: string): boolean {
  return Number.isNaN(Date.parse(value)) === false;
}

export function validatePushChange(change: PushChange): ValidationErrorPayload | null {
  return validateEnvelope(change.segmentEnvelope);
}

export function validateEnvelope(envelope: SegmentEnvelope): ValidationErrorPayload | null {
  const { segment, interpretation, summary, sync } = envelope;

  if (!segment.id) return makeError("segment.id is required", "segment.id");
  if (!segment.title) return makeError("segment.title is required", "segment.title");
  if (!lifecycleStates.has(segment.lifecycleState)) return makeError("segment.lifecycleState is invalid", "segment.lifecycleState");
  if (!originTypes.has(segment.originType)) return makeError("segment.originType is invalid", "segment.originType");
  if (!devices.has(segment.primaryDeviceHint)) return makeError("segment.primaryDeviceHint is invalid", "segment.primaryDeviceHint");

  if (!isIsoDateString(segment.startTime)) return makeError("segment.startTime must be ISO8601", "segment.startTime");
  if (!isIsoDateString(segment.endTime)) return makeError("segment.endTime must be ISO8601", "segment.endTime");
  if (!isIsoDateString(segment.createdAt)) return makeError("segment.createdAt must be ISO8601", "segment.createdAt");
  if (!isIsoDateString(segment.updatedAt)) return makeError("segment.updatedAt must be ISO8601", "segment.updatedAt");
  if (Date.parse(segment.endTime) < Date.parse(segment.startTime)) {
    return makeError("segment.endTime must not be earlier than segment.startTime", "segment.endTime");
  }

  if (!sync.lastModifiedByDeviceID) return makeError("sync.lastModifiedByDeviceID is required", "sync.lastModifiedByDeviceID");
  if (!isIsoDateString(sync.lastModifiedAt)) return makeError("sync.lastModifiedAt must be ISO8601", "sync.lastModifiedAt");
  if (sync.syncVersion < 0) return makeError("sync.syncVersion must be non-negative", "sync.syncVersion");

  if (interpretation) {
    if (interpretation.segmentID !== segment.id) {
      return makeError("interpretation.segmentID must match segment.id", "interpretation.segmentID");
    }
    if (!activityClasses.has(interpretation.visibleClass)) {
      return makeError("interpretation.visibleClass is invalid", "interpretation.visibleClass");
    }
    if (!ambiguityStates.has(interpretation.ambiguityState)) {
      return makeError("interpretation.ambiguityState is invalid", "interpretation.ambiguityState");
    }
    if (!interpretationOrigins.has(interpretation.interpretationOrigin)) {
      return makeError("interpretation.interpretationOrigin is invalid", "interpretation.interpretationOrigin");
    }
    if (interpretation.confidence < 0 || interpretation.confidence > 1) {
      return makeError("interpretation.confidence must be between 0 and 1", "interpretation.confidence");
    }
    if (!isIsoDateString(interpretation.updatedAt)) {
      return makeError("interpretation.updatedAt must be ISO8601", "interpretation.updatedAt");
    }
  }

  if (summary) {
    if (summary.segmentID !== segment.id) return makeError("summary.segmentID must match segment.id", "summary.segmentID");
    if (summary.durationSeconds < 0) return makeError("summary.durationSeconds must be non-negative", "summary.durationSeconds");
    if (summary.pauseCount < 0) return makeError("summary.pauseCount must be non-negative", "summary.pauseCount");
    const segmentDurationSeconds = (Date.parse(segment.endTime) - Date.parse(segment.startTime)) / 1000;
    if (Math.abs(summary.durationSeconds - segmentDurationSeconds) > 1) {
      return makeError("summary.durationSeconds must match the segment time range", "summary.durationSeconds");
    }
    for (const [field, value] of [
      ["summary.distanceMeters", summary.distanceMeters],
      ["summary.elevationGainMeters", summary.elevationGainMeters],
      ["summary.averageSpeedMetersPerSecond", summary.averageSpeedMetersPerSecond],
      ["summary.maxSpeedMetersPerSecond", summary.maxSpeedMetersPerSecond],
    ] as const) {
      if (value !== null && value < 0) return makeError(`${field} must be non-negative`, field);
    }
    if (!isIsoDateString(summary.updatedAt)) return makeError("summary.updatedAt must be ISO8601", "summary.updatedAt");
  }

  return null;
}
