import {
  app,
  BrowserWindow,
  ipcMain,
  Tray,
  nativeImage,
  screen
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

let mainWindow: BrowserWindow | null = null;
let popupWindow: BrowserWindow | null = null;
let nativeEngine: ChildProcessWithoutNullStreams | null = null;
let tray: Tray | null = null;
let stdoutBuffer = "";
let engineSnapshot: EngineSnapshot = createInitialSnapshot();

app.commandLine.appendSwitch("no-sandbox");
app.commandLine.appendSwitch("disable-gpu");
app.disableHardwareAcceleration();

function getNativeProjectPath(): string {
  return resolve(app.getAppPath(), "../../native/swift-engine");
}

function resolveAssetPath(fileName: string): string {
  const candidates = [
    resolve(app.getAppPath(), "src/assets", fileName),
    resolve(app.getAppPath(), "../src/assets", fileName),
    resolve(process.cwd(), "apps/electron/src/assets", fileName)
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
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.show();
    mainWindow.focus();
    return;
  }

  createWindow();
}

function ensurePopupWindow(): BrowserWindow {
  if (popupWindow && !popupWindow.isDestroyed()) {
    return popupWindow;
  }

  popupWindow = new BrowserWindow({
    width: 360,
    height: 360,
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
    backgroundColor: "#ffffff",
    icon: existsSync(createWindowIconPath()) ? createWindowIconPath() : undefined,
    webPreferences: {
      preload: join(__dirname, "../preload/index.js")
    }
  });

  popupWindow.on("blur", () => {
    popupWindow?.hide();
  });

  popupWindow.on("closed", () => {
    popupWindow = null;
  });

  if (process.env.ELECTRON_RENDERER_URL) {
    void popupWindow.loadURL(`${process.env.ELECTRON_RENDERER_URL}#tray-popup`);
  } else {
    void popupWindow.loadFile(join(__dirname, "../renderer/index.html"), {
      hash: "tray-popup"
    });
  }

  return popupWindow;
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
    popup.hide();
    return;
  }

  positionPopupWindow();
  popup.show();
  popup.focus();
}

function refreshTray(): void {
  if (!tray) {
    return;
  }

  const canStart =
    engineSnapshot.phase !== "starting" &&
    engineSnapshot.phase !== "processing" &&
    engineSnapshot.inputs.length > 0 &&
    engineSnapshot.permission !== "denied" &&
    engineSnapshot.permission !== "restricted";
  const canStop =
    engineSnapshot.phase === "starting" || engineSnapshot.phase === "processing";

  tray.setToolTip(`ClearTone · ${canStop ? "On" : "Off"}`);
  tray.setContextMenu(null);
}

function createTray(): void {
  if (tray) {
    refreshTray();
    return;
  }

  tray = new Tray(createTrayImage());
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
  mainWindow?.webContents.send("engine:snapshot", engineSnapshot);
  popupWindow?.webContents.send("engine:snapshot", engineSnapshot);
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
  nativeEngine = spawn("xcrun", ["swift", "run", "--disable-sandbox", "ClearToneEngine"], {
    cwd: getNativeProjectPath(),
    stdio: ["pipe", "pipe", "pipe"]
  });

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
    backgroundColor: "#ffffff",
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
  createWindow();
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

ipcMain.handle("engine:setStrength", async (_event, strength: number) => {
  sendCommand({ type: "setStrength", strength: normalizeStrength(strength) });
});
