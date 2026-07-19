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
    const label = isActive ? "Stop" : "Start";
    const disabled = isActive ? !canStop : !canStart;
    const handler = isActive
      ? () => void window.clearTone.stopProcessing()
      : () => void window.clearTone.startProcessing();

    return (
      <div className={variant === "tray" ? "flex" : "flex flex-col gap-3"}>
        <Button
          variant={isActive ? "secondary" : "default"}
          size={variant === "tray" || variant === "trayHeader" ? "sm" : "default"}
          className={
            variant === "tray"
              ? "h-9 w-full justify-center text-sm"
              : variant === "trayHeader"
                ? "h-8 px-3 text-xs"
                : ""
          }
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
