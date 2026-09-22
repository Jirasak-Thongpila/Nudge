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
      const lineUserId = headers["x-line-user-id"];

      const hasDeviceUuid = typeof deviceUuid === "string" && deviceUuid.trim() !== "";
      const hasLineUserId = typeof lineUserId === "string" && lineUserId.trim() !== "";

      if (!hasDeviceUuid && !hasLineUserId) {
        return {
          currentUser: null as User | null,
          deviceUuid: null as string | null,
          lineUserId: null as string | null,
          authError: "missing_header",
        };
      }

      try {
        let user: User | null = null;
        if (hasLineUserId) {
          user = await svc.getOrCreateUserByLineUserId(
            lineUserId!.trim(),
            hasDeviceUuid ? deviceUuid!.trim() : undefined
          );
        } else if (hasDeviceUuid) {
          user = await svc.getOrCreateUser(deviceUuid!.trim());
        }

        return {
          currentUser: user as User | null,
          deviceUuid: hasDeviceUuid ? deviceUuid!.trim() : null,
          lineUserId: hasLineUserId ? lineUserId!.trim() : null,
          authError: null as string | null,
        };
      } catch (err) {
        console.error("[authPlugin] Error resolving user:", err);
        return {
          currentUser: null as User | null,
          deviceUuid: hasDeviceUuid ? deviceUuid!.trim() : null,
          lineUserId: hasLineUserId ? lineUserId!.trim() : null,
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
                error: "Authentication required: missing or invalid x-device-uuid or x-line-user-id header",
              };
            }
          },
        };
      },
    });
};
