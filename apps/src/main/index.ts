import {
  app,
  BrowserWindow,
  ipcMain,
  Tray,
  nativeImage,
  screen,
  shell,
  systemPreferences
} from "electron";
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { existsSync } from "node:fs";
import { join, resolve } from "node:path";
import {
  createInitialSnapshot,
  normalizeStrength,
  type AudioInputDevice,
  type EngineCommand,
  type EngineSnapshot
} from "@contracts";
import { loadSettings, saveSettings } from "./settings";

let mainWindow: BrowserWindow | null = null;
let popupWindow: BrowserWindow | null = null;
let nativeEngine: ChildProcessWithoutNullStreams | null = null;
let tray: Tray | null = null;
let stdoutBuffer = "";
let engineSnapshot: EngineSnapshot = createInitialSnapshot();
let appSettings = loadSettings();
let autoStartPending = true;
let popupCleanupTimer: NodeJS.Timeout | null = null;

const POPUP_MEMORY_CLEANUP_DELAY_MS = 10_000;
const MACOS_MICROPHONE_SETTINGS_URL =
  "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone";

// Performance-critical: hardware acceleration must remain enabled.
// Sandbox disabled for native engine subprocess; keep unless a tighter sandbox is configured.
app.commandLine.appendSwitch("no-sandbox");

function getNativeProjectPath(): string {
  return resolve(app.getAppPath(), "../native/swift-engine");
}

function resolveAssetPath(fileName: string): string {
  const candidates = [
    // Packaged app: assets copied via electron-builder extraResources
    join(process.resourcesPath, "assets", fileName),
    resolve(app.getAppPath(), "src/assets", fileName),
    resolve(app.getAppPath(), "../src/assets", fileName),
    resolve(process.cwd(), "apps/src/assets", fileName)
  ];

  return candidates.find((candidate) => existsSync(candidate)) ?? candidates[0];
}

function createWindowIconPath(): string {
  return resolveAssetPath("icon_tray_sound.png");
}

function createTrayImage() {
  const trayIconPath = resolveAssetPath("icon_tray_sound_menu.png");
  const fallbackPath = createWindowIconPath();
  const image = nativeImage.createFromPath(
    existsSync(trayIconPath) ? trayIconPath : fallbackPath
  );

  if (image.isEmpty()) {
    return image;
  }

  const resized = image.resize({ height: 18 });
  resized.setTemplateImage(process.platform === "darwin");
  return resized;
}

function ensureWindow(): void {
  if (appSettings.trayOnlyMode) {
    return;
  }

  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.show();
    mainWindow.focus();
    return;
  }

  createWindow();
}

function ensurePopupWindow(): BrowserWindow {
  if (popupWindow && !popupWindow.isDestroyed()) {
    if (popupCleanupTimer) {
      clearTimeout(popupCleanupTimer);
      popupCleanupTimer = null;
    }
    return popupWindow;
  }

  popupWindow = new BrowserWindow({
    width: 360,
    height: 260,
    frame: false,
    resizable: false,
    show: false,
    maximizable: false,
    minimizable: false,
    fullscreenable: false,
    movable: false,
    skipTaskbar: true,
    alwaysOnTop: true,
    title: "ClearTone Quick Controls",
    backgroundColor: "#00000000",
    transparent: true,
    icon: existsSync(createWindowIconPath()) ? createWindowIconPath() : undefined,
    webPreferences: {
      preload: join(__dirname, "../preload/index.js")
    }
  });

  popupWindow.on("blur", hidePopupWindow);

  popupWindow.on("closed", () => {
    popupWindow = null;
    if (popupCleanupTimer) {
      clearTimeout(popupCleanupTimer);
      popupCleanupTimer = null;
    }
  });

  if (process.env.ELECTRON_RENDERER_URL) {
    void popupWindow.loadURL(new URL("tray.html", process.env.ELECTRON_RENDERER_URL).toString());
  } else {
    void popupWindow.loadFile(join(__dirname, "../renderer/tray.html"));
  }

  return popupWindow;
}

function hidePopupWindow(): void {
  if (!popupWindow || popupWindow.isDestroyed()) {
    return;
  }

  popupWindow.hide();
  if (popupCleanupTimer) {
    clearTimeout(popupCleanupTimer);
  }

  // The tray renderer is recreated on demand. Releasing it after it has been
  // hidden for a while prevents an unused Chromium renderer from staying in RAM.
  popupCleanupTimer = setTimeout(() => {
    popupCleanupTimer = null;
    if (popupWindow && !popupWindow.isDestroyed() && !popupWindow.isVisible()) {
      popupWindow.destroy();
    }
  }, POPUP_MEMORY_CLEANUP_DELAY_MS);
  popupCleanupTimer.unref();
}

