import "dotenv/config";
import { nudgeService } from "../services/nudge.service";

/**
 * Runs one Action Nudge dispatch pass locally.
 *
 *   bun run nudge:dispatch
 *
 * Hosted deployments should call POST /nudges/dispatch from their scheduler
 * instead, so the same rules run without shelling into the server.
 */
const result = await nudgeService.dispatchDailyNudges();

console.log(`Action Nudge dispatch at ${result.dispatchedAt}`);
console.log(`checked ${result.checked} user(s)`);

for (const sent of result.sent) {
  console.log(`  ✅ user ${sent.userId} → task ${sent.taskId} (${sent.reason})`);
}
for (const skipped of result.skipped) {
  console.log(`  ⏭️  user ${skipped.userId} skipped: ${skipped.reason}`);
}
