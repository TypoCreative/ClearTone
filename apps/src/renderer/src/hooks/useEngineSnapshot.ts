import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { createInitialSnapshot, type AudioInputDevice, type EngineSnapshot } from "@contracts";

const DEBOUNCE_MS = 100; // Merge rapid snapshot updates within 100ms windows

export function useEngineSnapshot(): {
  snapshot: EngineSnapshot;
  loading: boolean;
  selectedInput: AudioInputDevice | undefined;
} {
  const [snapshot, setSnapshot] = useState<EngineSnapshot>(createInitialSnapshot);
  const [loading, setLoading] = useState(true);
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

    void window.clearTone.getStatus().then((nextSnapshot) => {
      if (!mountedRef.current) return;
      latestRef.current = nextSnapshot;
      flushSnapshot();
    });

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

  return { snapshot, loading, selectedInput };
}
