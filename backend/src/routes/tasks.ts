import { Elysia, t } from "elysia";
import { authPlugin, type AuthPluginOptions } from "../plugins/auth";
import { TaskService, taskService as defaultTaskService } from "../services/task.service";
import { FocusService, focusService as defaultFocusService } from "../services/focus.service";

export interface TaskRouteOptions extends AuthPluginOptions {
  taskService?: TaskService;
  focusService?: FocusService;
}

export const taskRoutes = (options?: TaskRouteOptions) => {
  const tSvc = options?.taskService ?? defaultTaskService;
  const fSvc = options?.focusService ?? defaultFocusService;

  return new Elysia({ prefix: "/tasks" })
    .use(authPlugin(options))
    .post(
      "/",
      async ({ currentUser, body, set }) => {
        try {
          const task = await tSvc.createTask(currentUser!.id, body);
          set.status = 201;
          return {
            success: true,
            data: task,
          };
        } catch (error: any) {
          set.status = 400;
          return {
            success: false,
            error: error?.message || "Failed to create task",
          };
        }
      },
      {
        requireAuth: true,
        body: t.Object({
          title: t.String({ minLength: 1 }),
          deadline: t.String(),
          importance: t.Number({ minimum: 1, maximum: 5 }),
          estimatedMinutes: t.Number({ minimum: 1 }),
        }),
      }
    )
    .get(
      "/",
      async ({ currentUser }) => {
        const userTasks = await tSvc.getTasksForUser(currentUser!.id);
        return {
          success: true,
          data: userTasks,
        };
      },
      {
        requireAuth: true,
      }
    )
    .get(
      "/recommended",
      async ({ currentUser }) => {
        const recommendation = await tSvc.getRecommendedTask(currentUser!.id);
        return {
          success: true,
          data: recommendation,
        };
      },
      {
        requireAuth: true,
      }
    )
    .get(
      "/:id",
      async ({ currentUser, params: { id }, set }) => {
        try {
          const taskId = Number(id);
          if (isNaN(taskId)) {
            set.status = 400;
            return {
              success: false,
              error: "Invalid task ID",
            };
          }

          const task = await tSvc.getTaskById(currentUser!.id, taskId);
          return {
            success: true,
            data: task,
          };
        } catch (error: any) {
          if (error?.message === "Task not found") {
            set.status = 404;
          } else {
            set.status = 400;
          }
          return {
            success: false,
            error: error?.message || "Failed to fetch task",
          };
        }
      },
      {
        requireAuth: true,
        params: t.Object({
          id: t.String(),
        }),
      }
    )
    .patch(
      "/:id",
      async ({ currentUser, params: { id }, body, set }) => {
        try {
          const taskId = Number(id);
          if (isNaN(taskId)) {
            set.status = 400;
            return {
              success: false,
              error: "Invalid task ID",
            };
          }

          const updated = await tSvc.updateTask(
            currentUser!.id,
            taskId,
            body
          );

          return {
            success: true,
            data: updated,
          };
        } catch (error: any) {
          if (error?.message === "Task not found") {
            set.status = 404;
          } else {
            set.status = 400;
          }
          return {
            success: false,
            error: error?.message || "Failed to update task",
          };
        }
      },
      {
        requireAuth: true,
        params: t.Object({
          id: t.String(),
        }),
        body: t.Object({
          title: t.Optional(t.String({ minLength: 1 })),
          deadline: t.Optional(t.String()),
          importance: t.Optional(t.Number({ minimum: 1, maximum: 5 })),
          estimatedMinutes: t.Optional(t.Number({ minimum: 1 })),
          status: t.Optional(
            t.Union([
              t.Literal("NOT_STARTED"),
              t.Literal("IN_PROGRESS"),
              t.Literal("COMPLETED"),
            ])
          ),
        }),
      }
    )
    .delete(
      "/:id",
      async ({ currentUser, params: { id }, set }) => {
        try {
          const taskId = Number(id);
          if (isNaN(taskId)) {
            set.status = 400;
            return {
              success: false,
              error: "Invalid task ID",
            };
          }

          await tSvc.softDeleteTask(currentUser!.id, taskId);
          return {
            success: true,
            message: "Task deleted successfully",
          };
        } catch (error: any) {
          if (error?.message === "Task not found") {
            set.status = 404;
          } else {
            set.status = 400;
          }
          return {
            success: false,
            error: error?.message || "Failed to delete task",
          };
        }
      },
      {
        requireAuth: true,
        params: t.Object({
          id: t.String(),
        }),
      }
    )
    .post(
      "/:id/postpone",
      async ({ currentUser, params: { id }, set }) => {
        try {
          const taskId = Number(id);
          if (isNaN(taskId)) {
            set.status = 400;
            return {
              success: false,
              error: "Invalid task ID",
            };
          }

          const updated = await tSvc.postponeTask(currentUser!.id, taskId);
          return {
            success: true,
            data: updated,
          };
        } catch (error: any) {
          if (error?.message === "Task not found") {
            set.status = 404;
          } else {
            set.status = 400;
          }
          return {
            success: false,
            error: error?.message || "Failed to postpone task",
          };
        }
      },
      {
        requireAuth: true,
        params: t.Object({
          id: t.String(),
        }),
      }
    )
    .post(
      "/:id/start",
      async ({ currentUser, params: { id }, set }) => {
        try {
          const taskId = Number(id);
          if (isNaN(taskId)) {
            set.status = 400;
            return {
              success: false,
              error: "Invalid task ID",
            };
          }

          const result = await fSvc.startFocusSession(currentUser!.id, taskId);
          return {
            success: true,
            data: result,
          };
        } catch (error: any) {
          if (error?.message === "Task not found") {
            set.status = 404;
          } else {
            set.status = 400;
          }
          return {
            success: false,
            error: error?.message || "Failed to start focus session",
          };
        }
      },
      {
        requireAuth: true,
        params: t.Object({
          id: t.String(),
        }),
      }
    );
};
