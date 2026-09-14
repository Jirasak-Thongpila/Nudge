import { Elysia } from "elysia";
import { authPlugin, type AuthPluginOptions } from "../plugins/auth";
import { TaskService, taskService as defaultTaskService } from "../services/task.service";

export interface DashboardRouteOptions extends AuthPluginOptions {
  taskService?: TaskService;
}

export const dashboardRoutes = (options?: DashboardRouteOptions) => {
  const tSvc = options?.taskService ?? defaultTaskService;

  return new Elysia({ prefix: "/dashboard" })
    .use(authPlugin(options))
    .get(
      "/",
      async ({ currentUser }) => {
        const dashboardData = await tSvc.getDashboard(currentUser!.id);
        return {
          success: true,
          data: dashboardData,
        };
      },
      {
        requireAuth: true,
      }
    );
};
