import { contextBridge, ipcRenderer } from "electron";
import type {
  AppSettings,
  AudioInputDevice,
  EngineSnapshot,
  PerformanceMetrics,
  VoicePreset
} from "@contracts";

const clearToneApi = {
  getStatus: (): Promise<EngineSnapshot> => ipcRenderer.invoke("engine:getStatus"),
  getPerformanceMetrics: (): Promise<PerformanceMetrics> =>
    ipcRenderer.invoke("app:getPerformanceMetrics"),
  listInputs: (): Promise<AudioInputDevice[]> => ipcRenderer.invoke("engine:listInputs"),
  selectInput: (inputId: string): Promise<void> =>
    ipcRenderer.invoke("engine:selectInput", inputId),
  followSystemInput: (): Promise<void> => ipcRenderer.invoke("engine:followSystemInput"),
  startProcessing: (): Promise<void> => ipcRenderer.invoke("engine:startProcessing"),
  stopProcessing: (): Promise<void> => ipcRenderer.invoke("engine:stopProcessing"),
  requestMicrophoneAccess: (): Promise<void> =>
    ipcRenderer.invoke("engine:requestMicrophoneAccess"),
  setStrength: (strength: number): Promise<void> =>
    ipcRenderer.invoke("engine:setStrength", strength),
  setVoicePreset: (voicePreset: VoicePreset): Promise<void> =>
    ipcRenderer.invoke("engine:setVoicePreset", voicePreset),
  setVirtualMicrophone: (enabled: boolean): Promise<void> =>
    ipcRenderer.invoke("engine:setVirtualMicrophone", enabled),
  installVirtualMicrophoneDriver: (): Promise<void> =>
    ipcRenderer.invoke("engine:installVirtualMicrophoneDriver"),
  onSnapshot: (listener: (snapshot: EngineSnapshot) => void): (() => void) => {
    const wrapped = (_event: Electron.IpcRendererEvent, snapshot: EngineSnapshot) => {
      listener(snapshot);
    };

    ipcRenderer.on("engine:snapshot", wrapped);
    return () => {
      ipcRenderer.removeListener("engine:snapshot", wrapped);
    };
  },
  resizeTray: (height: number): Promise<void> => ipcRenderer.invoke("tray:resize", height),
  showMainWindow: (): Promise<void> => ipcRenderer.invoke("app:showMainWindow"),
  quitApp: (): Promise<void> => ipcRenderer.invoke("app:quit"),
  getSettings: (): Promise<AppSettings> => ipcRenderer.invoke("app:getSettings"),
  setTrayOnlyMode: (enabled: boolean): Promise<void> =>
    ipcRenderer.invoke("app:setTrayOnlyMode", enabled),
  onSettings: (listener: (settings: AppSettings) => void): (() => void) => {
    const wrapped = (_event: Electron.IpcRendererEvent, settings: AppSettings) => {
      listener(settings);
    };

    ipcRenderer.on("app:settings", wrapped);
    return () => {
      ipcRenderer.removeListener("app:settings", wrapped);
    };
  }
};

contextBridge.exposeInMainWorld("clearTone", clearToneApi);
