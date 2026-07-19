import type { AudioInputDevice, EngineSnapshot } from "@contracts";
import { MetricsGrid } from "../components/MetricsGrid";
import { StartStopControls } from "../components/StartStopControls";
import { StrengthSlider } from "../components/StrengthSlider";
import { TrayDeviceSelect } from "../components/TrayDeviceSelect";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { cn } from "../lib/utils";
import { deriveControlState, phaseLabels } from "../utils/engineUi";

type Props = {
  snapshot: EngineSnapshot;
  loading: boolean;
  selectedInput: AudioInputDevice | undefined;
};

export function TrayView({ snapshot, loading, selectedInput }: Props) {
  const { canStart, canStop, inputControlValue } = deriveControlState(snapshot);
  const statusLabel = loading ? "Connecting" : phaseLabels[snapshot.phase];
  const statusClassName = cn(
    "inline-flex items-center rounded-full border px-2 py-0.5 text-[11px] font-medium backdrop-blur-md",
    snapshot.phase === "processing"
      ? "border-primary/30 bg-primary/10 text-primary"
      : snapshot.phase === "error"
        ? "border-destructive/30 bg-destructive/10 text-destructive"
        : "border-border/60 bg-card/40 text-foreground"
  );

  return (
    <main className="rounded-[24px] bg-black p-3 text-foreground">
      <div className="flex flex-col gap-3">
        <Card className="border-white/12 bg-white/8 shadow-[0_10px_30px_rgba(0,0,0,0.35)] backdrop-blur-2xl">
          <CardHeader className="flex flex-row items-center justify-between gap-3 p-4">
            <div className="flex items-center gap-2">
              <CardTitle className="text-base">ClearTone</CardTitle>
              <span className={statusClassName}>{statusLabel}</span>
            </div>
            <StartStopControls
              canStart={canStart}
              canStop={canStop}
              mode="toggle"
              variant="trayHeader"
            />
          </CardHeader>
        </Card>

        <Card className="border-white/12 bg-white/8 shadow-[0_10px_30px_rgba(0,0,0,0.35)] backdrop-blur-2xl">
          <CardContent className="space-y-3 p-4">
            <TrayDeviceSelect
              snapshot={snapshot}
              value={inputControlValue}
              disabled={snapshot.inputs.length === 0}
            />
            <StrengthSlider snapshot={snapshot} variant="tray" />
          </CardContent>
        </Card>

        {snapshot.lastError ? (
          <Card className="border-destructive/30 bg-destructive/12 shadow-[0_10px_30px_rgba(0,0,0,0.35)] backdrop-blur-2xl">
            <CardHeader className="p-4 pb-2">
              <CardTitle className="text-sm">Engine Error</CardTitle>
            </CardHeader>
            <CardContent className="p-4 pt-0 text-sm">{snapshot.lastError}</CardContent>
          </Card>
        ) : null}

        <Card className="border-white/12 bg-white/8 shadow-[0_10px_30px_rgba(0,0,0,0.35)] backdrop-blur-2xl">
          <CardContent className="p-4">
            <MetricsGrid snapshot={snapshot} loading={loading} variant="tray" />
          </CardContent>
        </Card>
      </div>
    </main>
  );
}
