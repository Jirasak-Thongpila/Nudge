import "dotenv/config";
import { createApp } from "./app";

const port = Number(process.env.PORT) || 3000;
const hostname = process.env.HOST || "0.0.0.0";
const app = createApp();

app.listen({ port, hostname }, () => {
  console.log(`🚀 Nudge backend running at http://${hostname}:${port}`);
});

export type App = typeof app;
