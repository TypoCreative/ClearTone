import { useEffect, useRef, useState } from "react";
import type { AudioInputDevice, EngineSnapshot } from "@contracts";
import { MetricsGrid } from "../components/MetricsGrid";
import { StartStopControls } from "../components/StartStopControls";
import { StrengthSlider } from "../components/StrengthSlider";
import { Switch } from "../components/ui/switch";
import { TrayDeviceSelect } from "../components/TrayDeviceSelect";
import { cn } from "../lib/utils";
import { deriveControlState, formatDeviceMode, phaseLabels } from "../utils/engineUi";

type Props = {
  snapshot: EngineSnapshot;
  loading: boolean;
  selectedInput: AudioInputDevice | undefined;
};

export function TrayView({ snapshot, loading, selectedInput }: Props) {
  const { canStart, canStop, inputControlValue } = deriveControlState(snapshot);
  const statusLabel = loading ? "Connecting" : phaseLabels[snapshot.phase];
  const deviceModeLabel = formatDeviceMode(snapshot, selectedInput);
  const isProcessing = snapshot.phase === "processing";
  const isError = snapshot.phase === "error";
  const [trayOnlyMode, setTrayOnlyMode] = useState(false);

  useEffect(() => {
    let mounted = true;

    void window.clearTone.getSettings().then((settings) => {
      if (mounted) {
        setTrayOnlyMode(settings.trayOnlyMode);
      }
    });

    const unsubscribe = window.clearTone.onSettings((settings) => {
      if (mounted) {
        setTrayOnlyMode(settings.trayOnlyMode);
      }
    });

    return () => {
      mounted = false;
      unsubscribe();
    };
  }, []);

  const statusClassName = cn(
    "inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.18em]",
    isProcessing
      ? "border-emerald-400/30 bg-emerald-400/15 text-emerald-100 shadow-[0_0_12px_rgba(52,211,153,0.18)]"
      : isError
        ? "border-red-400/30 bg-red-400/15 text-red-100"
        : "border-white/10 bg-white/8 text-slate-200"
  );

  const mainRef = useRef<HTMLElement>(null);

  useEffect(() => {
    if (!mainRef.current) return;
    const observer = new ResizeObserver((entries) => {
      for (const entry of entries) {
        if (entry.target === mainRef.current) {
          void window.clearTone.resizeTray(entry.contentRect.height);
        }
      }
    });
    observer.observe(mainRef.current);
    return () => observer.disconnect();
  }, []);

  return (
    <main
      ref={mainRef}
      className={cn(
        "flex flex-col gap-4 rounded-[28px] border p-4 text-slate-100 shadow-[0_24px_60px_rgba(0,0,0,0.45)] backdrop-blur-3xl",
        "bg-[linear-gradient(180deg,rgb(55,60,75),rgb(26,30,42))]",
        "border-white/18"
      )}
    >
      <div className="flex flex-col gap-3">
        <div className="flex items-start justify-between gap-3">
          <div className="space-y-0.5">
            <div className="font-mono text-[11px] font-semibold tracking-[0.22em] text-white/90">
              CLEARTONE
            </div>
            <div className="max-w-[180px] truncate text-[11px] text-slate-400">{deviceModeLabel}</div>
          </div>
          <span className={statusClassName}>
            <span
              className={cn(
                "h-1.5 w-1.5 rounded-full",
                isProcessing
                  ? "animate-pulse bg-emerald-300"
                  : isError
                    ? "bg-red-300"
                    : "bg-slate-300"
              )}
            />
            {statusLabel}
          </span>
        </div>

        <StartStopControls
          canStart={canStart}
          canStop={canStop}
          mode="toggle"
          variant="trayHeader"
        />
      </div>

      <div className="space-y-3.5 rounded-2xl border border-white/10 bg-white/5 p-3.5">
        <TrayDeviceSelect
          snapshot={snapshot}
          value={inputControlValue}
          disabled={snapshot.inputs.length === 0}
        />
        <StrengthSlider snapshot={snapshot} variant="tray" />
      </div>

      {snapshot.lastError ? (
        <div className="rounded-xl border border-red-400/20 bg-red-400/10 px-3 py-2.5 text-[11px] font-medium text-red-100">
          ERR // {snapshot.lastError}
        </div>
      ) : null}

      <div className="space-y-1.5">
        <div className="text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-400">
          Live Metrics
        </div>
        <MetricsGrid snapshot={snapshot} loading={loading} variant="tray" />
      </div>

      <div className="space-y-3 border-t border-white/10 pt-3">
        <div className="flex items-center justify-between gap-3">
          <span className="text-[11px] font-medium text-slate-300">Tray only mode</span>
          <Switch
            checked={trayOnlyMode}
            onCheckedChange={(checked) => {
              setTrayOnlyMode(checked);
              void window.clearTone.setTrayOnlyMode(checked);
            }}
          />
        </div>
        <div className="flex items-center justify-between gap-3">
          {!trayOnlyMode ? (
            <button
              className="text-[11px] font-medium text-slate-300 transition-colors hover:text-white"
              onClick={() => void window.clearTone.showMainWindow()}
              type="button"
            >
              Show ClearTone
            </button>
          ) : (
            <span className="text-[11px] text-slate-500">Main window hidden</span>
          )}
          <button
            className="text-[11px] font-medium text-slate-400 transition-colors hover:text-white"
            onClick={() => void window.clearTone.quitApp()}
            type="button"
          >
            Quit
          </button>
        </div>
      </div>
    </main>
  );
}
