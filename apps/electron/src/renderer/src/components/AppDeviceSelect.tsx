import type { ChangeEvent } from "react";
import type { AudioInputDevice, EngineSnapshot } from "@contracts";
import { cn } from "../lib/utils";
import { formatDeviceMode } from "../utils/engineUi";

type Props = {
  snapshot: EngineSnapshot;
  selectedInput: AudioInputDevice | undefined;
  value: string;
  disabled: boolean;
};

export function AppDeviceSelect({ snapshot, selectedInput, value, disabled }: Props) {
  const handleChange = (event: ChangeEvent<HTMLSelectElement>) => {
    const nextValue = event.target.value;

    if (nextValue === "__follow_system__") {
      void window.clearTone.followSystemInput();
      return;
    }

    void window.clearTone.selectInput(nextValue);
  };

  return (
    <div className="space-y-2">
      <div className="text-[11px] font-medium uppercase tracking-wide text-muted-foreground">
        Select Device
      </div>
      <select
        value={value}
        onChange={handleChange}
        disabled={disabled}
        className={cn(
          "h-10 w-full rounded-md border border-input bg-background px-3 text-sm text-foreground outline-none",
          "focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background",
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
      <div className="text-xs text-muted-foreground">{formatDeviceMode(snapshot, selectedInput)}</div>
    </div>
  );
}
