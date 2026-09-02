import React from "react";
import ReactDOM from "react-dom/client";
import "./globals.css";
import { useEngineSnapshot } from "./hooks/useEngineSnapshot";
import { TrayView } from "./views/TrayView";

document.documentElement.classList.add("dark", "tray");

function TrayRoot() {
  const { snapshot, loading, selectedInput, actionError, dismissActionError } = useEngineSnapshot();

  return (
    <TrayView
      snapshot={snapshot}
      loading={loading}
      selectedInput={selectedInput}
      actionError={actionError}
      dismissActionError={dismissActionError}
    />
  );
}

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    <TrayRoot />
  </React.StrictMode>
);
