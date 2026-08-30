import { useEngineSnapshot } from "./hooks/useEngineSnapshot";
import { AppView } from "./views/AppView";
import { TrayView } from "./views/TrayView";

function App() {
  const isTrayPopup = window.location.hash === "#tray-popup";
  const { snapshot, loading, selectedInput, actionError, dismissActionError } = useEngineSnapshot();

  if (isTrayPopup) {
    return <TrayView snapshot={snapshot} loading={loading} selectedInput={selectedInput} actionError={actionError} dismissActionError={dismissActionError} />;
  }

  return <AppView snapshot={snapshot} loading={loading} selectedInput={selectedInput} actionError={actionError} dismissActionError={dismissActionError} />;
}

export default App;
