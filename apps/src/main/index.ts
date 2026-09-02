import {
  app,
  BrowserWindow,
  ipcMain,
  Tray,
  nativeImage,
  screen,
  session,
  shell,
  systemPreferences,
  type IpcMainInvokeEvent
} from "electron";
import { execFile, spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { randomUUID } from "node:crypto";
import { promisify } from "node:util";
import {
  type AppSettings,
  createInitialSnapshot,
  normalizeStrength,
  type AudioInputDevice,
  type EngineCommand,
  type EngineAcknowledgement,
  type EngineSnapshot,
  type PerformanceMetrics
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
let engineRestartTimer: NodeJS.Timeout | null = null;
let heartbeatTimer: NodeJS.Timeout | null = null;
let engineStableTimer: NodeJS.Timeout | null = null;
let driverAvailabilityPollTimer: NodeJS.Timeout | null = null;
let isQuitting = false;
let quitCleanupStarted = false;
let quitCleanupComplete = false;
let restartAttempts = 0;
let virtualMicrophoneOperation: Promise<void> = Promise.resolve();
let cachedPerformanceMetrics: PerformanceMetrics | null = null;
let performanceMetricsRequest: Promise<PerformanceMetrics> | null = null;
let lastTrayTooltip: string | null = null;
let rendererSessionConfigured = false;

type PendingCommand = {
  resolve: () => void;
  reject: (error: Error) => void;
  timer: NodeJS.Timeout;
};

const pendingCommands = new Map<string, PendingCommand>();
const execFileAsync = promisify(execFile);

const POPUP_MEMORY_CLEANUP_DELAY_MS = 1_500;
const PERFORMANCE_METRICS_CACHE_MS = 10_000;
const COMMAND_TIMEOUT_MS = 5_000;
const ACTIVE_HEARTBEAT_INTERVAL_MS = 5_000;
const IDLE_HEARTBEAT_INTERVAL_MS = 30_000;
const MAX_ENGINE_RESTART_DELAY_MS = 30_000;
const MAX_ENGINE_BUFFER_CHARACTERS = 1_000_000;
const DRIVER_AVAILABILITY_POLL_INTERVAL_MS = 2_000;
const DRIVER_AVAILABILITY_MAX_POLLS = 90;
const VIRTUAL_MICROPHONE_INSTALLER = "ClearToneVirtualMicrophone.pkg";
const VIRTUAL_MICROPHONE_RETRY_DELAY_MS = 350;
const VIRTUAL_MICROPHONE_MAX_ATTEMPTS = 3;
const MACOS_MICROPHONE_SETTINGS_URL =
  "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone";

// ClearTone renders a small, mostly static control surface. Software compositing
// avoids keeping Chromium's hardware-accelerated GPU context resident while the
// app spends most of its lifetime hidden in the menu bar.
app.disableHardwareAcceleration();
// Both windows contain trusted local ClearTone UI. Sharing one renderer caps
// the peak process count when the main window and tray controls overlap.
app.commandLine.appendSwitch("renderer-process-limit", "1");

function configureRendererSession(): void {
  if (rendererSessionConfigured) return;
  rendererSessionConfigured = true;
  session.defaultSession.setPermissionRequestHandler((_webContents, _permission, callback) => {
    callback(false);
  });
}

async function collectPerformanceMetrics(): Promise<PerformanceMetrics> {
  const appMetrics = app.getAppMetrics();
  const gpuMetrics = appMetrics.filter((metric) => metric.type === "GPU");
  let cpuPercent = appMetrics.reduce((total, metric) => total + metric.cpu.percentCPUUsage, 0);
  let memoryKB = appMetrics.reduce((total, metric) => total + metric.memory.workingSetSize, 0);

  if (nativeEngine?.pid) {
    try {
      const { stdout } = await execFileAsync(
        "/bin/ps",
        ["-p", String(nativeEngine.pid), "-o", "%cpu=,rss="],
        { maxBuffer: 4 * 1024, timeout: 1_000 }
      );
      const [nativeCpu, nativeMemoryKB] = stdout.trim().split(/\s+/).map(Number);
      if (Number.isFinite(nativeCpu)) cpuPercent += nativeCpu;
      if (Number.isFinite(nativeMemoryKB)) memoryKB += nativeMemoryKB;
    } catch {
      // The native process may exit between sampling and ps; Electron metrics remain valid.
    }
  }

  return {
    cpuPercent,
    memoryMB: memoryKB / 1024,
    gpuPercent: gpuMetrics.reduce(
      (total, metric) => total + metric.cpu.percentCPUUsage,
      0
    ),
    gpuMemoryMB:
      gpuMetrics.reduce((total, metric) => total + metric.memory.workingSetSize, 0) / 1024,
    gpuAvailable: gpuMetrics.length > 0,
    processCount: appMetrics.length + (nativeEngine?.pid ? 1 : 0),
    sampledAt: Date.now()
  };
}

function getPerformanceMetrics(): Promise<PerformanceMetrics> {
  if (
    cachedPerformanceMetrics &&
    Date.now() - cachedPerformanceMetrics.sampledAt < PERFORMANCE_METRICS_CACHE_MS
  ) {
    return Promise.resolve(cachedPerformanceMetrics);
  }

  if (performanceMetricsRequest) return performanceMetricsRequest;

  performanceMetricsRequest = collectPerformanceMetrics()
    .then((metrics) => {
      cachedPerformanceMetrics = metrics;
      return metrics;
    })
    .finally(() => {
      performanceMetricsRequest = null;
    });
  return performanceMetricsRequest;
}

const hasSingleInstanceLock = app.requestSingleInstanceLock();
if (!hasSingleInstanceLock) {
  app.quit();
}

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

function resolveDriverInstallerPath(): string {
  const candidates = [
    join(process.resourcesPath, "driver", VIRTUAL_MICROPHONE_INSTALLER),
    resolve(app.getAppPath(), "resources/driver", VIRTUAL_MICROPHONE_INSTALLER),
    resolve(app.getAppPath(), "../resources/driver", VIRTUAL_MICROPHONE_INSTALLER),
    resolve(process.cwd(), "apps/resources/driver", VIRTUAL_MICROPHONE_INSTALLER)
  ];

  return candidates.find((candidate) => existsSync(candidate)) ?? candidates[0];
}

function stopDriverAvailabilityPolling(): void {
  if (!driverAvailabilityPollTimer) return;
  clearInterval(driverAvailabilityPollTimer);
  driverAvailabilityPollTimer = null;
}

function startDriverAvailabilityPolling(): void {
  stopDriverAvailabilityPolling();
  let pollCount = 0;
  driverAvailabilityPollTimer = setInterval(() => {
    pollCount += 1;
    if (engineSnapshot.virtualMicrophone.available || pollCount >= DRIVER_AVAILABILITY_MAX_POLLS) {
      stopDriverAvailabilityPolling();
      return;
    }
    if (nativeEngine?.stdin.writable) {
      void sendCommand({ type: "listInputs" }).catch(() => undefined);
    }
  }, DRIVER_AVAILABILITY_POLL_INTERVAL_MS);
  driverAvailabilityPollTimer.unref();
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

function isTrustedRendererUrl(url: string): boolean {
  if (url.startsWith("file://")) {
    return true;
  }

  const developmentUrl = process.env.ELECTRON_RENDERER_URL;
  if (!developmentUrl) {
    return false;
  }

  try {
    return new URL(url).origin === new URL(developmentUrl).origin;
  } catch {
    return false;
  }
}

function secureWindow(window: BrowserWindow): void {
  window.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
  window.webContents.on("will-navigate", (event, url) => {
    if (!isTrustedRendererUrl(url)) {
      event.preventDefault();
    }
  });
  window.webContents.on("will-attach-webview", (event) => event.preventDefault());
}

function assertTrustedIpc(event: IpcMainInvokeEvent): void {
  const url = event.senderFrame?.url ?? event.sender.getURL();
  if (!isTrustedRendererUrl(url)) {
    throw new Error("Rejected IPC request from an untrusted renderer.");
  }
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

  configureRendererSession();
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
      preload: join(__dirname, "../preload/index.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: false,
      backgroundThrottling: true
    }
  });
  secureWindow(popupWindow);

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

  const tooltip = `ClearTone · ${canStop ? "On" : "Off"}`;
  if (tooltip === lastTrayTooltip) return;
  tray.setToolTip(tooltip);
  lastTrayTooltip = tooltip;
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
  const wasActive =
    engineSnapshot.phase === "starting" || engineSnapshot.phase === "processing";
  const isActive = snapshot.phase === "starting" || snapshot.phase === "processing";
  engineSnapshot = snapshot;
  if (heartbeatTimer && wasActive !== isActive) {
    startHeartbeat();
  }
  if (
    appSettings.virtualMicrophoneEnabled &&
    (
      !snapshot.virtualMicrophone.available ||
      (snapshot.phase === "error" && !snapshot.virtualMicrophone.enabled)
    )
  ) {
    appSettings = { ...appSettings, virtualMicrophoneEnabled: false };
    saveSettings(appSettings);
    pushSettings();
  }
  if (mainWindow && !mainWindow.isDestroyed() && mainWindow.isVisible()) {
    mainWindow.webContents.send("engine:snapshot", engineSnapshot);
  }
  if (popupWindow && !popupWindow.isDestroyed() && popupWindow.isVisible()) {
    popupWindow.webContents.send("engine:snapshot", engineSnapshot);
  }
  refreshTray();
}

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolveDelay) => {
    const timer = setTimeout(resolveDelay, milliseconds);
    timer.unref();
  });
}

