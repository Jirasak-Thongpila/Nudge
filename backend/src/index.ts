import "dotenv/config";
import { createApp } from "./app";

const port = Number(process.env.PORT) || 3000;
const app = createApp();

app.listen(port, () => {
  console.log(`🚀 Nudge backend running at http://localhost:${port}`);
});

export type App = typeof app;
