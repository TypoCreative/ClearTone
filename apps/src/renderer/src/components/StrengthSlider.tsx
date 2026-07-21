import { memo, useCallback } from "react";
import type { EngineSnapshot } from "@contracts";
import { cn } from "../lib/utils";
import { formatPercent } from "../utils/engineUi";

type Props = {
  snapshot: EngineSnapshot;
  variant?: "app" | "tray";
};

export const StrengthSlider = memo(function StrengthSlider({ snapshot, variant = "app" }: Props) {
  const strengthPercent = Math.round(snapshot.strength * 100);
  const label = variant === "tray" ? "Strength" : "Denoise Strength";

  const handleChange = useCallback(
    (event: React.ChangeEvent<HTMLInputElement>) => {
      void window.clearTone.setStrength(Number(event.target.value) / 100);
    },
    []
  );

  return (
    <div className={variant === "tray" ? "space-y-1.5" : "space-y-2"}>
      <div
        className={cn(
          "flex items-center justify-between uppercase tracking-wide",
          variant === "tray"
            ? "text-[10px] font-semibold tracking-[0.18em] text-slate-400"
            : "text-[11px] font-semibold text-muted-foreground"
        )}
      >
        <span>{label}</span>
        <span
          className={cn(
            "font-mono tabular-nums",
            variant === "tray" ? "text-[12px] font-semibold text-white" : "text-sm font-semibold text-primary"
          )}
        >
          {formatPercent(strengthPercent / 100)}
        </span>
      </div>
      <div className="flex items-center gap-3">
        <input
          type="range"
          value={strengthPercent}
          min={0}
          max={100}
          step={1}
          onChange={handleChange}
          style={{ "--value-percent": `${strengthPercent}%` } as React.CSSProperties}
          className={cn(
            "range-futuristic",
            variant === "tray" && "range-futuristic-sm"
          )}
        />
      </div>
    </div>
  );
});
