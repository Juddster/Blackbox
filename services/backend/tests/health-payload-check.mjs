import { createHealthPayload } from "../dist/index.js";

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const memoryPayload = createHealthPayload({ mode: "memory" });
assert(memoryPayload.ok === true, "health payload should report ok");
assert(memoryPayload.storageMode === "memory", "memory payload should report memory mode");
assert(!("snapshotPath" in memoryPayload), "memory payload should omit snapshotPath");

const filePayload = createHealthPayload({
  mode: "file",
  snapshotPath: "/tmp/blackbox/sync-state.json"
});
assert(filePayload.storageMode === "file", "file payload should report file mode");
assert(filePayload.snapshotPath === "/tmp/blackbox/sync-state.json", "file payload should include snapshotPath");

console.log("health-payload-check: ok");
