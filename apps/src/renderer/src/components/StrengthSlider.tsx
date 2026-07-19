import type { ChangeEvent, FormEvent } from "react";
import { useEffect, useState } from "react";
import type { EngineSnapshot } from "@contracts";
import { cn } from "../lib/utils";
import { formatPercent } from "../utils/engineUi";

type Props = {
  snapshot: EngineSnapshot;
  variant?: "app" | "tray";
};

export function StrengthSlider({ snapshot, variant = "app" }: Props) {
  const externalStrengthValue = Math.round(snapshot.strength * 100);
  const [strengthValue, setStrengthValue] = useState(externalStrengthValue);
  const label = variant === "tray" ? "Strength" : "Denoise Strength";

  const handleInput = (event: FormEvent<HTMLInputElement>) => {
    setStrengthValue(Number(event.currentTarget.value));
  };

  const handleCommit = (event: ChangeEvent<HTMLInputElement>) => {
    const nextValue = Number(event.target.value);
    setStrengthValue(nextValue);
    void window.clearTone.setStrength(nextValue / 100);
  };

  useEffect(() => {
    setStrengthValue(externalStrengthValue);
  }, [externalStrengthValue]);

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
          {formatPercent(strengthValue / 100)}
        </span>
      </div>
      <div className="flex items-center gap-3">
        <input
          type="range"
          value={strengthValue}
          min={0}
          max={100}
          step={1}
          onInput={handleInput}
          onChange={handleCommit}
          style={{ "--value-percent": `${strengthValue}%` } as React.CSSProperties}
          className={cn(
            "range-futuristic",
            variant === "tray" && "range-futuristic-sm"
          )}
        />
      </div>
    </div>
  );
}
