import { app } from "electron";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

type AppSettings = {
  trayOnlyMode: boolean;
};

const defaultSettings: AppSettings = {
  trayOnlyMode: false
};

function settingsPath(): string {
  return join(app.getPath("userData"), "cleartone-settings.json");
}

export function loadSettings(): AppSettings {
  const path = settingsPath();

  if (!existsSync(path)) {
    return { ...defaultSettings };
  }

  try {
    const parsed = JSON.parse(readFileSync(path, "utf8")) as Partial<AppSettings>;
    return {
      trayOnlyMode: typeof parsed.trayOnlyMode === "boolean" ? parsed.trayOnlyMode : defaultSettings.trayOnlyMode
    };
  } catch {
    return { ...defaultSettings };
  }
}

export function saveSettings(settings: AppSettings): void {
  const path = settingsPath();

  try {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, JSON.stringify(settings, null, 2));
  } catch (error) {
    console.error("[cleartone:settings] failed to save settings:", error);
  }
}
