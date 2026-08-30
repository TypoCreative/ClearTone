import { memo, useCallback, useState } from "react";
import type { EngineSnapshot } from "@contracts";
import { Switch } from "./ui/switch";
import { Button } from "./ui/button";
import { runEngineAction } from "../utils/runEngineAction";
import { cn } from "../lib/utils";

type Props = {
  snapshot: EngineSnapshot;
  variant?: "app" | "tray";
};

export const VirtualMicrophoneControl = memo(function VirtualMicrophoneControl({
  snapshot,
  variant = "app"
}: Props) {
  const [busy, setBusy] = useState(false);
  const [installerOpened, setInstallerOpened] = useState(false);
  const state = snapshot.virtualMicrophone;

  const handleChange = useCallback(async (enabled: boolean) => {
    setBusy(true);
    await runEngineAction(() => window.clearTone.setVirtualMicrophone(enabled));
    setBusy(false);
  }, []);

  const handleInstall = useCallback(async () => {
    setBusy(true);
    const opened = await runEngineAction(() => window.clearTone.installVirtualMicrophoneDriver());
    setInstallerOpened(opened);
    setBusy(false);
  }, []);

  return (
    <div
      className={cn(
        "rounded-xl border",
        variant === "tray"
          ? "border-white/10 bg-white/5 p-3"
          : "border-border/60 bg-background/30 p-4"
      )}
    >
      <div className="flex items-start justify-between gap-4">
        <div className="min-w-0">
          <div
            className={cn(
              "font-semibold",
              variant === "tray" ? "text-[11px] text-slate-200" : "text-sm text-foreground"
            )}
            id={`virtual-microphone-label-${variant}`}
          >
            Virtual Microphone
          </div>
          <p
            className={cn(
              "mt-1 break-words",
              variant === "tray" ? "text-[10px] leading-4 text-slate-400" : "text-xs text-muted-foreground"
            )}
            id={`virtual-microphone-description-${variant}`}
          >
            {state.statusMessage}
          </p>
        </div>
        <Switch
          aria-describedby={`virtual-microphone-description-${variant}`}
          aria-labelledby={`virtual-microphone-label-${variant}`}
          checked={state.enabled}
          disabled={busy || !state.available}
          onCheckedChange={handleChange}
        />
      </div>
      {!state.available ? (
        <div className="mt-3 space-y-2">
          <p
            className={cn(
              "text-pretty",
              variant === "tray" ? "text-[10px] leading-4 text-amber-200" : "text-xs text-amber-700 dark:text-amber-300"
            )}
            role="status"
            aria-live="polite"
          >
            {installerOpened
              ? "Driver installed. ClearTone is waiting for Core Audio to make it available."
              : "Install the ClearTone driver once. macOS will request administrator approval."}
          </p>
          <Button
            className={cn(variant === "tray" && "h-8 w-full text-xs")}
            disabled={busy}
            onClick={handleInstall}
            size="sm"
            type="button"
            variant="outline"
          >
            {busy ? "Installing…" : installerOpened ? "Install Again" : "Install Driver"}
          </Button>
        </div>
      ) : null}
    </div>
  );
});
