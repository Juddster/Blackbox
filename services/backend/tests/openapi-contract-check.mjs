import { readFileSync } from "node:fs";
import path from "node:path";

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const specPath = path.resolve(process.cwd(), "contracts/openapi.json");
const spec = JSON.parse(readFileSync(specPath, "utf8"));

assert(spec.openapi === "3.1.0", "OpenAPI spec should declare version 3.1.0");
assert(spec.paths["/v1/sync/push"], "OpenAPI spec should include /v1/sync/push");
assert(spec.paths["/v1/sync/pull"], "OpenAPI spec should include /v1/sync/pull");
assert(spec.paths["/health"], "OpenAPI spec should include /health");
assert(spec.components?.schemas?.ValidationError, "OpenAPI spec should include ValidationError schema");

console.log("openapi-contract-check: ok");
