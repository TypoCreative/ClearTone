export type EnginePhase =
  | "booting"
  | "idle"
  | "starting"
  | "processing"
  | "stopping"
  | "error";

export type PermissionState =
  | "unknown"
  | "not-determined"
  | "granted"
  | "denied"
  | "restricted";

export interface AudioInputDevice {
  id: string;
  name: string;
  manufacturer: string;
  isDefault: boolean;
}

export interface EngineMetrics {
  framesProcessed: number;
  inputLevel: number;
  estimatedLatencyMs: number;
}

export interface EngineSnapshot {
  phase: EnginePhase;
  permission: PermissionState;
  selectedInputId: string | null;
  systemInputId: string | null;
  followSystemInput: boolean;
  inputs: AudioInputDevice[];
  strength: number;
  statusMessage: string;
  lastError: string | null;
  metrics: EngineMetrics;
}

export type EngineCommand =
  | { type: "getStatus" }
  | { type: "listInputs" }
  | { type: "selectInput"; inputId: string }
  | { type: "followSystemInput" }
  | { type: "startProcessing" }
  | { type: "stopProcessing" }
  | { type: "setStrength"; strength: number };

export function createInitialSnapshot(): EngineSnapshot {
  return {
    phase: "booting",
    permission: "unknown",
    selectedInputId: null,
    systemInputId: null,
    followSystemInput: true,
    inputs: [],
    strength: 0.65,
    statusMessage: "Starting native engine",
    lastError: null,
    metrics: {
      framesProcessed: 0,
      inputLevel: 0,
      estimatedLatencyMs: 0
    }
  };
}

export function normalizeStrength(strength: number): number {
  return Math.max(0, Math.min(1, strength));
}
