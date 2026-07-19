import { Switch } from "./ui/switch";
import { useThemePreference } from "../hooks/useThemePreference";

type Props = {
  compact?: boolean;
};

export function ThemeToggle({ compact = false }: Props) {
  const { theme, setTheme } = useThemePreference();
  const isDark = theme === "dark";

  return (
    <div className={compact ? "flex items-center gap-2" : "flex items-center gap-3"}>
      <span className={compact ? "text-xs text-muted-foreground" : "text-sm text-muted-foreground"}>
        Dark
      </span>
      <Switch
        checked={isDark}
        onCheckedChange={(checked) => setTheme(checked ? "dark" : "light")}
        aria-label="Toggle dark theme"
      />
    </div>
  );
}
