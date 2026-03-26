import { createNodeHttpServer } from "./node-http-server.js";
import { createConfiguredStores } from "../storage/configured.js";

const port = Number.parseInt(process.env.PORT || "8787", 10);
const host = process.env.HOST || "127.0.0.1";
const stores = createConfiguredStores();

const server = createNodeHttpServer(stores.envelopeStore, stores.feedStore);

server.listen(port, host, () => {
  const storageInfo = stores.mode === "file"
    ? `file storage at ${stores.snapshotPath}`
    : "in-memory storage";
  console.log(`Blackbox backend listening on http://${host}:${port} using ${storageInfo}`);
});
