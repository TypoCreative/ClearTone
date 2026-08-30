import { memo, useCallback, useEffect, useRef, useState } from "react";
import type { EngineSnapshot } from "@contracts";
import { cn } from "../lib/utils";
import { formatPercent } from "../utils/engineUi";
import { runEngineAction } from "../utils/runEngineAction";

type Props = {
  snapshot: EngineSnapshot;
  variant?: "app" | "tray";
};

export const StrengthSlider = memo(function StrengthSlider({ snapshot, variant = "app" }: Props) {
  const strengthPercent = Math.round(snapshot.strength * 100);
  const [displayStrength, setDisplayStrength] = useState(strengthPercent);
  const updateTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const label = variant === "tray" ? "Strength" : "Denoise Strength";

  useEffect(() => {
    if (!updateTimer.current) {
      setDisplayStrength(strengthPercent);
    }
  }, [strengthPercent]);

  useEffect(() => () => {
    if (updateTimer.current) clearTimeout(updateTimer.current);
  }, []);

  const handleChange = useCallback(
    (event: React.ChangeEvent<HTMLInputElement>) => {
      const nextStrength = Number(event.target.value);
      setDisplayStrength(nextStrength);
      if (updateTimer.current) clearTimeout(updateTimer.current);
      updateTimer.current = setTimeout(() => {
        updateTimer.current = null;
        void runEngineAction(() => window.clearTone.setStrength(nextStrength / 100));
      }, 80);
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
        <label htmlFor={`denoise-strength-${variant}`}>{label}</label>
        <span
          className={cn(
            "font-mono tabular-nums",
            variant === "tray" ? "text-[12px] font-semibold text-white" : "text-sm font-semibold text-primary"
          )}
        >
          {formatPercent(displayStrength / 100)}
        </span>
      </div>
      <div className="flex items-center gap-3">
        <input
          aria-valuetext={`${displayStrength}%`}
          id={`denoise-strength-${variant}`}
          name="denoise-strength"
          type="range"
          value={displayStrength}
          min={0}
          max={100}
          step={1}
          onChange={handleChange}
          style={{ "--value-percent": `${displayStrength}%` } as React.CSSProperties}
          className={cn(
            "range-futuristic",
            variant === "tray" && "range-futuristic-sm"
          )}
        />
      </div>
    </div>
  );
});
