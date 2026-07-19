import React from "react";
import ReactDOM from "react-dom/client";
import "@fontsource/inter/latin-400.css";
import "@fontsource/inter/latin-500.css";
import "@fontsource/inter/latin-600.css";
import "@fontsource/inter/latin-700.css";
import "./globals.css";
import { useEngineSnapshot } from "./hooks/useEngineSnapshot";
import { AppView } from "./views/AppView";

function MainAppRoot() {
  const { snapshot, loading, selectedInput } = useEngineSnapshot();

  return <AppView snapshot={snapshot} loading={loading} selectedInput={selectedInput} />;
}

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    <MainAppRoot />
  </React.StrictMode>
);
