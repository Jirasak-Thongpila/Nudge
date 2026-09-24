import "dotenv/config";
import { createApp } from "./app";

const port = Number(process.env.PORT) || 3000;
const hostname = process.env.HOST || "0.0.0.0";
const app = createApp();

if (typeof Bun !== "undefined" && !process.env.VERCEL && !process.env.AWS_LAMBDA_FUNCTION_NAME) {
  app.listen({ port, hostname }, () => {
    console.log(`🚀 Nudge backend running at http://${hostname}:${port}`);
  });
}

export type App = typeof app;
export default app;
