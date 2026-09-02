import { describe, expect, it } from "vitest";
import { createInitialSnapshot, normalizeStrength } from "./index";

describe("normalizeStrength", () => {
  it("clamps values to the supported range", () => {
    expect(normalizeStrength(-1)).toBe(0);
    expect(normalizeStrength(0.42)).toBe(0.42);
    expect(normalizeStrength(2)).toBe(1);
  });

  it("uses the safe default for non-finite values", () => {
    expect(normalizeStrength(Number.NaN)).toBe(0.65);
    expect(normalizeStrength(Number.POSITIVE_INFINITY)).toBe(0.65);
  });
});

describe("createInitialSnapshot", () => {
  it("starts with virtual routing disabled and empty health metrics", () => {
    const snapshot = createInitialSnapshot();
    expect(snapshot.virtualMicrophone.enabled).toBe(false);
    expect(snapshot.virtualMicrophone.available).toBe(false);
    expect(snapshot.metrics.droppedFrames).toBe(0);
    expect(snapshot.metrics.outputQueueFrames).toBe(0);
    expect(snapshot.voicePreset).toBe("clear");
  });
});
