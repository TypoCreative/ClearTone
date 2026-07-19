import type { AudioInputDevice, EngineSnapshot } from "@contracts";

interface ClearToneApi {
  getStatus(): Promise<EngineSnapshot>;
  listInputs(): Promise<AudioInputDevice[]>;
  selectInput(inputId: string): Promise<void>;
  followSystemInput(): Promise<void>;
  startProcessing(): Promise<void>;
  stopProcessing(): Promise<void>;
  setStrength(strength: number): Promise<void>;
  onSnapshot(listener: (snapshot: EngineSnapshot) => void): () => void;
}

declare global {
  interface Window {
    clearTone: ClearToneApi;
  }
}

export {};
