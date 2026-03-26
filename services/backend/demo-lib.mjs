const envelopeStore = new Map();
const feed = [];

function key(accountID, segmentID) {
  return `${accountID}:${segmentID}`;
}

function feedPositionFromVersion(syncVersion, segmentID) {
  const suffix = Number.parseInt(String(segmentID).replace(/[^0-9]/g, "").slice(-6) || "0", 10);
  return syncVersion * 1_000_000 + suffix;
}

function validateEnvelope(envelope) {
  if (!envelope?.segment?.id) return { code: "invalidPayload", message: "segment.id is required", field: "segment.id" };
  if (!envelope?.segment?.title) return { code: "invalidPayload", message: "segment.title is required", field: "segment.title" };
  if (!envelope?.sync?.lastModifiedByDeviceID) {
    return { code: "invalidPayload", message: "sync.lastModifiedByDeviceID is required", field: "sync.lastModifiedByDeviceID" };
  }
  if (envelope.interpretation && envelope.interpretation.segmentID !== envelope.segment.id) {
    return { code: "invalidPayload", message: "interpretation.segmentID must match segment.id", field: "interpretation.segmentID" };
  }
  if (envelope.summary && envelope.summary.segmentID !== envelope.segment.id) {
    return { code: "invalidPayload", message: "summary.segmentID must match segment.id", field: "summary.segmentID" };
  }
  return null;
}

export function createDemoBackend() {
  const nextFeedPositionByAccount = new Map();

  function nextFeedPosition(accountID) {
    const next = (nextFeedPositionByAccount.get(accountID) ?? 0) + 1;
    nextFeedPositionByAccount.set(accountID, next);
    return next;
  }

  return {
    push(body) {
      if (!body?.accountID || !Array.isArray(body?.changes)) {
        return { statusCode: 400, body: { code: "invalidPayload", message: "accountID and changes are required" } };
      }

      const accepted = [];
      const conflicts = [];

      for (const change of body.changes) {
        const validationError = validateEnvelope(change.segmentEnvelope);
        if (validationError) {
          return { statusCode: 422, body: validationError };
        }

        const envelope = change.segmentEnvelope;
        const storeKey = key(body.accountID, envelope.segment.id);
        const existing = envelopeStore.get(storeKey) ?? null;

        if (existing && change.baseSyncVersion !== existing.syncVersion) {
          conflicts.push({
            segmentID: envelope.segment.id,
            reason: existing.isDeleted ? "deletedOnServer" : "versionMismatch",
            serverEnvelope: existing.envelope,
          });
          continue;
        }

        if (existing?.isDeleted && envelope.sync.isDeleted === false) {
          conflicts.push({
            segmentID: envelope.segment.id,
            reason: "deletedOnServer",
            serverEnvelope: existing.envelope,
          });
          continue;
        }

        const nextVersion = existing ? existing.syncVersion + 1 : 1;
        const storedEnvelope = {
          ...envelope,
          sync: {
            ...envelope.sync,
            syncVersion: nextVersion,
          },
        };

        envelopeStore.set(storeKey, {
          accountID: body.accountID,
          segmentID: envelope.segment.id,
          envelope: storedEnvelope,
          syncVersion: nextVersion,
          isDeleted: storedEnvelope.sync.isDeleted,
          updatedAt: storedEnvelope.sync.lastModifiedAt,
        });

        feed.push({
          accountID: body.accountID,
          feedPosition: nextFeedPosition(body.accountID),
          segmentID: envelope.segment.id,
          syncVersion: nextVersion,
          changedAt: storedEnvelope.sync.lastModifiedAt,
          isDeleted: storedEnvelope.sync.isDeleted,
        });

        accepted.push({
          segmentID: envelope.segment.id,
          syncVersion: nextVersion,
          updatedAt: storedEnvelope.sync.lastModifiedAt,
        });
      }

      return { statusCode: 200, body: { accepted, conflicts } };
    },

    pull(body) {
      if (!body?.accountID) {
        return { statusCode: 400, body: { code: "invalidPayload", message: "accountID is required" } };
      }

      const cursorPosition = body.cursor ? Number.parseInt(body.cursor, 10) : 0;
      const accountEntries = feed
        .filter((entry) => entry.accountID === body.accountID && entry.feedPosition > cursorPosition)
        .sort((a, b) => a.feedPosition - b.feedPosition);

      const page = accountEntries.slice(0, 100);
      const changes = page
        .map((entry) => envelopeStore.get(key(body.accountID, entry.segmentID)))
        .filter(Boolean)
        .map((stored) => ({ segmentEnvelope: stored.envelope }));

      const nextCursor = String(page.length > 0 ? page[page.length - 1].feedPosition : cursorPosition);

      return {
        statusCode: 200,
        body: {
          changes,
          nextCursor,
          hasMore: accountEntries.length > page.length,
        },
      };
    },
  };
}
