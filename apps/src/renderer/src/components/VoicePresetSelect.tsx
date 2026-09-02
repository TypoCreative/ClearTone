import { memo, useCallback, type ChangeEvent } from "react";
import { ChevronDownIcon } from "@radix-ui/react-icons";
import type { EngineSnapshot, VoicePreset } from "@contracts";
import { cn } from "../lib/utils";
import { runEngineAction } from "../utils/runEngineAction";

type Props = {
  snapshot: EngineSnapshot;
  variant?: "app" | "tray";
};

const presetDescriptions: Record<VoicePreset, string> = {
  natural: "Gentle cleanup with the most natural dynamics",
  clear: "Balanced clarity for calls and everyday recording",
  broadcast: "Fuller, louder voice with stronger control"
};

export const VoicePresetSelect = memo(function VoicePresetSelect({
  snapshot,
  variant = "app"
}: Props) {
  const handleChange = useCallback((event: ChangeEvent<HTMLSelectElement>) => {
    void runEngineAction(() =>
      window.clearTone.setVoicePreset(event.target.value as VoicePreset)
    );
  }, []);

  return (
    <div className={variant === "tray" ? "space-y-1.5" : "space-y-2"}>
      <label
        className={cn(
          "font-semibold uppercase tracking-wide",
          variant === "tray"
            ? "text-[10px] tracking-[0.18em] text-slate-400"
            : "text-[11px] text-muted-foreground"
        )}
        htmlFor={`voice-preset-${variant}`}
      >
        Voice Profile
      </label>
      <div className="relative">
        <select
          aria-describedby={`voice-preset-description-${variant}`}
          className={cn(
            "w-full appearance-none rounded-xl border pr-9 font-medium outline-none transition-[border-color,background-color,box-shadow]",
            variant === "tray"
              ? "h-9 border-white/10 bg-white/5 px-3 text-xs text-white focus-visible:ring-2 focus-visible:ring-white/60"
              : "h-11 border-border/60 bg-background/40 px-4 text-sm text-foreground focus-visible:border-primary/50 focus-visible:ring-2 focus-visible:ring-primary/30"
          )}
          id={`voice-preset-${variant}`}
          onChange={handleChange}
          value={snapshot.voicePreset}
        >
          <option value="natural">Natural</option>
          <option value="clear">Clear</option>
          <option value="broadcast">Broadcast</option>
        </select>
        <ChevronDownIcon
          aria-hidden="true"
          className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 opacity-60"
        />
      </div>
      <p
        className={cn(
          variant === "tray" ? "text-[10px] leading-4 text-slate-400" : "text-xs text-muted-foreground"
        )}
        id={`voice-preset-description-${variant}`}
      >
        {presetDescriptions[snapshot.voicePreset]}
      </p>
    </div>
  );
});
