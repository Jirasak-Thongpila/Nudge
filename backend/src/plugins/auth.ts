import { Elysia } from "elysia";
import { UserService, userService as defaultUserService } from "../services/user.service";
import type { User } from "../db/schema";

export interface AuthPluginOptions {
  userService?: UserService;
}

export const authPlugin = (options?: AuthPluginOptions) => {
  const svc = options?.userService ?? defaultUserService;

  return new Elysia({ name: "nudge-auth" })
    .derive({ as: "scoped" }, async ({ headers }) => {
      const deviceUuid = headers["x-device-uuid"];
      if (!deviceUuid || typeof deviceUuid !== "string" || deviceUuid.trim() === "") {
        return {
          currentUser: null as User | null,
          deviceUuid: null as string | null,
          authError: "missing_header",
        };
      }

      try {
        const user = await svc.getOrCreateUser(deviceUuid.trim());
        return {
          currentUser: user as User | null,
          deviceUuid: deviceUuid.trim(),
          authError: null as string | null,
        };
      } catch (err) {
        console.error("[authPlugin] Error resolving user from device UUID:", err);
        return {
          currentUser: null as User | null,
          deviceUuid: deviceUuid.trim(),
          authError: err instanceof Error ? err.message : String(err),
        };
      }
    })
    .macro({
      requireAuth(enabled: boolean = true) {
        if (!enabled) return {};
        return {
          beforeHandle({ currentUser, authError, set }) {
            if (!currentUser) {
              if (authError && authError !== "missing_header") {
                set.status = 500;
                return {
                  success: false,
                  error: `Database connection error: ${authError}`,
                };
              }
              set.status = 401;
              return {
                success: false,
                error: "Authentication required: missing or invalid x-device-uuid header",
              };
            }
          },
        };
      },
    });
};
