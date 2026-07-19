import { resolve } from "node:path";
import { defineConfig, externalizeDepsPlugin } from "electron-vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  main: {
    cacheDir: resolve(__dirname, ".vite/main"),
    plugins: [externalizeDepsPlugin()],
    resolve: {
      alias: {
        "@contracts": resolve(__dirname, "../packages/contracts/src")
      }
    }
  },
  preload: {
    cacheDir: resolve(__dirname, ".vite/preload"),
    plugins: [externalizeDepsPlugin()],
    build: {
      rollupOptions: {
        output: {
          format: "cjs",
          entryFileNames: "[name].js"
        }
      }
    },
    resolve: {
      alias: {
        "@contracts": resolve(__dirname, "../packages/contracts/src")
      }
    }
  },
  renderer: {
    cacheDir: resolve(__dirname, ".vite/renderer"),
    build: {
      rollupOptions: {
        input: {
          main: resolve(__dirname, "src/renderer/index.html"),
          tray: resolve(__dirname, "src/renderer/tray.html")
        },
        output: {
          manualChunks(id) {
            if (id.includes("/src/renderer/src/")) {
              if (
                id.includes("/src/renderer/src/views/AppView") ||
                id.includes("/src/renderer/src/components/AppDeviceSelect") ||
                id.includes("/src/renderer/src/components/ThemeToggle") ||
                id.includes("/src/renderer/src/components/ui/switch") ||
                id.includes("/src/renderer/src/hooks/useThemePreference")
              ) {
                return "main-ui";
              }

              if (
                id.includes("/src/renderer/src/views/TrayView") ||
                id.includes("/src/renderer/src/components/TrayDeviceSelect")
              ) {
                return "tray-ui";
              }

              if (
                id.includes("/src/renderer/src/components/StrengthSlider") ||
                id.includes("/src/renderer/src/components/StartStopControls") ||
                id.includes("/src/renderer/src/components/MetricsGrid") ||
                id.includes("/src/renderer/src/components/ui/button") ||
                id.includes("/src/renderer/src/components/ui/card") ||
                id.includes("/src/renderer/src/hooks/useEngineSnapshot") ||
                id.includes("/src/renderer/src/lib/utils") ||
                id.includes("/src/renderer/src/utils/engineUi")
              ) {
                return "shared-ui";
              }

              return undefined;
            }

            if (!id.includes("node_modules")) {
              return undefined;
            }

            if (id.includes("/react/") || id.includes("/react-dom/")) {
              return "react-vendor";
            }

            if (id.includes("@radix-ui/react-select")) {
              return "radix-select";
            }

            if (id.includes("@radix-ui/react-switch")) {
              return "radix-switch";
            }

            if (id.includes("@radix-ui/react-slider")) {
              return "radix-slider";
            }

            return undefined;
          }
        }
      }
    },
    resolve: {
      alias: {
        "@contracts": resolve(__dirname, "../packages/contracts/src")
      }
    },
    plugins: [react()]
  }
});
