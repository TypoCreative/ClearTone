import { useEffect, useState } from "react";

export type ThemePreference = "light" | "dark";

const STORAGE_KEY = "cleartone-theme";

function applyTheme(theme: ThemePreference) {
  document.documentElement.classList.toggle("dark", theme === "dark");
  document.documentElement.style.colorScheme = theme;
}

export function useThemePreference() {
  const [theme, setTheme] = useState<ThemePreference>(() => {
    if (typeof window === "undefined") return "dark";
    const stored = window.localStorage.getItem(STORAGE_KEY);
    return stored === "light" ? "light" : "dark";
  });

  useEffect(() => {
    applyTheme(theme);
    window.localStorage.setItem(STORAGE_KEY, theme);
  }, [theme]);

  return { theme, setTheme };
}
