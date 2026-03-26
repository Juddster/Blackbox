import { readFileSync } from "node:fs";
import path from "node:path";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

function loadJson(relativePath) {
  const absolutePath = path.resolve(process.cwd(), relativePath);
  return JSON.parse(readFileSync(absolutePath, "utf8"));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const ajv = new Ajv2020({
  allErrors: true,
  strict: true
});
addFormats(ajv);

const segmentEnvelopeSchema = loadJson("../../packages/shared/contracts/segment-envelope.schema.json");
const syncPushSchema = loadJson("../../packages/shared/contracts/sync-push.schema.json");
const syncPullSchema = loadJson("../../packages/shared/contracts/sync-pull.schema.json");

ajv.addSchema(segmentEnvelopeSchema);

const validatePush = ajv.compile(syncPushSchema);
const validatePull = ajv.compile(syncPullSchema);

const payloads = [
  {
    name: "push-request.valid.json",
    validator: validatePush,
    payload: loadJson("../../packages/shared/contracts/examples/push-request.valid.json")
  },
  {
    name: "push-response.valid.json",
    validator: validatePush,
    payload: loadJson("../../packages/shared/contracts/examples/push-response.valid.json")
  },
  {
    name: "pull-request.valid.json",
    validator: validatePull,
    payload: loadJson("../../packages/shared/contracts/examples/pull-request.valid.json")
  },
  {
    name: "pull-response.valid.json",
    validator: validatePull,
    payload: loadJson("../../packages/shared/contracts/examples/pull-response.valid.json")
  }
];

for (const { name, validator, payload } of payloads) {
  const valid = validator(payload);
  assert(valid, `${name} should validate but failed with ${ajv.errorsText(validator.errors)}`);
}

console.log("schema-contract-check: ok");
