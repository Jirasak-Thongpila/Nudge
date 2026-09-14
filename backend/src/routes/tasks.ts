import { Elysia, t } from "elysia";
import { authPlugin, type AuthPluginOptions } from "../plugins/auth";
import { TaskService, taskService as defaultTaskService } from "../services/task.service";

export interface TaskRouteOptions extends AuthPluginOptions {
  taskService?: TaskService;
}

export const taskRoutes = (options?: TaskRouteOptions) => {
  const tSvc = options?.taskService ?? defaultTaskService;

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
    );
};
