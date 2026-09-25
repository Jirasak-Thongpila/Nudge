import { Elysia, t } from "elysia";
import { authPlugin, type AuthPluginOptions } from "../plugins/auth";
import { TaskService, taskService as defaultTaskService } from "../services/task.service";
import { FocusService, focusService as defaultFocusService } from "../services/focus.service";
import { GeminiService, geminiService as defaultGeminiService } from "../services/gemini.service";
import { LineService, lineService as defaultLineService } from "../services/line.service";

export interface TaskRouteOptions extends AuthPluginOptions {
  taskService?: TaskService;
  focusService?: FocusService;
  geminiService?: GeminiService;
  lineService?: LineService;
}

export const taskRoutes = (options?: TaskRouteOptions) => {
  const tSvc = options?.taskService ?? defaultTaskService;
  const fSvc = options?.focusService ?? defaultFocusService;
  const gSvc = options?.geminiService ?? defaultGeminiService;
  const lSvc = options?.lineService ?? new LineService(options?.userService, tSvc, gSvc);

  return new Elysia({ prefix: "/tasks" })
    .use(authPlugin(options))
    .post(
      "/quick-add",
      async ({ currentUser, body, set }) => {
        try {
          const text = body.text?.trim() || "";
          if (!text) {
            set.status = 400;
            return { success: false, error: "Text is required" };
          }

          const intentResult = await gSvc.parseTaskIntent(text);
          if (intentResult.intent !== "CREATE_TASK") {
            return {
              success: false,
              notTask: true,
              replyMessage:
                intentResult.replyMessage ||
                "ยังไม่สามารถระบุงานจากข้อความนี้ได้ กรุณาระบุชื่องานหรือวันเวลาให้ชัดเจนขึ้นครับ",
            };
          }

          const title = intentResult.title || text;
          const deadline = intentResult.deadline || new Date(Date.now() + 86400000).toISOString();
          const importance = intentResult.importance || 3;
          const estimatedMinutes = intentResult.estimatedMinutes || 30;

          // Duplicate check
          if (!body.confirmed) {
            const duplicate = await lSvc.findDuplicateTask(currentUser!.id, title);
            if (duplicate) {
              return {
                success: true,
                duplicate: true,
                existingTask: duplicate,
                parsed: {
                  title,
                  deadline,
                  importance,
                  estimatedMinutes,
                },
              };
            }
          }

          const task = await tSvc.createTask(currentUser!.id, {
            title,
            deadline,
            importance,
            estimatedMinutes,
          });

          set.status = 201;
          return {
            success: true,
            duplicate: false,
            data: task,
            parsed: {
              title,
              deadline,
              importance,
              estimatedMinutes,
            },
          };
        } catch (error: any) {
          set.status = 400;
          return {
            success: false,
            error: error?.message || "Failed to quick create task",
          };
        }
      },
      {
        requireAuth: true,
        body: t.Object({
          text: t.String({ minLength: 1 }),
          confirmed: t.Optional(t.Boolean()),
        }),
      }
    )
    .post(
      "/quick-add-audio",
      async ({ currentUser, body, set }) => {
        try {
          const audioBase64 = body.audioBase64;
          const mimeType = body.mimeType || "audio/webm";
          if (!audioBase64) {
            set.status = 400;
            return { success: false, error: "Audio data is required" };
          }

          const audioBuffer = Buffer.from(audioBase64, "base64");
          const audioResult = await gSvc.parseTaskFromAudio(audioBuffer, mimeType);

          if (audioResult.intent !== "CREATE_TASK" || !audioResult.title) {
            return {
              success: false,
              notTask: true,
              transcription: audioResult.transcription,
              replyMessage:
                audioResult.replyMessage ||
                (audioResult.transcription
                  ? `ได้ยินว่า: "${audioResult.transcription}" แต่ยังไม่สามารถระบุงานได้ชัดเจนครับ`
                  : "ฟังเสียงไม่ชัดเจน กรุณาลองใหม่อีกครั้งครับ"),
            };
          }

          const title = audioResult.title;
          const deadline = audioResult.deadline || new Date(Date.now() + 86400000).toISOString();
          const importance = audioResult.importance || 3;
          const estimatedMinutes = audioResult.estimatedMinutes || 30;

          if (!body.confirmed) {
            const duplicate = await lSvc.findDuplicateTask(currentUser!.id, title);
            if (duplicate) {
              return {
                success: true,
                duplicate: true,
                existingTask: duplicate,
                transcription: audioResult.transcription,
                parsed: {
                  title,
                  deadline,
                  importance,
                  estimatedMinutes,
                },
              };
            }
          }

          const task = await tSvc.createTask(currentUser!.id, {
            title,
            deadline,
            importance,
            estimatedMinutes,
          });

          set.status = 201;
          return {
            success: true,
            duplicate: false,
            data: task,
            transcription: audioResult.transcription,
            parsed: {
              title,
              deadline,
              importance,
              estimatedMinutes,
            },
          };
        } catch (error: any) {
          set.status = 400;
          return {
            success: false,
            error: error?.message || "Failed to process audio task",
          };
        }
      },
      {
        requireAuth: true,
        body: t.Object({
          audioBase64: t.String({ minLength: 1 }),
          mimeType: t.Optional(t.String()),
          confirmed: t.Optional(t.Boolean()),
        }),
      }
    )
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