function positionPopupWindow(): void {
  const popup = ensurePopupWindow();
  const trayBounds = tray?.getBounds();

  if (!trayBounds) {
    popup.center();
    return;
  }

  const display = screen.getDisplayNearestPoint({
    x: Math.round(trayBounds.x),
    y: Math.round(trayBounds.y)
  });
  const bounds = display.workArea;
  const x = Math.round(
    Math.min(
      Math.max(bounds.x + 8, trayBounds.x + trayBounds.width / 2 - popup.getBounds().width / 2),
      bounds.x + bounds.width - popup.getBounds().width - 8
    )
  );
  const y = Math.round(
    Math.max(bounds.y + 8, trayBounds.y + trayBounds.height + 8)
  );

  popup.setPosition(x, y, false);
}

function togglePopupWindow(): void {
  const popup = ensurePopupWindow();

  if (popup.isVisible()) {
    hidePopupWindow();
    return;
  }

  positionPopupWindow();
  popup.show();
  popup.focus();
  pushSettings();
}

function refreshTray(): void {
  if (!tray) {
    return;
  }

  const canStop =
    engineSnapshot.phase === "starting" || engineSnapshot.phase === "processing";

  tray.setToolTip(`ClearTone · ${canStop ? "On" : "Off"}`);
}

function createTray(): void {
  if (tray) {
    refreshTray();
    return;
  }

  const trayImage = createTrayImage();
  if (trayImage.isEmpty()) {
    console.error("[cleartone:tray] tray icon missing; skipping tray creation");
    return;
  }

  tray = new Tray(trayImage);
  tray.on("click", () => {
    togglePopupWindow();
  });
  tray.on("right-click", () => {
    togglePopupWindow();
  });
  refreshTray();
}

function pushSnapshot(snapshot: EngineSnapshot): void {
  engineSnapshot = snapshot;
  if (mainWindow && !mainWindow.isDestroyed() && mainWindow.isVisible()) {
    mainWindow.webContents.send("engine:snapshot", engineSnapshot);
  }
  if (popupWindow && !popupWindow.isDestroyed() && popupWindow.isVisible()) {
    popupWindow.webContents.send("engine:snapshot", engineSnapshot);
  }
  refreshTray();
}

function sendCommand(command: EngineCommand): void {
  if (!nativeEngine?.stdin.writable) {
    pushSnapshot({
      ...engineSnapshot,
      phase: "error",
      lastError: "Native engine is not connected.",
      statusMessage: "Bridge offline"
    });
    return;
  }

  nativeEngine.stdin.write(`${JSON.stringify(command)}\n`);
}

function handleEngineLine(line: string): void {
  if (!line.trim()) {
    return;
  }

  try {
    const payload = JSON.parse(line) as { type: string; snapshot?: EngineSnapshot };

    if (payload.type === "snapshot" && payload.snapshot) {
      pushSnapshot(payload.snapshot);

      if (autoStartPending && payload.snapshot.phase === "idle") {
        autoStartPending = false;
        sendCommand({ type: "startProcessing" });
      }
    }
  } catch (error) {
    pushSnapshot({
      ...engineSnapshot,
      phase: "error",
      lastError:
        error instanceof Error ? error.message : "Native engine emitted invalid JSON.",
      statusMessage: "Bridge parse failure"
    });
  }
}

function bootNativeEngine(): void {
  if (app.isPackaged) {
    const nativeEnginePath = join(process.resourcesPath, "native", "ClearToneEngine");
    if (!existsSync(nativeEnginePath)) {
      pushSnapshot({
        ...engineSnapshot,
        phase: "error",
        lastError: `Native engine binary not found at ${nativeEnginePath}.`,
        statusMessage: "Bridge missing"
      });
      return;
    }

    nativeEngine = spawn(nativeEnginePath, [], { stdio: ["pipe", "pipe", "pipe"] });
  } else {
    nativeEngine = spawn("xcrun", ["swift", "run", "--disable-sandbox", "ClearToneEngine"], {
      cwd: getNativeProjectPath(),
      stdio: ["pipe", "pipe", "pipe"]
    });
  }

  nativeEngine.stdout.on("data", (chunk: Buffer) => {
    stdoutBuffer += chunk.toString("utf8");

    let newlineIndex = stdoutBuffer.indexOf("\n");
    while (newlineIndex >= 0) {
      const line = stdoutBuffer.slice(0, newlineIndex);
      stdoutBuffer = stdoutBuffer.slice(newlineIndex + 1);
      handleEngineLine(line);
      newlineIndex = stdoutBuffer.indexOf("\n");
    }
  });

  nativeEngine.stderr.on("data", (chunk: Buffer) => {
    const message = chunk.toString("utf8").trim();
    if (!message) {
      return;
    }
    console.warn("[cleartone:native]", message);
  });

  nativeEngine.on("exit", () => {
    nativeEngine = null;
    autoStartPending = true;
    pushSnapshot({
      ...engineSnapshot,
      phase: "error",
      lastError: "Native engine process exited.",
      statusMessage: "Bridge disconnected"
    });
  });

  sendCommand({ type: "getStatus" });
}

