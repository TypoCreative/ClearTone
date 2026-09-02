import React from "react";
import ReactDOM from "react-dom/client";
import "./globals.css";
import { useEngineSnapshot } from "./hooks/useEngineSnapshot";
import { AppView } from "./views/AppView";

function MainAppRoot() {
  const { snapshot, loading, selectedInput, actionError, dismissActionError } = useEngineSnapshot();

  return (
    <AppView
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
    <MainAppRoot />
  </React.StrictMode>
);
