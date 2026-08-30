import { describe, expect, it } from "vitest";
import { createInitialSnapshot } from "@contracts";
import { deriveControlState, formatLatency, formatPercent } from "./engineUi";

describe("engine UI formatting", () => {
  it("formats percentages and latency with units", () => {
    expect(formatPercent(0.5)).toContain("50");
    expect(formatLatency(12.25)).toContain("ms");
  });
});

describe("deriveControlState", () => {
  it("prevents start until an input is available", () => {
    expect(deriveControlState(createInitialSnapshot()).canStart).toBe(false);
  });

  it("allows stop while processing", () => {
    const snapshot = createInitialSnapshot();
    snapshot.phase = "processing";
    expect(deriveControlState(snapshot).canStop).toBe(true);
  });
});
