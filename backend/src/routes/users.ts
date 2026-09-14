import { Elysia } from "elysia";
import { authPlugin, type AuthPluginOptions } from "../plugins/auth";

export const userRoutes = (options?: AuthPluginOptions) =>
  new Elysia({ prefix: "/users" })
    .use(authPlugin(options))
    .get(
      "/me",
      ({ currentUser }) => {
        return {
          success: true,
          data: {
            id: currentUser!.id,
            deviceUuid: currentUser!.deviceUuid,
            lineUserId: currentUser!.lineUserId,
            createdAt: currentUser!.createdAt,
          },
        };
      },
      {
        requireAuth: true,
      }
    );
