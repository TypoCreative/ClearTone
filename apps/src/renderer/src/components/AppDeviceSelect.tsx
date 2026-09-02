import { memo, useCallback, type ChangeEvent } from "react";
import { ChevronDownIcon } from "@radix-ui/react-icons";
import type { AudioInputDevice, EngineSnapshot } from "@contracts";
import { cn } from "../lib/utils";
import { formatDeviceMode } from "../utils/engineUi";
import { runEngineAction } from "../utils/runEngineAction";

type Props = {
  snapshot: EngineSnapshot;
  selectedInput: AudioInputDevice | undefined;
  value: string;
  disabled: boolean;
};

export const AppDeviceSelect = memo(function AppDeviceSelect({
  snapshot,
  selectedInput,
  value,
  disabled,
}: Props) {
  const handleChange = useCallback((event: ChangeEvent<HTMLSelectElement>) => {
    const nextValue = event.target.value;
    if (nextValue === "__follow_system__") {
      void runEngineAction(() => window.clearTone.followSystemInput());
      return;
    }
    void runEngineAction(() => window.clearTone.selectInput(nextValue));
  }, []);

  return (
    <div className="space-y-2">
      <label className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground" htmlFor="app-input-device">
        Input Device
      </label>
      <div className="relative">
        <select
          autoComplete="off"
          id="app-input-device"
          name="input-device"
          value={value}
          onChange={handleChange}
          disabled={disabled}
          className={cn(
            "h-11 w-full appearance-none rounded-xl border border-border/60 bg-background/80 px-4 pr-10 text-sm font-medium text-foreground outline-none transition-[border-color,background-color,box-shadow]",
            "focus-visible:border-primary/50 focus-visible:bg-background/60 focus-visible:ring-2 focus-visible:ring-primary/30",
            "disabled:cursor-not-allowed disabled:opacity-50"
          )}
        >
          <option value="__follow_system__">Follow system input</option>
          {snapshot.inputs.map((input) => (
            <option key={input.id} value={input.id}>
              {input.name}
              {input.isDefault ? " (System)" : ""}
            </option>
          ))}
        </select>
        <ChevronDownIcon aria-hidden="true" className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
      </div>
      <div className="text-xs text-muted-foreground">{formatDeviceMode(snapshot, selectedInput)}</div>
    </div>
  );
});
