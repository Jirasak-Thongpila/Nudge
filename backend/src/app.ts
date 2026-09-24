import { Elysia } from "elysia";
import { cors } from "@elysiajs/cors";
import { userRoutes } from "./routes/users";
import { taskRoutes, type TaskRouteOptions } from "./routes/tasks";
import { dashboardRoutes } from "./routes/dashboard";
import { focusRoutes, type FocusRouteOptions } from "./routes/focus";
import { lineRoutes, type LineRouteOptions } from "./routes/line";
import { nudgeRoutes, type NudgeRouteOptions } from "./routes/nudges";

export type AppOptions = TaskRouteOptions & FocusRouteOptions & LineRouteOptions & NudgeRouteOptions;

export const createApp = (options?: AppOptions) =>
  new Elysia()
    .use(
      cors({
        origin: "*",
        methods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allowedHeaders: [
          "Content-Type",
          "x-device-uuid",
          "x-line-user-id",
          "x-nudge-dispatch-key",
          "Authorization",
        ],
      })
    )
    .get("/", () => ({
      status: "ok",
      name: "Nudge API",
      version: "0.1.0",
      timestamp: new Date().toISOString(),
      endpoints: {
        health: "/health",
        tasks: "/tasks",
        dashboard: "/dashboard",
        lineWebhook: "/line/webhook",
        nudgesDispatch: "/nudges/dispatch",
      },
    }))
    .get("/health", () => ({
      status: "ok",
      timestamp: new Date().toISOString(),
      service: "nudge-backend",
    }))
    .onError(({ code, error, set }) => {
      if (code === "NOT_FOUND") {
        set.status = 404;
        return {
          success: false,
          error: "Endpoint not found",
        };
      }
      if (code === "VALIDATION") {
        set.status = 422;
        return {
          success: false,
          error: (error as any)?.message || "Validation error",
        };
      }
      console.error("Unhandled error:", error);
      set.status = 500;
      return {
        success: false,
        error: (error as any)?.message || "Internal server error",
      };
    })
    .use(userRoutes(options))
    .use(taskRoutes(options))
    .use(dashboardRoutes(options))
    .use(focusRoutes(options))
    .use(lineRoutes(options))
    .use(nudgeRoutes(options));
