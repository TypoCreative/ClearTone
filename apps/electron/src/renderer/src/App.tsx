import { useEngineSnapshot } from "./hooks/useEngineSnapshot";
import { AppView } from "./views/AppView";
import { TrayView } from "./views/TrayView";

function App() {
  const isTrayPopup = window.location.hash === "#tray-popup";
  const { snapshot, loading, selectedInput } = useEngineSnapshot();

  return isTrayPopup ? (
    <TrayView snapshot={snapshot} loading={loading} selectedInput={selectedInput} />
  ) : (
    <AppView snapshot={snapshot} loading={loading} selectedInput={selectedInput} />
  );
}

export default App;
