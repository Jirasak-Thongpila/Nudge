import "dotenv/config";
import { createApp } from "./app";

const port = Number(process.env.PORT) || 3000;
const hostname = process.env.HOST || "0.0.0.0";
const app = createApp();

const isServerless = Boolean(
  process.env.VERCEL ||
  process.env.VERCEL_ENV ||
  process.env.AWS_LAMBDA_FUNCTION_NAME ||
  process.env.NODE_ENV === "production"
);

if (typeof Bun !== "undefined" && !isServerless) {
  app.listen({ port, hostname }, () => {
    console.log(`🚀 Nudge backend running at http://${hostname}:${port}`);
  });
}

export type App = typeof app;
export default app;
