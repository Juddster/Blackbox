import { runSmokeExample } from "../dist/demo/smoke-example.js";

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const result = await runSmokeExample();

assert(Array.isArray(result.pushResult.accepted), "built smoke push should return accepted changes");
assert(result.pushResult.accepted.length === 1, "built smoke push should accept one change");
assert(result.pullResult.changes.length === 1, "built smoke pull should return one change");
assert(result.pullResult.nextCursor === "1", "built smoke pull should advance the cursor");

console.log("built-backend-check: ok");