function createWindow(): void {
  const preloadPath = join(__dirname, "../preload/index.js");
  const windowIconPath = createWindowIconPath();
  mainWindow = new BrowserWindow({
    width: 1320,
    height: 860,
    minWidth: 1180,
    minHeight: 760,
    title: "ClearTone",
    backgroundColor: "#03030a",
    icon: existsSync(windowIconPath) ? windowIconPath : undefined,
    webPreferences: {
      preload: preloadPath
    }
  });

  mainWindow.on("closed", () => {
    mainWindow = null;
  });

  if (process.env.ELECTRON_RENDERER_URL) {
    void mainWindow.loadURL(process.env.ELECTRON_RENDERER_URL);
  } else {
    void mainWindow.loadFile(join(__dirname, "../renderer/index.html"));
  }
}

app.whenReady().then(() => {
  if (!appSettings.trayOnlyMode) {
    createWindow();
  }
  createTray();
  if (process.platform === "darwin" && existsSync(createWindowIconPath())) {
    app.dock?.setIcon(createWindowIconPath());
  }
  bootNativeEngine();
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});

app.on("before-quit", () => {
  if (popupCleanupTimer) {
    clearTimeout(popupCleanupTimer);
    popupCleanupTimer = null;
  }
  nativeEngine?.kill();
});

ipcMain.handle("engine:getStatus", async () => engineSnapshot);

ipcMain.handle("engine:listInputs", async (): Promise<AudioInputDevice[]> => {
  sendCommand({ type: "listInputs" });
  return engineSnapshot.inputs;
});

ipcMain.handle("engine:selectInput", async (_event, inputId: string) => {
  sendCommand({ type: "selectInput", inputId });
});

ipcMain.handle("engine:followSystemInput", async () => {
  sendCommand({ type: "followSystemInput" });
});

ipcMain.handle("engine:startProcessing", async () => {
  sendCommand({ type: "startProcessing" });
});

ipcMain.handle("engine:stopProcessing", async () => {
  sendCommand({ type: "stopProcessing" });
});

ipcMain.handle("engine:requestMicrophoneAccess", async () => {
  if (process.platform !== "darwin") {
    sendCommand({ type: "startProcessing" });
    return;
  }

  const status = systemPreferences.getMediaAccessStatus("microphone");
  if (status === "not-determined") {
    const granted = await systemPreferences.askForMediaAccess("microphone");
    if (granted) {
      sendCommand({ type: "startProcessing" });
      return;
    }
  } else if (status === "granted") {
    sendCommand({ type: "startProcessing" });
    return;
  }

  // This URL is a fixed application constant, never renderer/user input.
  await shell.openExternal(MACOS_MICROPHONE_SETTINGS_URL);
});

ipcMain.handle("engine:setStrength", async (_event, strength: number) => {
  sendCommand({ type: "setStrength", strength: normalizeStrength(strength) });
});

ipcMain.handle("tray:resize", async (_event, height: number) => {
  if (popupWindow && !popupWindow.isDestroyed()) {
    const [width] = popupWindow.getSize();
    popupWindow.setContentSize(width, Math.max(220, Math.round(height)));
  }
});

function pushSettings(): void {
  popupWindow?.webContents.send("app:settings", appSettings);
}

ipcMain.handle("app:showMainWindow", async () => {
  ensureWindow();
});

ipcMain.handle("app:quit", async () => {
  app.quit();
});

ipcMain.handle("app:getSettings", async () => {
  return appSettings;
});

ipcMain.handle("app:setTrayOnlyMode", async (_event, enabled: boolean) => {
  appSettings = { ...appSettings, trayOnlyMode: enabled };
  saveSettings(appSettings);

  if (enabled) {
    mainWindow?.hide();
  } else {
    ensureWindow();
  }

  pushSettings();
});
