# macOS performance review — 2026-11-17

## Changes

- Allocate RNNoise state on Start rather than application launch; preserve the
  existing two-second idle cleanup.
- Reuse capture work-buffer capacity for alternating callback sizes instead of
  reallocating whenever the length changes. Process only the valid sample count.
- Give each input tap its own converter and scratch buffer, removing the explicit
  per-callback ConverterInputBuffer object and avoiding cross-session sharing.
- Keep the RNNoise model, 48 kHz rate, 480-sample frames, mastering converter quality,
  suppression controls and voice finishing profiles. No lower-quality preset was
  added. Existing ARM NEON kernels remain enabled through the vendored code.
- Keep buffer pools bounded and reject stale metrics/output completion callbacks.

## Measurements and limits

Local host: Apple M1 Pro, macOS 26.6.2, arm64. Release XCTest run:

| Check | Result |
| --- | --- |
| RNNoise inference, 500 frames / 5 seconds of audio | 0.361 s total, 0.721 ms/frame |
| Inference CPU time relative to audio duration | About 7.21% of one core, wall-time estimate |
| Voice finishing, 500 frames | Test completed in about 0.008 s |
| Swift regression tests | 12 passed, Debug and Release |

These are synthetic component measurements, not full-app CPU, memory, end-to-end
latency, battery or M1 Air thermal measurements. They are not before/after speedup
numbers. The improvements reduce known allocation work without replacing DSP.
No percentage CPU/RAM reduction or perceptual quality parity is claimed.

Reproduce with:

```sh
swift test --package-path apps/macos/native/swift-engine --disable-sandbox -c release
```

## M1 Air validation still needed

Use the arm64 Release app on an actual M1 Air (including 8 GB configurations).
Run a 30-minute call with the virtual microphone, compare CPU and resident memory
in Activity Monitor and the app, then repeat in menu-bar-only mode. Check audio
continuity and quality with all three profiles, 44.1/48 kHz USB input, Bluetooth
input, sleep/wake, unplug/replug and rapid start/cancel/stop. Compare recordings
at identical strength and preset; record dropped frames and thermal behavior.
