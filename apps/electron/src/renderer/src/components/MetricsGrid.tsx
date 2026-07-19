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
      { label: "Input RMS", value: formatRms(snapshot.metrics.inputRms) },
      { label: "Output RMS", value: formatRms(snapshot.metrics.outputRms) },
      { label: "Noise Reduction", value: formatPercent(snapshot.metrics.noiseReductionPercent / 100) },
      { label: "Latency", value: formatLatency(snapshot.metrics.estimatedLatencyMs) }
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

  return (
    <section
      className={
        variant === "tray"
          ? "grid grid-cols-2 gap-2"
          : "grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
      }
    >
      {metrics.map((metric) => (
        <Card key={metric.label} className="p-4">
          <div className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
            {metric.label}
          </div>
          <div className={variant === "tray" ? "mt-1 text-lg font-semibold" : "mt-1 text-xl font-semibold"}>
            {metric.value}
          </div>
        </Card>
      ))}
    </section>
  );
}
