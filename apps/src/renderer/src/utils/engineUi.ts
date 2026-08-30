import type { AudioInputDevice, EnginePhase, EngineSnapshot } from "@contracts";

export const phaseLabels: Record<EnginePhase, string> = {
  booting: "Booting",
  idle: "Ready",
  starting: "Starting",
  processing: "Live",
  stopping: "Stopping",
  error: "Needs Attention"
};

const percentFormatter = new Intl.NumberFormat(undefined, {
  maximumFractionDigits: 0,
  style: "percent"
});

const latencyFormatter = new Intl.NumberFormat(undefined, {
  maximumFractionDigits: 1,
  minimumFractionDigits: 1
});

export const integerFormatter = new Intl.NumberFormat(undefined, {
  maximumFractionDigits: 0
});

export function formatPercent(value: number): string {
  return percentFormatter.format(value);
}

export function formatRms(value: number): string {
  return percentFormatter.format(value);
}

export function formatLatency(value: number): string {
  return `${latencyFormatter.format(value)} ms`;
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
