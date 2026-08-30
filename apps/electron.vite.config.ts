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
        output: {}
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
