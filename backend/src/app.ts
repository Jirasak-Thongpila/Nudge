import { Elysia } from "elysia";
import { cors } from "@elysiajs/cors";
import { userRoutes } from "./routes/users";
import { taskRoutes, type TaskRouteOptions } from "./routes/tasks";
import { dashboardRoutes } from "./routes/dashboard";
import { focusRoutes, type FocusRouteOptions } from "./routes/focus";
import { lineRoutes, type LineRouteOptions } from "./routes/line";

export type AppOptions = TaskRouteOptions & FocusRouteOptions & LineRouteOptions;

export const createApp = (options?: AppOptions) =>
  new Elysia()
    .use(
      cors({
        origin: "*",
        methods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allowedHeaders: ["Content-Type", "x-device-uuid", "x-line-user-id", "Authorization"],
      })
    )
    .get("/health", () => ({
      status: "ok",
      timestamp: new Date().toISOString(),
      service: "nudge-backend",
    }))
    .use(userRoutes(options))
    .use(taskRoutes(options))
    .use(dashboardRoutes(options))
    .use(focusRoutes(options))
    .use(lineRoutes(options));
