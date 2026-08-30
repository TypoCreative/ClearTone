import { memo, useCallback } from "react";
import type { EngineSnapshot } from "@contracts";
import { Button } from "./ui/button";
import { runEngineAction } from "../utils/runEngineAction";

type Props = {
  permission: EngineSnapshot["permission"];
  compact?: boolean;
};

export const MicrophonePermissionAction = memo(function MicrophonePermissionAction({
  permission,
  compact = false
}: Props) {
  const needsPermission =
    permission === "not-determined" ||
    permission === "denied" ||
    permission === "restricted";

  const handleClick = useCallback(() => {
    void runEngineAction(() => window.clearTone.requestMicrophoneAccess());
  }, []);

  if (!needsPermission) {
    return null;
  }

  const label =
    permission === "not-determined" ? "Allow Microphone" : "Open Microphone Settings";

  return (
    <Button
      className={compact ? "h-8 w-full text-xs" : "mt-4"}
      onClick={handleClick}
      size={compact ? "sm" : "default"}
      variant="outline"
    >
      {label}
    </Button>
  );
});
