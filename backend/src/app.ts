import { Elysia } from "elysia";
import { cors } from "@elysiajs/cors";
import { userRoutes } from "./routes/users";
import type { AuthPluginOptions } from "./plugins/auth";

export const createApp = (options?: AuthPluginOptions) =>
  new Elysia()
    .use(
      cors({
        origin: "*",
        methods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allowedHeaders: ["Content-Type", "x-device-uuid", "Authorization"],
      })
    )
    .get("/health", () => ({
      status: "ok",
      timestamp: new Date().toISOString(),
      service: "nudge-backend",
    }))
    .use(userRoutes(options));
