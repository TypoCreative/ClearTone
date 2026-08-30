import { MoonIcon, SunIcon } from "@radix-ui/react-icons";
import { Switch } from "./ui/switch";
import { useThemePreference } from "../hooks/useThemePreference";
import { cn } from "../lib/utils";

type Props = {
  compact?: boolean;
};

export function ThemeToggle({ compact = false }: Props) {
  const { theme, setTheme } = useThemePreference();
  const isDark = theme === "dark";

  return (
    <div
      className={cn(
        "flex items-center gap-2 rounded-full border border-border/60 bg-card/50 backdrop-blur-md",
        compact ? "px-2.5 py-1" : "px-3 py-1.5"
      )}
    >
      <SunIcon
        aria-hidden="true"
        className={cn(
          "h-4 w-4 transition-colors",
          isDark ? "text-muted-foreground" : "text-primary"
        )}
      />
      <Switch
        checked={isDark}
        onCheckedChange={(checked) => setTheme(checked ? "dark" : "light")}
        aria-label="Toggle dark theme"
      />
      <MoonIcon
        aria-hidden="true"
        className={cn(
          "h-4 w-4 transition-colors",
          isDark ? "text-primary" : "text-muted-foreground"
        )}
      />
    </div>
  );
}
