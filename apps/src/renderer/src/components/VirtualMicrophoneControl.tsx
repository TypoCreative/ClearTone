import { memo, useCallback, useState } from "react";
import { QuestionMarkCircledIcon } from "@radix-ui/react-icons";
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
              "flex items-center gap-1.5 font-semibold",
              variant === "tray" ? "text-[11px] text-slate-200" : "text-sm text-foreground"
            )}
          >
            <span id={`virtual-microphone-label-${variant}`}>Virtual Microphone</span>
            <button
              aria-describedby={`virtual-microphone-tooltip-${variant}`}
              aria-label="About Virtual Microphone routing"
              className="group relative rounded-full text-muted-foreground outline-none hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring"
              type="button"
            >
              <QuestionMarkCircledIcon aria-hidden="true" className="h-3.5 w-3.5" />
              <span
                className="invisible absolute bottom-full left-1/2 z-30 mb-2 w-48 -translate-x-1/2 rounded-md border border-border bg-popover px-2.5 py-2 text-left text-[10px] font-normal leading-4 text-popover-foreground opacity-0 shadow-lg transition-opacity group-hover:visible group-hover:opacity-100 group-focus-visible:visible group-focus-visible:opacity-100"
                id={`virtual-microphone-tooltip-${variant}`}
                role="tooltip"
              >
                Turn on to route cleaned audio automatically.
              </span>
            </button>
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
          aria-describedby={`virtual-microphone-description-${variant} virtual-microphone-tooltip-${variant}`}
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