function isVirtualMicrophoneUnavailableError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  return (
    message.includes("Virtual Microphone driver is not installed") ||
    message.includes("Install ClearTone Virtual Microphone")
  );
}

function persistVirtualMicrophoneSetting(enabled: boolean): void {
  if (appSettings.virtualMicrophoneEnabled === enabled) return;
  appSettings = { ...appSettings, virtualMicrophoneEnabled: enabled };
  saveSettings(appSettings);
  pushSettings();
}

async function setVirtualMicrophoneSafely(enabled: boolean): Promise<void> {
  if (!enabled) {
    await sendCommand({ type: "setVirtualMicrophone", enabled: false });
    persistVirtualMicrophoneSetting(false);
    return;
  }

  for (let attempt = 0; attempt < VIRTUAL_MICROPHONE_MAX_ATTEMPTS; attempt += 1) {
    await sendCommand({ type: "listInputs" });
    if (!engineSnapshot.virtualMicrophone.available) {
      persistVirtualMicrophoneSetting(false);
      return;
    }

    try {
      await sendCommand({ type: "setVirtualMicrophone", enabled: true });
      persistVirtualMicrophoneSetting(true);
      return;
    } catch (error) {
      if (!isVirtualMicrophoneUnavailableError(error)) throw error;
      persistVirtualMicrophoneSetting(false);
      if (attempt + 1 < VIRTUAL_MICROPHONE_MAX_ATTEMPTS) {
        await delay(VIRTUAL_MICROPHONE_RETRY_DELAY_MS);
      }
    }
  }

  await sendCommand({ type: "listInputs" }).catch(() => undefined);
}

