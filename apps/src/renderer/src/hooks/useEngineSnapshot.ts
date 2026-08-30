import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { createInitialSnapshot, type AudioInputDevice, type EngineSnapshot } from "@contracts";
import { UI_ERROR_EVENT } from "../utils/runEngineAction";

const DEBOUNCE_MS = 100; // Merge rapid snapshot updates within 100ms windows

export function useEngineSnapshot(): {
  snapshot: EngineSnapshot;
  loading: boolean;
  selectedInput: AudioInputDevice | undefined;
  actionError: string | null;
  dismissActionError: () => void;
} {
  const [snapshot, setSnapshot] = useState<EngineSnapshot>(createInitialSnapshot);
  const [loading, setLoading] = useState(true);
  const [actionError, setActionError] = useState<string | null>(null);
  const latestRef = useRef<EngineSnapshot | null>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const mountedRef = useRef(true);

  // Stable debounced setter — avoids React batching every single IPC message
  const flushSnapshot = useCallback(() => {
    if (!mountedRef.current || !latestRef.current) return;
    setSnapshot({ ...latestRef.current });
    latestRef.current = null;
    setLoading(false);
  }, []);

  useEffect(() => {
    mountedRef.current = true;

    void window.clearTone.getStatus()
      .then((nextSnapshot) => {
        if (!mountedRef.current) return;
        latestRef.current = nextSnapshot;
        flushSnapshot();
      })
      .catch((error: unknown) => {
        if (!mountedRef.current) return;
        setLoading(false);
        setActionError(error instanceof Error ? error.message : "Could not connect to ClearTone.");
      });

    const handleUiError = (event: Event) => {
      setActionError((event as CustomEvent<string>).detail);
    };
    window.addEventListener(UI_ERROR_EVENT, handleUiError);

    const unsubscribe = window.clearTone.onSnapshot((nextSnapshot) => {
      if (!mountedRef.current) return;
      latestRef.current = nextSnapshot;

      // Debounce: collapse rapid-fire snapshots into at most one render per DEBOUNCE_MS
      if (timerRef.current) {
        clearTimeout(timerRef.current);
      }
      timerRef.current = setTimeout(() => {
        timerRef.current = null;
        flushSnapshot();
      }, DEBOUNCE_MS);
    });

    return () => {
      mountedRef.current = false;
      unsubscribe();
      window.removeEventListener(UI_ERROR_EVENT, handleUiError);
      if (timerRef.current) {
        clearTimeout(timerRef.current);
        timerRef.current = null;
      }
    };
  }, [flushSnapshot]);

  const selectedInput = useMemo<AudioInputDevice | undefined>(
    () => snapshot.inputs.find((input) => input.id === snapshot.selectedInputId),
    [snapshot.inputs, snapshot.selectedInputId]
  );

  const dismissActionError = useCallback(() => setActionError(null), []);

  return { snapshot, loading, selectedInput, actionError, dismissActionError };
}
