import type { ChangeEvent } from "react";
import type { EngineSnapshot } from "@contracts";
import { cn } from "../lib/utils";

type Props = {
  snapshot: EngineSnapshot;
  value: string;
  disabled: boolean;
};

export function TrayDeviceSelect({ snapshot, value, disabled }: Props) {
  const systemInput = snapshot.inputs.find((input) => input.isDefault);
  const systemInputLabel = systemInput?.name ?? "System";

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
      <div className="text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-400">Mic Input</div>
      <select
        value={value}
        onChange={handleChange}
        disabled={disabled}
        className={cn(
          "h-9 w-full rounded-xl border border-white/12 bg-white/8 px-3 text-[13px] font-medium text-white outline-none transition-colors backdrop-blur-xl",
          "focus-visible:border-white/30 focus-visible:bg-white/12",
          "disabled:cursor-not-allowed disabled:opacity-50"
        )}
      >
        <option value="__follow_system__">Follow system input ({systemInputLabel})</option>
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
