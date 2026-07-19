import type { ChangeEvent } from "react";
import type { EngineSnapshot } from "@contracts";
import { cn } from "../lib/utils";

type Props = {
  snapshot: EngineSnapshot;
  value: string;
  disabled: boolean;
};

export function TrayDeviceSelect({ snapshot, value, disabled }: Props) {
  const handleChange = (event: ChangeEvent<HTMLSelectElement>) => {
    const nextValue = event.target.value;

    if (nextValue === "__follow_system__") {
      void window.clearTone.followSystemInput();
      return;
    }

    void window.clearTone.selectInput(nextValue);
  };

  return (
    <div className="space-y-1.5">
      <div className="text-[11px] font-medium uppercase tracking-wide text-muted-foreground">Mic</div>
      <select
        value={value}
        onChange={handleChange}
        disabled={disabled}
        className={cn(
          "h-9 w-full rounded-md border border-input bg-background px-3 text-xs text-foreground outline-none",
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
    </div>
  );
}
