import { Elysia } from "elysia";
import { cors } from "@elysiajs/cors";
import { userRoutes } from "./routes/users";
import { taskRoutes, type TaskRouteOptions } from "./routes/tasks";
import { dashboardRoutes } from "./routes/dashboard";

export const createApp = (options?: TaskRouteOptions) =>
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
    .use(userRoutes(options))
    .use(taskRoutes(options))
    .use(dashboardRoutes(options));
