import type { AudioInputDevice, EngineSnapshot } from "@contracts";
import { AppDeviceSelect } from "../components/AppDeviceSelect";
import { MetricsGrid } from "../components/MetricsGrid";
import { StartStopControls } from "../components/StartStopControls";
import { StrengthSlider } from "../components/StrengthSlider";
import { ThemeToggle } from "../components/ThemeToggle";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../components/ui/card";
import { deriveControlState } from "../utils/engineUi";

type Props = {
  snapshot: EngineSnapshot;
  loading: boolean;
  selectedInput: AudioInputDevice | undefined;
};

export function AppView({ snapshot, loading, selectedInput }: Props) {
  const { canStart, canStop, inputControlValue } = deriveControlState(snapshot);

  return (
    <main className="flex min-h-full items-center justify-center p-6 text-foreground">
      <div className="flex w-full max-w-4xl flex-col gap-4">
        <Card>
          <CardHeader className="flex flex-row items-start justify-between gap-4">
            <div className="space-y-1">
              <div className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                ClearTone
              </div>
              <CardTitle className="text-2xl">Utility Dashboard</CardTitle>
              <CardDescription className="text-base">{snapshot.statusMessage}</CardDescription>
            </div>
            <ThemeToggle />
          </CardHeader>
        </Card>

        <section className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle>Start / Stop</CardTitle>
              <CardDescription>Control the denoise engine.</CardDescription>
            </CardHeader>
            <CardContent>
              <StartStopControls canStart={canStart} canStop={canStop} mode="toggle" variant="app" />
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Device / Strength</CardTitle>
              <CardDescription>Choose input and tune denoise intensity.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <AppDeviceSelect
                snapshot={snapshot}
                selectedInput={selectedInput}
                value={inputControlValue}
                disabled={snapshot.inputs.length === 0}
              />
              <StrengthSlider snapshot={snapshot} />
            </CardContent>
          </Card>
        </section>

        {snapshot.lastError ? (
          <Card className="border-destructive/30 bg-destructive/10">
            <CardHeader className="pb-3">
              <CardTitle className="text-base">Engine Error</CardTitle>
            </CardHeader>
            <CardContent className="pt-0 text-sm">{snapshot.lastError}</CardContent>
          </Card>
        ) : null}

        <Card>
          <CardHeader className="pb-3">
            <CardTitle>Engine Metrics</CardTitle>
          </CardHeader>
          <CardContent className="pt-0">
            <MetricsGrid snapshot={snapshot} loading={loading} variant="app" />
          </CardContent>
        </Card>
      </div>
    </main>
  );
}
