import type { EngineSnapshot } from "@contracts";
import { formatPercent } from "../utils/engineUi";
import { Slider } from "./ui/slider";

type Props = {
  snapshot: EngineSnapshot;
};

export function StrengthSlider({ snapshot }: Props) {
  const strengthValue = Math.round(snapshot.strength * 100);

  return (
    <div className="space-y-2">
      <div className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
        Denoise Strength
      </div>
      <div className="flex items-center gap-3">
        <Slider
          value={[strengthValue]}
          min={0}
          max={100}
          step={1}
          onValueChange={(values) => void window.clearTone.setStrength((values[0] ?? 0) / 100)}
        />
        <div className="w-12 text-right font-mono text-sm">{formatPercent(snapshot.strength)}</div>
      </div>
    </div>
  );
}
