import { memo } from "react";
import { Button } from "./ui/button";
import { cn } from "../lib/utils";

type Props = {
  message: string | null;
  onDismiss: () => void;
  compact?: boolean;
};

export const ActionError = memo(function ActionError({ message, onDismiss, compact = false }: Props) {
  if (!message) return null;

  return (
    <div
      aria-live="polite"
      className={cn(
        "flex items-start justify-between gap-3 rounded-xl border border-red-400/30 bg-red-400/10 text-red-100",
        compact ? "px-3 py-2 text-[11px]" : "p-4 text-sm"
      )}
      role="alert"
    >
      <p className="min-w-0 break-words">{message}</p>
      <Button
        aria-label="Dismiss error"
        className={compact ? "h-7 px-2 text-[10px]" : "shrink-0"}
        onClick={onDismiss}
        size="sm"
        type="button"
        variant="ghost"
      >
        Dismiss
      </Button>
    </div>
  );
});
