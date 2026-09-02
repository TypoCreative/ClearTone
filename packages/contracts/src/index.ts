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

export type VoicePreset = "natural" | "clear" | "broadcast";

export interface AudioInputDevice {
  id: string;
  name: string;
  manufacturer: string;
  isDefault: boolean;
}

export interface EngineMetrics {
  framesProcessed: number;
  inputRms: number;
  outputRms: number;
  noiseReductionPercent: number;
  estimatedLatencyMs: number;
  droppedFrames: number;
  outputQueueFrames: number;
}

export interface PerformanceMetrics {
  cpuPercent: number;
  memoryMB: number;
  gpuPercent: number;
  gpuMemoryMB: number;
  gpuAvailable: boolean;
  processCount: number;
  sampledAt: number;
}

export interface VirtualMicrophoneState {
  enabled: boolean;
  available: boolean;
  deviceId: string | null;
  deviceName: string;
  statusMessage: string;
}

export interface AppSettings {
  trayOnlyMode: boolean;
  virtualMicrophoneEnabled: boolean;
  strength: number;
  voicePreset: VoicePreset;
  selectedInputId: string | null;
  followSystemInput: boolean;
}

export interface EngineSnapshot {
  phase: EnginePhase;
  permission: PermissionState;
  selectedInputId: string | null;
  systemInputId: string | null;
  followSystemInput: boolean;
  inputs: AudioInputDevice[];
  strength: number;
  voicePreset: VoicePreset;
  statusMessage: string;
  lastError: string | null;
  metrics: EngineMetrics;
  virtualMicrophone: VirtualMicrophoneState;
}

export type EngineCommand =
  | { type: "getStatus"; requestId?: string }
  | { type: "listInputs"; requestId?: string }
  | { type: "selectInput"; inputId: string; requestId?: string }
  | { type: "followSystemInput"; requestId?: string }
  | { type: "startProcessing"; requestId?: string }
  | { type: "stopProcessing"; requestId?: string }
  | { type: "setStrength"; strength: number; requestId?: string }
  | { type: "setVoicePreset"; voicePreset: VoicePreset; requestId?: string }
  | { type: "setVirtualMicrophone"; enabled: boolean; requestId?: string };

export interface EngineAcknowledgement {
  type: "ack";
  requestId: string;
  ok: boolean;
  error?: string;
}

export function createInitialSnapshot(): EngineSnapshot {
  return {
    phase: "booting",
    permission: "unknown",
    selectedInputId: null,
    systemInputId: null,
    followSystemInput: true,
    inputs: [],
    strength: 0.65,
    voicePreset: "clear",
    statusMessage: "Starting native engine",
    lastError: null,
    metrics: {
      framesProcessed: 0,
      inputRms: 0,
      outputRms: 0,
      noiseReductionPercent: 0,
      estimatedLatencyMs: 0,
      droppedFrames: 0,
      outputQueueFrames: 0
    },
    virtualMicrophone: {
      enabled: false,
      available: false,
      deviceId: null,
      deviceName: "ClearTone Virtual Microphone",
      statusMessage: "Virtual microphone is off"
    }
  };
}

export function normalizeStrength(strength: number): number {
  if (!Number.isFinite(strength)) {
    return 0.65;
  }
  return Math.max(0, Math.min(1, strength));
}
