import { memo, useEffect, useState } from "react";
import type { PerformanceMetrics } from "@contracts";
import { cn } from "../lib/utils";

const ACTIVE_SAMPLE_INTERVAL_MS = 10_000;
const IDLE_SAMPLE_INTERVAL_MS = 30_000;

function metricsChanged(current: PerformanceMetrics | null, next: PerformanceMetrics): boolean {
  if (!current) return true;
  return (
    Math.round(current.cpuPercent * 10) !== Math.round(next.cpuPercent * 10) ||
    Math.round(current.memoryMB) !== Math.round(next.memoryMB) ||
    Math.round(current.gpuPercent * 10) !== Math.round(next.gpuPercent * 10) ||
    Math.round(current.gpuMemoryMB) !== Math.round(next.gpuMemoryMB) ||
    current.gpuAvailable !== next.gpuAvailable ||
    current.processCount !== next.processCount
  );
}

type Props = {
  active: boolean;
  variant?: "app" | "tray";
};

export const PerformancePanel = memo(function PerformancePanel({
  active,
  variant = "app"
}: Props) {
  const [metrics, setMetrics] = useState<PerformanceMetrics | null>(null);

  useEffect(() => {
    let mounted = true;
    let requestPending = false;

    const sample = async () => {
      if (document.hidden || requestPending) return;
      requestPending = true;
      try {
        const nextMetrics = await window.clearTone.getPerformanceMetrics();
        if (mounted) {
          setMetrics((current) => metricsChanged(current, nextMetrics) ? nextMetrics : current);
        }
      } catch {
        if (mounted) setMetrics(null);
      } finally {
        requestPending = false;
      }
    };

    let timer: number | null = null;
    const scheduleSample = () => {
      timer = window.setTimeout(async () => {
        await sample();
        if (mounted) scheduleSample();
      }, active ? ACTIVE_SAMPLE_INTERVAL_MS : IDLE_SAMPLE_INTERVAL_MS);
    };

    void sample();
    scheduleSample();
    const handleVisibilityChange = () => {
      if (!document.hidden) void sample();
    };
    document.addEventListener("visibilitychange", handleVisibilityChange);
    return () => {
      mounted = false;
      if (timer !== null) window.clearTimeout(timer);
      document.removeEventListener("visibilitychange", handleVisibilityChange);
    };
  }, [active]);

  const items = [
    {
      label: "CPU",
      value: metrics ? `${metrics.cpuPercent.toFixed(1)}%` : "—",
      detail: metrics ? `${metrics.processCount} processes` : "Collecting"
    },
    {
      label: "Memory",
      value: metrics ? `${metrics.memoryMB.toFixed(1)} MB` : "—",
      detail: "Total resident"
    },
    {
      label: "GPU",
      value: metrics?.gpuAvailable ? `${metrics.gpuPercent.toFixed(1)}%` : "N/A",
      detail: metrics?.gpuAvailable ? `${metrics.gpuMemoryMB.toFixed(1)} MB` : "No GPU process"
    }
  ];

  return (
    <section aria-label="Application performance" className="grid grid-cols-3 gap-2">
      {items.map((item) => (
        <article
          className={cn(
            "rounded-lg border px-3 py-2",
            variant === "tray"
              ? "border-white/8 bg-white/4"
              : "border-border/50 bg-card/35"
          )}
          key={item.label}
        >
          <div className={cn(
            "text-[9px] font-semibold uppercase tracking-[0.16em]",
            variant === "tray" ? "text-slate-400" : "text-muted-foreground"
          )}>
            {item.label}
          </div>
          <div className={cn(
            "mt-0.5 font-mono font-semibold tabular-nums",
            variant === "tray" ? "text-[11px] text-white" : "text-sm text-foreground"
          )}>
            {item.value}
          </div>
          <div className={cn(
            "mt-0.5 truncate text-[9px]",
            variant === "tray" ? "text-slate-500" : "text-muted-foreground"
          )}>{item.detail}</div>
        </article>
      ))}
    </section>
  );
});
