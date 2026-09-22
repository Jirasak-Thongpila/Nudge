import { Elysia, t } from "elysia";
import { authPlugin, type AuthPluginOptions } from "../plugins/auth";
import { UserService, userService as defaultUserService } from "../services/user.service";
import { LineService, lineService as defaultLineService } from "../services/line.service";

export interface LineRouteOptions extends AuthPluginOptions {
  userService?: UserService;
  lineService?: LineService;
}

export const lineRoutes = (options?: LineRouteOptions) => {
  const uSvc = options?.userService ?? defaultUserService;
  const lSvc = options?.lineService ?? defaultLineService;

  return new Elysia({ prefix: "/line" })
    .use(authPlugin(options))
    .post(
      "/auth",
      async ({ body, set }) => {
        try {
          const user = await uSvc.getOrCreateUserByLineUserId(body.lineUserId.trim(), body.deviceUuid);
          return {
            success: true,
            data: user,
          };
        } catch (error: any) {
          set.status = 400;
          return {
            success: false,
            error: error?.message || "Failed to authenticate with LINE",
          };
        }
      },
      {
        body: t.Object({
          lineUserId: t.String({ minLength: 1 }),
          deviceUuid: t.Optional(t.String()),
          displayName: t.Optional(t.String()),
          pictureUrl: t.Optional(t.String()),
        }),
      }
    )
    .post(
      "/link",
      async ({ currentUser, body, set }) => {
        try {
          const updated = await uSvc.linkLineUserId(currentUser!.id, body.lineUserId.trim());
          return {
            success: true,
            data: updated,
          };
        } catch (error: any) {
          set.status = 400;
          return {
            success: false,
            error: error?.message || "Failed to link LINE account",
          };
        }
      },
      {
        requireAuth: true,
        body: t.Object({
          lineUserId: t.String({ minLength: 1 }),
        }),
      }
    )
    .post(
      "/nudge/:taskId",
      async ({ currentUser, params: { taskId }, set }) => {
        try {
          const id = Number(taskId);
          if (isNaN(id)) {
            set.status = 400;
            return {
              success: false,
              error: "Invalid task ID",
            };
          }

          const result = await lSvc.sendActionNudge(currentUser!.id, id);
          return {
            success: true,
            data: result,
          };
        } catch (error: any) {
          if (error?.message === "Task not found") {
            set.status = 404;
          } else if (error?.message === "User has not linked a LINE account") {
            set.status = 400;
          } else {
            set.status = 500;
          }
          return {
            success: false,
            error: error?.message || "Failed to send action nudge",
          };
        }
      },
      {
        requireAuth: true,
        params: t.Object({
          taskId: t.String(),
        }),
      }
    )
    .post(
      "/webhook",
      async ({ body, headers, set }) => {
        // The raw body is preserved by the local `parse` hook below so the
        // HMAC-SHA256 signature can be validated against the exact bytes LINE sent.
        const rawBody = typeof body === "string" ? body : "";
        const signature = headers["x-line-signature"];

        if (!lSvc.verifySignature(rawBody, signature)) {
          set.status = 401;
          return {
            success: false,
            error: "Invalid or missing X-Line-Signature",
          };
        }

        let payload: any = {};
        try {
          payload = rawBody ? JSON.parse(rawBody) : {};
        } catch {
          set.status = 400;
          return {
            success: false,
            error: "Invalid JSON payload",
          };
        }

        const events = payload?.events ?? [];
        const result = await lSvc.handleWebhookEvents(events);
        return {
          status: "ok",
          ...result,
        };
      },
      {
        parse({ request, contentType }) {
          if (contentType?.includes("application/json")) {
            return request.text();
          }
        },
      }
    );
};
