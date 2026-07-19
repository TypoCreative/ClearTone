import { Suspense, lazy } from "react";
import { useEngineSnapshot } from "./hooks/useEngineSnapshot";

const AppView = lazy(async () => {
  const module = await import("./views/AppView");
  return { default: module.AppView };
});

const TrayView = lazy(async () => {
  const module = await import("./views/TrayView");
  return { default: module.TrayView };
});

function App() {
  const isTrayPopup = window.location.hash === "#tray-popup";
  const { snapshot, loading, selectedInput } = useEngineSnapshot();

  return (
    <Suspense fallback={<div className="min-h-full bg-background" />}>
      {isTrayPopup ? (
        <TrayView snapshot={snapshot} loading={loading} selectedInput={selectedInput} />
      ) : (
        <AppView snapshot={snapshot} loading={loading} selectedInput={selectedInput} />
      )}
    </Suspense>
  );
}

export default App;
