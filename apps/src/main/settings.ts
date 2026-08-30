import { app } from "electron";
import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import type { AppSettings } from "@contracts";

const defaultSettings: AppSettings = {
  trayOnlyMode: false,
  virtualMicrophoneEnabled: false,
  strength: 0.65,
  selectedInputId: null,
  followSystemInput: true
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
      trayOnlyMode: typeof parsed.trayOnlyMode === "boolean" ? parsed.trayOnlyMode : defaultSettings.trayOnlyMode,
      virtualMicrophoneEnabled:
        typeof parsed.virtualMicrophoneEnabled === "boolean"
          ? parsed.virtualMicrophoneEnabled
          : defaultSettings.virtualMicrophoneEnabled,
      strength:
        typeof parsed.strength === "number" && Number.isFinite(parsed.strength)
          ? Math.max(0, Math.min(1, parsed.strength))
          : defaultSettings.strength,
      selectedInputId: typeof parsed.selectedInputId === "string" ? parsed.selectedInputId : null,
      followSystemInput:
        typeof parsed.followSystemInput === "boolean"
          ? parsed.followSystemInput
          : defaultSettings.followSystemInput
    };
  } catch {
    return { ...defaultSettings };
  }
}

export function saveSettings(settings: AppSettings): void {
  const path = settingsPath();

  try {
    mkdirSync(dirname(path), { recursive: true });
    const temporaryPath = `${path}.tmp-${process.pid}`;
    writeFileSync(temporaryPath, JSON.stringify(settings, null, 2), { mode: 0o600 });
    renameSync(temporaryPath, path);
  } catch (error) {
    console.error("[cleartone:settings] failed to save settings:", error);
  }
}
