import { memo, useCallback, type ChangeEvent } from "react";
import type { EngineSnapshot } from "@contracts";
import { cn } from "../lib/utils";
import { runEngineAction } from "../utils/runEngineAction";

type Props = {
  snapshot: EngineSnapshot;
  value: string;
  disabled: boolean;
};

export const TrayDeviceSelect = memo(function TrayDeviceSelect({
  snapshot,
  value,
  disabled,
}: Props) {
  const systemInput = snapshot.inputs.find((input) => input.isDefault);
  const systemInputLabel = systemInput?.name ?? "System";

  const handleChange = useCallback((event: ChangeEvent<HTMLSelectElement>) => {
    const nextValue = event.target.value;
    if (nextValue === "__follow_system__") {
      void runEngineAction(() => window.clearTone.followSystemInput());
      return;
    }
    void runEngineAction(() => window.clearTone.selectInput(nextValue));
  }, []);

  return (
    <div className="space-y-1.5">
      <label className="text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-400" htmlFor="tray-input-device">Mic Input</label>
      <select
        autoComplete="off"
        id="tray-input-device"
        name="tray-input-device"
        value={value}
        onChange={handleChange}
        disabled={disabled}
        className={cn(
          "h-9 w-full rounded-xl border border-white/12 bg-white/10 px-3 text-[13px] font-medium text-white outline-none transition-colors",
          "focus-visible:border-white/30 focus-visible:bg-white/12 focus-visible:ring-2 focus-visible:ring-white/60",
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
});
