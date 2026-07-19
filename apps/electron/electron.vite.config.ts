import { resolve } from "node:path";
import { defineConfig, externalizeDepsPlugin } from "electron-vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  main: {
    plugins: [externalizeDepsPlugin()],
    resolve: {
      alias: {
        "@contracts": resolve(__dirname, "../../packages/contracts/src")
      }
    }
  },
  preload: {
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
        "@contracts": resolve(__dirname, "../../packages/contracts/src")
      }
    }
  },
  renderer: {
    resolve: {
      alias: {
        "@contracts": resolve(__dirname, "../../packages/contracts/src")
      }
    },
    plugins: [react()]
  }
});
