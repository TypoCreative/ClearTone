import type { EngineSnapshot } from "@contracts";
import { formatPercent } from "../utils/engineUi";
import { Slider } from "./ui/slider";

type Props = {
  snapshot: EngineSnapshot;
  variant?: "app" | "tray";
};

export function StrengthSlider({ snapshot, variant = "app" }: Props) {
  const strengthValue = Math.round(snapshot.strength * 100);
  const label = variant === "tray" ? "Strength" : "Denoise Strength";

  return (
    <div className={variant === "tray" ? "space-y-1.5" : "space-y-2"}>
      <div className="text-[11px] font-medium uppercase tracking-wide text-muted-foreground">
        {label}
      </div>
      <div className="flex items-center gap-3">
        <Slider
          value={[strengthValue]}
          min={0}
          max={100}
          step={1}
          onValueChange={(values) => void window.clearTone.setStrength((values[0] ?? 0) / 100)}
        />
        <div className={variant === "tray" ? "w-10 text-right font-mono text-xs" : "w-12 text-right font-mono text-sm"}>
          {formatPercent(snapshot.strength)}
        </div>
      </div>
    </div>
  );
}