function rejectPendingCommands(message: string): void {
  for (const pending of pendingCommands.values()) {
    clearTimeout(pending.timer);
    pending.reject(new Error(message));
  }
  pendingCommands.clear();
}

function sendCommand(command: EngineCommand): Promise<void> {
  if (!nativeEngine?.stdin.writable) {
    pushSnapshot({
      ...engineSnapshot,
      phase: "error",
      lastError: "Native engine is not connected.",
      statusMessage: "Bridge offline"
    });
    return Promise.reject(new Error("Native engine is not connected."));
  }

  const requestId = randomUUID();
  return new Promise<void>((resolveCommand, rejectCommand) => {
    const timer = setTimeout(() => {
      pendingCommands.delete(requestId);
      rejectCommand(new Error(`Native engine did not acknowledge ${command.type}.`));
    }, COMMAND_TIMEOUT_MS);
    timer.unref();
    pendingCommands.set(requestId, {
      resolve: resolveCommand,
      reject: rejectCommand,
      timer
    });
    nativeEngine?.stdin.write(`${JSON.stringify({ ...command, requestId })}\n`, (error) => {
      if (!error) return;
      const pending = pendingCommands.get(requestId);
      if (!pending) return;
      clearTimeout(pending.timer);
      pendingCommands.delete(requestId);
      pending.reject(error);
    });
  });
}

async function applyStartupSettings(): Promise<void> {
  try {
    await sendCommand({ type: "setStrength", strength: appSettings.strength });
    await sendCommand({ type: "setVoicePreset", voicePreset: appSettings.voicePreset });
    if (
      !appSettings.followSystemInput &&
      appSettings.selectedInputId &&
      engineSnapshot.inputs.some((input) => input.id === appSettings.selectedInputId)
    ) {
      await sendCommand({ type: "selectInput", inputId: appSettings.selectedInputId });
    } else {
      await sendCommand({ type: "followSystemInput" });
    }

    if (appSettings.virtualMicrophoneEnabled && engineSnapshot.virtualMicrophone.available) {
      await setVirtualMicrophoneSafely(true);
      if (!engineSnapshot.virtualMicrophone.enabled) {
        await sendCommand({ type: "startProcessing" });
      }
    } else {
      if (appSettings.virtualMicrophoneEnabled) {
        appSettings = { ...appSettings, virtualMicrophoneEnabled: false };
        saveSettings(appSettings);
        pushSettings();
      }
      await sendCommand({ type: "startProcessing" });
    }
  } catch (error) {
    if (appSettings.virtualMicrophoneEnabled) {
      appSettings = { ...appSettings, virtualMicrophoneEnabled: false };
      saveSettings(appSettings);
      pushSettings();
    }
    pushSnapshot({
      ...engineSnapshot,
      phase: "error",
      lastError: error instanceof Error ? error.message : "ClearTone could not start.",
      statusMessage: "Startup failed"
    });
  }
}

