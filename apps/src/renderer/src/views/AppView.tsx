import { memo, useMemo } from "react";
import type { AudioInputDevice, EnginePhase, EngineSnapshot } from "@contracts";
import { AppDeviceSelect } from "../components/AppDeviceSelect";
import { MetricsGrid } from "../components/MetricsGrid";
import { StartStopControls } from "../components/StartStopControls";
import { StrengthSlider } from "../components/StrengthSlider";
import { ThemeToggle } from "../components/ThemeToggle";
import { Card, CardDescription, CardTitle } from "../components/ui/card";
import { cn } from "../lib/utils";
import { deriveControlState, phaseLabels } from "../utils/engineUi";

type Props = {
  snapshot: EngineSnapshot;
  loading: boolean;
  selectedInput: AudioInputDevice | undefined;
};

const StatusBadge = memo(function StatusBadge({
  phase,
  loading,
}: {
  phase: EnginePhase;
  loading: boolean;
}) {
  const isProcessing = phase === "processing";
  const isError = phase === "error";
  const label = loading ? "Connecting" : phaseLabels[phase];

  return (
    <div
      className={cn(
        "inline-flex items-center gap-2 rounded-full border px-3 py-1 text-xs font-semibold uppercase tracking-widest backdrop-blur-md",
        isProcessing
          ? "border-emerald-400/30 bg-emerald-400/15 text-emerald-100 shadow-[0_0_16px_rgba(52,211,153,0.25)]"
          : isError
            ? "border-red-400/30 bg-red-400/15 text-red-100"
            : "border-white/10 bg-white/8 text-slate-200"
      )}
    >
      <span
        className={cn(
          "h-2 w-2 rounded-full",
          isProcessing && "animate-pulse bg-emerald-300",
          isError ? "bg-red-300" : !isProcessing && "bg-slate-300"
        )}
      />
      {label}
    </div>
  );
});

export const AppView = memo(function AppView({ snapshot, loading, selectedInput }: Props) {
  const controls = useMemo(() => deriveControlState(snapshot), [snapshot]);
  const { canStart, canStop, inputControlValue } = controls;

  return (
    <main className="relative flex min-h-full flex-col items-center justify-center p-6 text-foreground md:p-10">
      <div className="relative w-full max-w-6xl space-y-6">
        <section className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div className="space-y-1">
            <div className="text-[10px] font-bold uppercase tracking-[0.25em] text-primary">ClearTone</div>
            <h1 className="text-3xl font-bold tracking-tight md:text-4xl">Audio Command Center</h1>
            <p className="text-sm text-muted-foreground">{snapshot.statusMessage}</p>
          </div>
          <div className="flex items-center gap-3">
            <StatusBadge phase={snapshot.phase} loading={loading} />
            <ThemeToggle compact />
          </div>
        </section>

        <section className="grid grid-cols-1 gap-6 lg:grid-cols-12">
          <Card className="flex flex-col justify-between p-6 lg:col-span-7">
            <div className="mb-6 space-y-1">
              <CardTitle className="text-xl">Engine Control</CardTitle>
              <CardDescription>Start or stop the real-time denoise engine.</CardDescription>
            </div>
            <StartStopControls canStart={canStart} canStop={canStop} mode="toggle" variant="app" />
          </Card>

          <Card className="space-y-5 p-6 lg:col-span-5">
            <div className="space-y-1">
              <CardTitle className="text-xl">Control Deck</CardTitle>
              <CardDescription>Choose your mic and tune denoise intensity.</CardDescription>
            </div>
            <AppDeviceSelect
              snapshot={snapshot}
              selectedInput={selectedInput}
              value={inputControlValue}
              disabled={snapshot.inputs.length === 0}
            />
            <StrengthSlider snapshot={snapshot} />
          </Card>
        </section>

        {snapshot.lastError ? (
          <Card className="border-destructive/30 bg-destructive/10 p-5">
            <div className="flex items-center gap-2 text-sm font-semibold text-destructive">
              <span className="h-2 w-2 rounded-full bg-destructive" />
              Engine Error
            </div>
            <p className="mt-1 text-sm text-destructive/90">{snapshot.lastError}</p>
          </Card>
        ) : null}

        <section className="space-y-3">
          <div className="flex items-center gap-2">
            <span className="h-2 w-2 animate-pulse rounded-full bg-primary" />
            <span className="text-xs font-bold uppercase tracking-widest text-muted-foreground">Live Engine Metrics</span>
          </div>
          <MetricsGrid snapshot={snapshot} loading={loading} variant="app" />
        </section>
      </div>
    </main>
  );
});
