import type { AppSettings, AudioInputDevice, EngineSnapshot } from "@contracts";

interface ClearToneApi {
  getStatus(): Promise<EngineSnapshot>;
  listInputs(): Promise<AudioInputDevice[]>;
  selectInput(inputId: string): Promise<void>;
  followSystemInput(): Promise<void>;
  startProcessing(): Promise<void>;
  stopProcessing(): Promise<void>;
  requestMicrophoneAccess(): Promise<void>;
  setStrength(strength: number): Promise<void>;
  setVirtualMicrophone(enabled: boolean): Promise<void>;
  installVirtualMicrophoneDriver(): Promise<void>;
  onSnapshot(listener: (snapshot: EngineSnapshot) => void): () => void;
  resizeTray(height: number): Promise<void>;
  showMainWindow(): Promise<void>;
  quitApp(): Promise<void>;
  getSettings(): Promise<AppSettings>;
  setTrayOnlyMode(enabled: boolean): Promise<void>;
  onSettings(listener: (settings: AppSettings) => void): () => void;
}

declare global {
  interface Window {
    clearTone: ClearToneApi;
  }
}

export {};
