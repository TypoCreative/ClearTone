import type { AudioInputDevice, EngineSnapshot } from "@contracts";
import { DeviceSelect } from "../components/DeviceSelect";
import { MetricsGrid } from "../components/MetricsGrid";
import { StartStopControls } from "../components/StartStopControls";
import { StrengthSlider } from "../components/StrengthSlider";
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
    <main className="bg-transparent p-2 text-foreground">
      <div className="flex flex-col gap-2">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between gap-2 p-3">
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

        <Card>
          <CardContent className="space-y-2 p-3">
            <DeviceSelect
              snapshot={snapshot}
              selectedInput={selectedInput}
              value={inputControlValue}
              disabled={snapshot.inputs.length === 0}
              variant="tray"
            />
            <StrengthSlider snapshot={snapshot} variant="tray" />
          </CardContent>
        </Card>

        {snapshot.lastError ? (
          <Card className="border-destructive/30 bg-destructive/10">
            <CardHeader className="p-3 pb-2">
              <CardTitle className="text-sm">Engine Error</CardTitle>
            </CardHeader>
            <CardContent className="p-3 pt-0 text-sm">{snapshot.lastError}</CardContent>
          </Card>
        ) : null}

        <Card>
          <CardContent className="p-3">
            <MetricsGrid snapshot={snapshot} loading={loading} variant="tray" />
          </CardContent>
        </Card>
      </div>
    </main>
  );
}
