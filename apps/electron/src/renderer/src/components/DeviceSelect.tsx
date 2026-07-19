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
};

export function DeviceSelect({ snapshot, selectedInput, value, disabled }: Props) {
  const handleChange = (nextValue: string) => {
    if (nextValue === "__follow_system__") {
      void window.clearTone.followSystemInput();
      return;
    }

    void window.clearTone.selectInput(nextValue);
  };

  return (
    <div className="space-y-2">
      <div className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
        Select Device
      </div>
      <Select value={value} onValueChange={handleChange} disabled={disabled}>
        <SelectTrigger>
          <SelectValue placeholder="Select input" />
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
      <div className="text-xs text-muted-foreground">{formatDeviceMode(snapshot, selectedInput)}</div>
    </div>
  );
}
