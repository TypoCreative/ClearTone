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
      <div className="text-[11px] font-medium uppercase tracking-wide text-muted-foreground">
        {label}
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
          className={cn(
            "h-2 w-full cursor-pointer appearance-none rounded-full bg-secondary accent-[hsl(var(--primary))]",
            "[&::-webkit-slider-runnable-track]:h-2 [&::-webkit-slider-runnable-track]:rounded-full [&::-webkit-slider-runnable-track]:bg-secondary",
            "[&::-webkit-slider-thumb]:mt-[-6px] [&::-webkit-slider-thumb]:h-5 [&::-webkit-slider-thumb]:w-5 [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:border [&::-webkit-slider-thumb]:border-primary/40 [&::-webkit-slider-thumb]:bg-background [&::-webkit-slider-thumb]:shadow",
            "[&::-moz-range-track]:h-2 [&::-moz-range-track]:rounded-full [&::-moz-range-track]:border-0 [&::-moz-range-track]:bg-secondary",
            "[&::-moz-range-thumb]:h-5 [&::-moz-range-thumb]:w-5 [&::-moz-range-thumb]:rounded-full [&::-moz-range-thumb]:border [&::-moz-range-thumb]:border-primary/40 [&::-moz-range-thumb]:bg-background [&::-moz-range-thumb]:shadow"
          )}
        />
        <div className={variant === "tray" ? "w-10 text-right font-mono text-xs" : "w-12 text-right font-mono text-sm"}>
          {formatPercent(strengthValue / 100)}
        </div>
      </div>
    </div>
  );
}
