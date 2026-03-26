import { createDefaultNodeHttpServer } from "./node-http-server.js";

const port = Number.parseInt(process.env.PORT || "8787", 10);
const host = process.env.HOST || "127.0.0.1";

const server = createDefaultNodeHttpServer();

server.listen(port, host, () => {
  console.log(`Blackbox backend listening on http://${host}:${port}`);
});
