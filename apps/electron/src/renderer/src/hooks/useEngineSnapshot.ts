import { useEffect, useMemo, useState } from "react";
import { createInitialSnapshot, type AudioInputDevice, type EngineSnapshot } from "@contracts";

export function useEngineSnapshot(): {
  snapshot: EngineSnapshot;
  loading: boolean;
  selectedInput: AudioInputDevice | undefined;
} {
  const [snapshot, setSnapshot] = useState<EngineSnapshot>(createInitialSnapshot);
  const [loading, setLoading] = useState(true);

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

  return { snapshot, loading, selectedInput };
}