function handleEngineLine(line: string): void {
  if (!line.trim()) {
    return;
  }

  try {
    const payload = JSON.parse(line) as
      | { type: "snapshot"; snapshot: EngineSnapshot }
      | EngineAcknowledgement;

    if (payload.type === "ack") {
      const pending = pendingCommands.get(payload.requestId);
      if (!pending) return;
      clearTimeout(pending.timer);
      pendingCommands.delete(payload.requestId);
      if (payload.ok) {
        pending.resolve();
      } else {
        pending.reject(new Error(payload.error ?? "Native engine rejected the command."));
      }
      return;
    }

    if (payload.type === "snapshot" && payload.snapshot) {
      pushSnapshot(payload.snapshot);
      if (autoStartPending && payload.snapshot.phase === "idle") {
        autoStartPending = false;
        void applyStartupSettings();
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
  if (nativeEngine || isQuitting) {
    return;
  }

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
    if (stdoutBuffer.length > MAX_ENGINE_BUFFER_CHARACTERS) {
      stdoutBuffer = "";
      pushSnapshot({
        ...engineSnapshot,
        phase: "error",
        lastError: "Native engine exceeded the bridge message limit.",
        statusMessage: "Bridge protocol failure"
      });
      nativeEngine?.kill();
      return;
    }

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

  nativeEngine.on("error", (error) => {
    console.error("[cleartone:native] failed to launch:", error);
  });

  nativeEngine.on("exit", (_code, signal) => {
    if (engineStableTimer) {
      clearTimeout(engineStableTimer);
      engineStableTimer = null;
    }
    nativeEngine = null;
    stdoutBuffer = "";
    autoStartPending = true;
    rejectPendingCommands("Native engine disconnected.");
    pushSnapshot({
      ...engineSnapshot,
      phase: "error",
      lastError: signal
        ? `Native engine stopped after receiving ${signal}.`
        : "Native engine process exited.",
      statusMessage: "Bridge disconnected"
    });
    scheduleEngineRestart();
  });

  void sendCommand({ type: "getStatus" }).catch(() => {
    nativeEngine?.kill();
  });
  engineStableTimer = setTimeout(() => {
    engineStableTimer = null;
    restartAttempts = 0;
  }, 30_000);
  engineStableTimer.unref();
  startHeartbeat();
}

function scheduleEngineRestart(): void {
  if (isQuitting || engineRestartTimer) return;
  const delay = Math.min(1_000 * 2 ** restartAttempts, MAX_ENGINE_RESTART_DELAY_MS);
  restartAttempts += 1;
  engineRestartTimer = setTimeout(() => {
    engineRestartTimer = null;
    bootNativeEngine();
  }, delay);
  engineRestartTimer.unref();
}

function startHeartbeat(): void {
  if (heartbeatTimer) clearTimeout(heartbeatTimer);

  const scheduleHeartbeat = () => {
    const isActive =
      engineSnapshot.phase === "starting" || engineSnapshot.phase === "processing";
    heartbeatTimer = setTimeout(() => {
      heartbeatTimer = null;
      if (!nativeEngine || isQuitting) return;
      void sendCommand({ type: "getStatus" })
        .catch(() => {
          nativeEngine?.kill();
        })
        .finally(() => {
          if (!isQuitting) scheduleHeartbeat();
        });
    }, isActive ? ACTIVE_HEARTBEAT_INTERVAL_MS : IDLE_HEARTBEAT_INTERVAL_MS);
    heartbeatTimer.unref();
  };

  scheduleHeartbeat();
}

function createWindow(): void {
  configureRendererSession();
  const preloadPath = join(__dirname, "../preload/index.js");
  const windowIconPath = createWindowIconPath();
  mainWindow = new BrowserWindow({
    width: 1120,
    height: 780,
    minWidth: 760,
    minHeight: 620,
    title: "ClearTone",
    backgroundColor: "#03030a",
    icon: existsSync(windowIconPath) ? windowIconPath : undefined,
    webPreferences: {
      preload: preloadPath,
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: false,
      backgroundThrottling: true
    }
  });
  secureWindow(mainWindow);

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
  if (!hasSingleInstanceLock) return;
  if (!appSettings.trayOnlyMode) {
    createWindow();
  }
  createTray();
  if (process.platform === "darwin" && existsSync(createWindowIconPath())) {
    app.dock?.setIcon(createWindowIconPath());
  }
  bootNativeEngine();
});

app.on("second-instance", () => {
  ensureWindow();
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});

app.on("before-quit", (event) => {
  if (
    !quitCleanupComplete &&
    !quitCleanupStarted &&
    nativeEngine &&
    engineSnapshot.virtualMicrophone.enabled
  ) {
    event.preventDefault();
    quitCleanupStarted = true;
    isQuitting = true;
    void sendCommand({ type: "setVirtualMicrophone", enabled: false })
      .catch((error) => console.warn("[cleartone:native] could not restore system input:", error))
      .finally(() => {
        quitCleanupComplete = true;
        app.quit();
      });
    return;
  }

  isQuitting = true;
  if (popupCleanupTimer) {
    clearTimeout(popupCleanupTimer);
    popupCleanupTimer = null;
  }
  if (engineRestartTimer) {
    clearTimeout(engineRestartTimer);
    engineRestartTimer = null;
  }
  if (heartbeatTimer) {
    clearTimeout(heartbeatTimer);
    heartbeatTimer = null;
  }
  if (engineStableTimer) {
    clearTimeout(engineStableTimer);
    engineStableTimer = null;
  }
  stopDriverAvailabilityPolling();
  rejectPendingCommands("ClearTone is quitting.");
  nativeEngine?.kill();
});

ipcMain.handle("engine:getStatus", async (event) => {
  assertTrustedIpc(event);
  return engineSnapshot;
});

ipcMain.handle("engine:listInputs", async (event): Promise<AudioInputDevice[]> => {
  assertTrustedIpc(event);
  await sendCommand({ type: "listInputs" });
  return engineSnapshot.inputs;
});

ipcMain.handle("engine:selectInput", async (event, inputId: string) => {
  assertTrustedIpc(event);
  if (typeof inputId !== "string" || !engineSnapshot.inputs.some((input) => input.id === inputId)) {
    throw new TypeError("The selected microphone is invalid or unavailable.");
  }
  await sendCommand({ type: "selectInput", inputId });
  appSettings = {
    ...appSettings,
    selectedInputId: inputId,
    followSystemInput: false
  };
  saveSettings(appSettings);
});

ipcMain.handle("engine:followSystemInput", async (event) => {
  assertTrustedIpc(event);
  await sendCommand({ type: "followSystemInput" });
  appSettings = { ...appSettings, selectedInputId: null, followSystemInput: true };
  saveSettings(appSettings);
});

ipcMain.handle("engine:startProcessing", async (event) => {
  assertTrustedIpc(event);
  await sendCommand({ type: "startProcessing" });
});

ipcMain.handle("engine:stopProcessing", async (event) => {
  assertTrustedIpc(event);
  await sendCommand({ type: "stopProcessing" });
  if (appSettings.virtualMicrophoneEnabled) {
    await sendCommand({ type: "setVirtualMicrophone", enabled: false });
    appSettings = { ...appSettings, virtualMicrophoneEnabled: false };
    saveSettings(appSettings);
    pushSettings();
  }
});

ipcMain.handle("engine:requestMicrophoneAccess", async (event) => {
  assertTrustedIpc(event);
  if (process.platform !== "darwin") {
    await sendCommand({ type: "startProcessing" });
    return;
  }

  const status = systemPreferences.getMediaAccessStatus("microphone");
  if (status === "not-determined") {
    const granted = await systemPreferences.askForMediaAccess("microphone");
    if (granted) {
      await sendCommand({ type: "startProcessing" });
      return;
    }
  } else if (status === "granted") {
    await sendCommand({ type: "startProcessing" });
    return;
  }

  // This URL is a fixed application constant, never renderer/user input.
  await shell.openExternal(MACOS_MICROPHONE_SETTINGS_URL);
});

ipcMain.handle("engine:setStrength", async (event, strength: number) => {
  assertTrustedIpc(event);
  if (typeof strength !== "number" || !Number.isFinite(strength)) {
    throw new TypeError("Denoise strength must be a finite number.");
  }
  await sendCommand({ type: "setStrength", strength: normalizeStrength(strength) });
  appSettings = { ...appSettings, strength: normalizeStrength(strength) };
  saveSettings(appSettings);
});

ipcMain.handle("engine:setVoicePreset", async (event, voicePreset: string) => {
  assertTrustedIpc(event);
  if (voicePreset !== "natural" && voicePreset !== "clear" && voicePreset !== "broadcast") {
    throw new TypeError("Voice preset must be Natural, Clear, or Broadcast.");
  }
  await sendCommand({ type: "setVoicePreset", voicePreset });
  appSettings = { ...appSettings, voicePreset };
  saveSettings(appSettings);
  pushSettings();
});

ipcMain.handle("engine:setVirtualMicrophone", async (event, enabled: boolean) => {
  assertTrustedIpc(event);
  if (typeof enabled !== "boolean") {
    throw new TypeError("Virtual microphone state must be a boolean.");
  }
  const operation = virtualMicrophoneOperation
    .catch(() => undefined)
    .then(() => setVirtualMicrophoneSafely(enabled));
  virtualMicrophoneOperation = operation;
  await operation;
});

ipcMain.handle("engine:installVirtualMicrophoneDriver", async (event) => {
  assertTrustedIpc(event);
  if (process.platform !== "darwin") {
    throw new Error("ClearTone Virtual Microphone is available only on macOS.");
  }

  const installerPath = resolveDriverInstallerPath();
  if (!existsSync(installerPath)) {
    throw new Error("The ClearTone driver installer is missing from this app build.");
  }

  try {
    await execFileAsync(
      "/usr/bin/osascript",
      [
        "-e",
        "on run argv",
        "-e",
        'do shell script "/usr/sbin/installer -pkg " & quoted form of (item 1 of argv) & " -target /" with administrator privileges',
        "-e",
        "end run",
        installerPath
      ],
      { maxBuffer: 64 * 1024, timeout: 5 * 60 * 1_000 }
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : "";
    if (message.includes("User canceled") || message.includes("(-128)")) {
      throw new Error("Driver installation was cancelled.", { cause: error });
    }
    throw new Error("macOS could not install the ClearTone virtual microphone driver.", {
      cause: error
    });
  }

  if (nativeEngine?.stdin.writable) {
    await sendCommand({ type: "listInputs" });
  }
  startDriverAvailabilityPolling();
});

ipcMain.handle("tray:resize", async (event, height: number) => {
  assertTrustedIpc(event);
  if (typeof height !== "number" || !Number.isFinite(height)) return;
  if (popupWindow && !popupWindow.isDestroyed()) {
    const [width] = popupWindow.getSize();
    const displayHeight = screen.getDisplayNearestPoint(screen.getCursorScreenPoint()).workArea.height;
    popupWindow.setContentSize(
      width,
      Math.min(displayHeight - 24, Math.max(220, Math.round(height)))
    );
  }
});

function pushSettings(): void {
  popupWindow?.webContents.send("app:settings", appSettings);
}

ipcMain.handle("app:showMainWindow", async (event) => {
  assertTrustedIpc(event);
  ensureWindow();
});

ipcMain.handle("app:quit", async (event) => {
  assertTrustedIpc(event);
  app.quit();
});

ipcMain.handle("app:getSettings", async (event): Promise<AppSettings> => {
  assertTrustedIpc(event);
  return appSettings;
});

ipcMain.handle("app:getPerformanceMetrics", async (event): Promise<PerformanceMetrics> => {
  assertTrustedIpc(event);
  return getPerformanceMetrics();
});

ipcMain.handle("app:setTrayOnlyMode", async (event, enabled: boolean) => {
  assertTrustedIpc(event);
  if (typeof enabled !== "boolean") {
    throw new TypeError("Tray-only mode state must be a boolean.");
  }
  appSettings = { ...appSettings, trayOnlyMode: enabled };
  saveSettings(appSettings);

  if (enabled) {
    const windowToRelease = mainWindow;
    windowToRelease?.hide();
    const releaseTimer = setTimeout(() => {
      if (
        appSettings.trayOnlyMode &&
        windowToRelease &&
        !windowToRelease.isDestroyed()
      ) {
        windowToRelease.destroy();
      }
    }, 250);
    releaseTimer.unref();
  } else {
    ensureWindow();
  }

  pushSettings();
});
