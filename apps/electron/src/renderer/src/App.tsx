import { useEffect, useMemo, useState } from "react";
import {
  createInitialSnapshot,
  type AudioInputDevice,
  type EnginePhase,
  type EngineSnapshot
} from "@contracts";

const phaseLabels: Record<EnginePhase, string> = {
  booting: "Booting",
  idle: "Ready",
  starting: "Starting",
  processing: "Live",
  stopping: "Stopping",
  error: "Needs Attention"
};

function formatPercent(value: number): string {
  return `${Math.round(value * 100)}%`;
}

function formatLevel(value: number): string {
  return `${Math.round(value * 100)}%`;
}

function formatLatency(value: number): string {
  return `${value.toFixed(1)} ms`;
}

function formatDeviceMode(snapshot: EngineSnapshot, selectedInput?: AudioInputDevice): string {
  if (snapshot.followSystemInput) {
    return selectedInput ? `Following ${selectedInput.name}` : "Following system input";
  }

  return selectedInput ? `Locked to ${selectedInput.name}` : "Manual device mode";
}

function App() {
  const [snapshot, setSnapshot] = useState<EngineSnapshot>(createInitialSnapshot);
  const [loading, setLoading] = useState(true);
  const isTrayPopup = window.location.hash === "#tray-popup";

  useEffect(() => {
    let mounted = true;

    void window.clearTone.getStatus().then((nextSnapshot) => {
      if (mounted) {
        setSnapshot(nextSnapshot);
        setLoading(false);
      }
    });

    const unsubscribe = window.clearTone.onSnapshot((nextSnapshot) => {
      if (mounted) {
        setSnapshot(nextSnapshot);
        setLoading(false);
      }
    });

    return () => {
      mounted = false;
      unsubscribe();
    };
  }, []);

  const selectedInput = useMemo<AudioInputDevice | undefined>(
    () => snapshot.inputs.find((input) => input.id === snapshot.selectedInputId),
    [snapshot.inputs, snapshot.selectedInputId]
  );

  const canStart =
    snapshot.phase !== "starting" &&
    snapshot.phase !== "processing" &&
    snapshot.inputs.length > 0 &&
    snapshot.permission !== "denied" &&
    snapshot.permission !== "restricted";

  const canStop = snapshot.phase === "starting" || snapshot.phase === "processing";
  const inputControlValue = snapshot.followSystemInput
    ? "__follow_system__"
    : (snapshot.selectedInputId ?? "");

  const handleInputChange = (value: string) => {
    if (value === "__follow_system__") {
      void window.clearTone.followSystemInput();
      return;
    }

    void window.clearTone.selectInput(value);
  };

  const metrics = [
    {
      label: "Status",
      value: loading ? "Connecting" : phaseLabels[snapshot.phase]
    },
    {
      label: "Permission",
      value: snapshot.permission
    },
    {
      label: "Frames",
      value: snapshot.metrics.framesProcessed.toLocaleString()
    },
    {
      label: "Input Level",
      value: formatLevel(snapshot.metrics.inputLevel)
    },
    {
      label: "Latency",
      value: formatLatency(snapshot.metrics.estimatedLatencyMs)
    }
  ];

  const controlPanel = (
    <>
      <div className="action-column">
        <button
          className="primary-button"
          disabled={!canStart}
          onClick={() => void window.clearTone.startProcessing()}
        >
          Start
        </button>
        <button
          className="secondary-button"
          disabled={!canStop}
          onClick={() => void window.clearTone.stopProcessing()}
        >
          Stop
        </button>
      </div>

      <div className="settings-column">
        <label className="field">
          <span>Select Device</span>
          <select
            value={inputControlValue}
            onChange={(event) => handleInputChange(event.target.value)}
            disabled={snapshot.inputs.length === 0}
          >
            <option value="__follow_system__">Follow system input</option>
            {snapshot.inputs.map((input) => (
              <option key={input.id} value={input.id}>
                {input.name}
                {input.isDefault ? " (System)" : ""}
              </option>
            ))}
          </select>
          <small className="field-note">
            {formatDeviceMode(snapshot, selectedInput)}
          </small>
        </label>

        <label className="field">
          <span>Denoise Strength</span>
          <div className="slider-row">
            <input
              type="range"
              min="0"
              max="1"
              step="0.01"
              value={snapshot.strength}
              onChange={(event) =>
                void window.clearTone.setStrength(Number(event.target.value))
              }
            />
            <strong>{formatPercent(snapshot.strength)}</strong>
          </div>
        </label>
      </div>
    </>
  );

  return (
    <main className={`app-shell ${isTrayPopup ? "tray-popup-shell" : ""}`}>
      <section className={`top-summary phase-${snapshot.phase}`}>
        <div>
          <p className="summary-label">{isTrayPopup ? "Quick Controls" : "Simple Voice Cleaner"}</p>
          <h1>{isTrayPopup ? "ClearTone Mini" : "ClearTone"}</h1>
          <p className="summary-copy">{snapshot.statusMessage}</p>
        </div>
        {!isTrayPopup ? (
          <div className="summary-side">
            <strong>{loading ? "Connecting" : phaseLabels[snapshot.phase]}</strong>
            <span>{selectedInput?.name ?? "No microphone selected"}</span>
          </div>
        ) : null}
      </section>

      <section className={`control-row ${isTrayPopup ? "tray-control-row" : ""}`}>
        {controlPanel}
      </section>

      {snapshot.lastError ? (
        <section className="error-card">
          <p className="error-title">Engine Error</p>
          <p>{snapshot.lastError}</p>
        </section>
      ) : null}

      {isTrayPopup ? (
        <section className="mini-status-row">
          <div className="mini-status-card">
            <span>Status</span>
            <strong>{loading ? "Connecting" : phaseLabels[snapshot.phase]}</strong>
          </div>
          <div className="mini-status-card">
            <span>Current Input</span>
            <strong>{selectedInput?.name ?? "None"}</strong>
          </div>
        </section>
      ) : (
        <section className="metrics-row">
          {metrics.map((metric) => (
            <article key={metric.label} className="metric-card">
              <span>{metric.label}</span>
              <strong>{metric.value}</strong>
            </article>
          ))}
        </section>
      )}
    </main>
  );
}

export default App;
