import { contextBridge, ipcRenderer } from "electron";
import type { AudioInputDevice, EngineSnapshot } from "@contracts";

const clearToneApi = {
  getStatus: (): Promise<EngineSnapshot> => ipcRenderer.invoke("engine:getStatus"),
  listInputs: (): Promise<AudioInputDevice[]> => ipcRenderer.invoke("engine:listInputs"),
  selectInput: (inputId: string): Promise<void> =>
    ipcRenderer.invoke("engine:selectInput", inputId),
  followSystemInput: (): Promise<void> => ipcRenderer.invoke("engine:followSystemInput"),
  startProcessing: (): Promise<void> => ipcRenderer.invoke("engine:startProcessing"),
  stopProcessing: (): Promise<void> => ipcRenderer.invoke("engine:stopProcessing"),
  setStrength: (strength: number): Promise<void> =>
    ipcRenderer.invoke("engine:setStrength", strength),
  onSnapshot: (listener: (snapshot: EngineSnapshot) => void): (() => void) => {
    const wrapped = (_event: Electron.IpcRendererEvent, snapshot: EngineSnapshot) => {
      listener(snapshot);
    };

    ipcRenderer.on("engine:snapshot", wrapped);
    return () => {
      ipcRenderer.removeListener("engine:snapshot", wrapped);
    };
  }
};

contextBridge.exposeInMainWorld("clearTone", clearToneApi);
