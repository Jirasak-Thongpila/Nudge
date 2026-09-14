import { Elysia, t } from "elysia";
import { authPlugin, type AuthPluginOptions } from "../plugins/auth";
import { FocusService, focusService as defaultFocusService } from "../services/focus.service";

export interface FocusRouteOptions extends AuthPluginOptions {
  focusService?: FocusService;
}

export const focusRoutes = (options?: FocusRouteOptions) => {
  const fSvc = options?.focusService ?? defaultFocusService;

  return new Elysia({ prefix: "/focus" })
    .use(authPlugin(options))
    .post(
      "/sessions",
      async ({ currentUser, body, set }) => {
        try {
          const session = await fSvc.recordFocusSession(currentUser!.id, {
            taskId: body.taskId,
            durationMinutes: body.durationMinutes,
            completed: body.completed,
          });
          set.status = 201;
          return {
            success: true,
            data: session,
          };
        } catch (error: any) {
          if (error?.message === "Task not found") {
            set.status = 404;
          } else {
            set.status = 400;
          }
          return {
            success: false,
            error: error?.message || "Failed to record focus session",
          };
        }
      },
      {
        requireAuth: true,
        body: t.Object({
          taskId: t.Number(),
          durationMinutes: t.Number({ minimum: 0 }),
          completed: t.Boolean(),
        }),
      }
    )
    .get(
      "/sessions",
      async ({ currentUser, query, set }) => {
        try {
          const taskId = Number(query.taskId);
          if (isNaN(taskId)) {
            set.status = 400;
            return {
              success: false,
              error: "taskId query parameter is required and must be a number",
            };
          }

          const sessions = await fSvc.getSessionsForTask(currentUser!.id, taskId);
          return {
            success: true,
            data: sessions,
          };
        } catch (error: any) {
          if (error?.message === "Task not found") {
            set.status = 404;
          } else {
            set.status = 400;
          }
          return {
            success: false,
            error: error?.message || "Failed to get focus sessions",
          };
        }
      },
      {
        requireAuth: true,
        query: t.Object({
          taskId: t.String(),
        }),
      }
    );
};
