import type { EngineSnapshot } from "@contracts";
import { formatLatency, formatPercent, formatRms, phaseLabels } from "../utils/engineUi";
import { Card } from "./ui/card";

type Variant = "app" | "tray";

type Props = {
  snapshot: EngineSnapshot;
  loading: boolean;
  variant: Variant;
};

type Metric = {
  label: string;
  value: string;
};

function buildMetrics(snapshot: EngineSnapshot, loading: boolean, variant: Variant): Metric[] {
  if (variant === "tray") {
    return [
      { label: "In", value: formatRms(snapshot.metrics.inputRms) },
      { label: "Out", value: formatRms(snapshot.metrics.outputRms) },
      { label: "NR", value: formatPercent(snapshot.metrics.noiseReductionPercent / 100) },
      { label: "Lat", value: formatLatency(snapshot.metrics.estimatedLatencyMs) }
    ];
  }

  return [
    { label: "Status", value: loading ? "Connecting" : phaseLabels[snapshot.phase] },
    { label: "Permission", value: snapshot.permission },
    { label: "Frames", value: snapshot.metrics.framesProcessed.toLocaleString() },
    { label: "Input RMS", value: formatRms(snapshot.metrics.inputRms) },
    { label: "Output RMS", value: formatRms(snapshot.metrics.outputRms) },
    { label: "Noise Reduction", value: formatPercent(snapshot.metrics.noiseReductionPercent / 100) },
    { label: "Latency", value: formatLatency(snapshot.metrics.estimatedLatencyMs) }
  ];
}

export function MetricsGrid({ snapshot, loading, variant }: Props) {
  const metrics = buildMetrics(snapshot, loading, variant);

  if (variant === "tray") {
    return (
      <section className="divide-y divide-border/40">
        {metrics.map((metric) => (
          <div key={metric.label} className="flex items-center justify-between gap-3 py-2">
            <div className="text-[11px] font-medium uppercase tracking-wide text-muted-foreground">
              {metric.label}
            </div>
            <div className="font-mono text-sm font-semibold tabular-nums text-foreground">
              {metric.value}
            </div>
          </div>
        ))}
      </section>
    );
  }

  return (
    <section
      className={
        "grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
      }
    >
      {metrics.map((metric) => (
        <Card key={metric.label} className="p-4">
          <div className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
            {metric.label}
          </div>
          <div className="mt-1 text-xl font-semibold">{metric.value}</div>
        </Card>
      ))}
    </section>
  );
}
