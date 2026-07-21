import { memo, useCallback } from "react";
import type { AudioInputDevice, EngineSnapshot } from "@contracts";
import { formatDeviceMode } from "../utils/engineUi";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectSeparator,
  SelectTrigger,
  SelectValue
} from "./ui/select";

type Props = {
  snapshot: EngineSnapshot;
  selectedInput: AudioInputDevice | undefined;
  value: string;
  disabled: boolean;
  variant?: "app" | "tray";
};

export const DeviceSelect = memo(function DeviceSelect({
  snapshot,
  selectedInput,
  value,
  disabled,
  variant = "app",
}: Props) {
  const handleChange = useCallback((nextValue: string) => {
    if (nextValue === "__follow_system__") {
      void window.clearTone.followSystemInput();
      return;
    }
    void window.clearTone.selectInput(nextValue);
  }, []);

  const label = variant === "tray" ? "Mic" : "Select Device";

  return (
    <div className={variant === "tray" ? "space-y-1.5" : "space-y-2"}>
      <div className="text-[11px] font-medium uppercase tracking-wide text-muted-foreground">
        {label}
      </div>
      <Select value={value} onValueChange={handleChange} disabled={disabled}>
        <SelectTrigger className={variant === "tray" ? "h-9 text-xs" : ""}>
          <SelectValue placeholder={variant === "tray" ? "Input" : "Select input"} />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="__follow_system__">Follow system input</SelectItem>
          <SelectSeparator />
          {snapshot.inputs.map((input) => (
            <SelectItem key={input.id} value={input.id}>
              {input.name}
              {input.isDefault ? " (System)" : ""}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      {variant === "app" ? (
        <div className="text-xs text-muted-foreground">{formatDeviceMode(snapshot, selectedInput)}</div>
      ) : null}
    </div>
  );
});
