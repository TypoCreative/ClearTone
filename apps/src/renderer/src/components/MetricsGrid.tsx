import { memo, useMemo } from "react";
import type { EngineSnapshot } from "@contracts";
import { cn } from "../lib/utils";
import { formatLatency, formatPercent, formatRms, integerFormatter, phaseLabels } from "../utils/engineUi";

type Variant = "app" | "tray";

type Props = {
  snapshot: EngineSnapshot;
  loading: boolean;
  variant: Variant;
};

export const MetricsGrid = memo(function MetricsGrid({ snapshot, loading, variant }: Props) {
  const metrics = useMemo(() => {
    if (variant === "tray") {
      return [
        { label: "In", value: formatRms(snapshot.metrics.inputRms) },
        { label: "Out", value: formatRms(snapshot.metrics.outputRms) },
        { label: "NR", value: formatPercent(snapshot.metrics.noiseReductionPercent / 100) },
        { label: "Lat", value: formatLatency(snapshot.metrics.estimatedLatencyMs) },
        { label: "Drop", value: integerFormatter.format(snapshot.metrics.droppedFrames) },
      ];
    }

    return [
      { label: "Status", value: loading ? "Connecting…" : phaseLabels[snapshot.phase] },
      { label: "Permission", value: snapshot.permission },
      { label: "Frames", value: integerFormatter.format(snapshot.metrics.framesProcessed) },
      { label: "Input RMS", value: formatRms(snapshot.metrics.inputRms) },
      { label: "Output RMS", value: formatRms(snapshot.metrics.outputRms) },
      { label: "Noise Reduction", value: formatPercent(snapshot.metrics.noiseReductionPercent / 100) },
      { label: "Latency", value: formatLatency(snapshot.metrics.estimatedLatencyMs) },
      { label: "Dropped Frames", value: integerFormatter.format(snapshot.metrics.droppedFrames) },
      { label: "Output Queue", value: integerFormatter.format(snapshot.metrics.outputQueueFrames) },
    ];
  }, [snapshot, loading, variant]);

  if (variant === "tray") {
    return (
      <section className="flex flex-col">
        {metrics.map((metric, index) => (
          <div
            key={metric.label}
            className={cn(
              "flex items-center justify-between py-1.5",
              index !== metrics.length - 1 && "border-b border-white/8"
            )}
          >
            <span className="text-[9px] font-medium uppercase tracking-[0.14em] text-slate-400">{metric.label}</span>
            <span className="font-mono text-[11px] font-semibold tabular-nums text-white">{metric.value}</span>
          </div>
        ))}
      </section>
    );
  }

  return (
    <section className="grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-5">
      {metrics.map((metric) => (
        <article
          key={metric.label}
          className="relative overflow-hidden rounded-lg border border-white/10 bg-card/80 px-3 py-2.5"
        >
          <div className="absolute inset-x-8 top-0 h-px bg-linear-to-r from-transparent via-primary/30 to-transparent" />
          <div className="text-[9px] font-semibold uppercase tracking-[0.16em] text-muted-foreground">{metric.label}</div>
          <div className="mt-1 font-mono text-base font-semibold tabular-nums text-foreground">{metric.value}</div>
        </article>
      ))}
    </section>
  );
});
