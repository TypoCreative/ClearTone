import { LightningBoltIcon } from "@radix-ui/react-icons";
import { cn } from "../lib/utils";

import { Button } from "./ui/button";

type Props = {
  canStart: boolean;
  canStop: boolean;
  mode?: "dual" | "toggle";
  variant: "app" | "tray" | "trayHeader";
};

export function StartStopControls({ canStart, canStop, mode = "dual", variant }: Props) {
  if (mode === "toggle") {
    const isActive = canStop;
    const label = isActive ? "Stop Processing" : "Start Processing";
    const disabled = isActive ? !canStop : !canStart;
    const handler = isActive
      ? () => void window.clearTone.stopProcessing()
      : () => void window.clearTone.startProcessing();

    if (variant === "trayHeader") {
      return (
        <button
          className={cn(
            "group relative flex h-12 w-full items-center justify-center overflow-hidden rounded-2xl border text-sm font-semibold tracking-wide transition-all",
            "disabled:pointer-events-none disabled:opacity-50",
            isActive
              ? "border-white/12 bg-white/8 text-white hover:bg-white/14"
              : "border-emerald-400/35 bg-linear-to-b from-emerald-400/85 to-emerald-500/80 text-emerald-950 shadow-[0_0_24px_rgba(52,211,153,0.28)] hover:shadow-[0_0_32px_rgba(52,211,153,0.38)] hover:from-emerald-300 hover:to-emerald-400"
          )}
          disabled={disabled}
          onClick={handler}
          type="button"
        >
          <span className="relative z-10">{label}</span>
        </button>
      );
    }

    if (variant === "app") {
      return (
        <button
          className={cn(
            "group relative flex h-20 w-full items-center justify-center gap-3 overflow-hidden rounded-2xl border text-lg font-bold tracking-wide transition-all",
            "disabled:pointer-events-none disabled:opacity-50",
            isActive
              ? "border-red-400/30 bg-linear-to-r from-red-500/90 to-red-600/90 text-white shadow-[0_0_30px_rgba(239,68,68,0.3)] hover:shadow-[0_0_40px_rgba(239,68,68,0.45)]"
              : "border-primary/30 bg-linear-to-r from-primary to-cyan-300 text-primary-foreground shadow-(--glow-primary) hover:shadow-(--glow-primary-hover) hover:brightness-110"
          )}
          disabled={disabled}
          onClick={handler}
          type="button"
        >
          <LightningBoltIcon className="h-5 w-5" />
          <span className="relative z-10">{label}</span>
        </button>
      );
    }

    return (
      <div className={variant === "tray" ? "flex" : "flex flex-col gap-3"}>
        <Button
          variant={isActive ? "secondary" : "default"}
          size={variant === "tray" ? "sm" : "default"}
          className={cn(variant === "tray" ? "h-9 w-full justify-center text-sm" : "")}
          disabled={disabled}
          onClick={handler}
        >
          {label}
        </Button>
      </div>
    );
  }

  return (
    <div className={variant === "tray" ? "flex flex-col gap-2" : "flex flex-col gap-3"}>
      <Button disabled={!canStart} onClick={() => void window.clearTone.startProcessing()}>
        Start
      </Button>
      <Button variant="secondary" disabled={!canStop} onClick={() => void window.clearTone.stopProcessing()}>
        Stop
      </Button>
    </div>
  );
}
