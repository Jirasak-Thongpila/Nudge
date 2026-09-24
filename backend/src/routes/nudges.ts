import { Elysia } from "elysia";
import { authPlugin, type AuthPluginOptions } from "../plugins/auth";
import { NudgeService, nudgeService as defaultNudgeService } from "../services/nudge.service";

export interface NudgeRouteOptions extends AuthPluginOptions {
  nudgeService?: NudgeService;
  /** Shared secret the external scheduler must send (defaults to NUDGE_DISPATCH_KEY). */
  dispatchKey?: string;
}

export const nudgeRoutes = (options?: NudgeRouteOptions) => {
  const nSvc = options?.nudgeService ?? defaultNudgeService;

  return new Elysia({ prefix: "/nudges" })
    .use(authPlugin(options))
    /**
     * Called by the scheduler (cron / hosting cron job). Nudge is delivered to every
     * user who currently deserves one — see lib/nudge.ts for the rules.
     *
     * The endpoint is deliberately not authenticated by user headers: it acts on
     * behalf of the whole system, so it requires a shared secret instead.
     */
    .post("/dispatch", async ({ headers, set }) => {
      const dispatchKey = options?.dispatchKey ?? process.env.NUDGE_DISPATCH_KEY ?? "";

      if (!dispatchKey) {
        set.status = 503;
        return {
          success: false,
          error: "NUDGE_DISPATCH_KEY is not configured on the server",
        };
      }

      if (headers["x-nudge-dispatch-key"] !== dispatchKey) {
        set.status = 401;
        return {
          success: false,
          error: "Invalid or missing x-nudge-dispatch-key",
        };
      }

      try {
        const result = await nSvc.dispatchDailyNudges();
        return {
          success: true,
          data: result,
        };
      } catch (error: any) {
        set.status = 500;
        return {
          success: false,
          error: error?.message || "Failed to dispatch nudges",
        };
      }
    })
    /**
     * Shows what the next nudge would be, without sending anything.
     * Handy for the app's debug panel and for demos.
     */
    .get(
      "/preview",
      async ({ currentUser, set }) => {
        try {
          const preview = await nSvc.previewNudge(currentUser!.id);
          return {
            success: true,
            data: preview,
          };
        } catch (error: any) {
          set.status = 400;
          return {
            success: false,
            error: error?.message || "Failed to preview nudge",
          };
        }
      },
      {
        requireAuth: true,
      }
    );
};
