import type { AudioInputDevice, EnginePhase, EngineSnapshot } from "@contracts";

export const phaseLabels: Record<EnginePhase, string> = {
  booting: "Booting",
  idle: "Ready",
  starting: "Starting",
  processing: "Live",
  stopping: "Stopping",
  error: "Needs Attention"
};

export function formatPercent(value: number): string {
  return `${Math.round(value * 100)}%`;
}

export function formatRms(value: number): string {
  return `${Math.round(value * 100)}%`;
}

export function formatLatency(value: number): string {
  return `${value.toFixed(1)} ms`;
}

export function formatDeviceMode(snapshot: EngineSnapshot, selectedInput?: AudioInputDevice): string {
  if (snapshot.followSystemInput) {
    return selectedInput ? `Following ${selectedInput.name}` : "Following system input";
  }

  return selectedInput ? `Locked to ${selectedInput.name}` : "Manual device mode";
}

export function getSelectedInput(snapshot: EngineSnapshot): AudioInputDevice | undefined {
  return snapshot.inputs.find((input) => input.id === snapshot.selectedInputId);
}

export function deriveControlState(snapshot: EngineSnapshot): {
  canStart: boolean;
  canStop: boolean;
  inputControlValue: string;
} {
  const canStart =
    snapshot.phase !== "starting" &&
    snapshot.phase !== "processing" &&
    snapshot.phase !== "stopping" &&
    snapshot.inputs.length > 0 &&
    snapshot.permission !== "denied" &&
    snapshot.permission !== "restricted";

  const canStop = snapshot.phase === "starting" || snapshot.phase === "processing";
  const inputControlValue = snapshot.followSystemInput
    ? "__follow_system__"
    : (snapshot.selectedInputId ?? "");

  return { canStart, canStop, inputControlValue };
}
