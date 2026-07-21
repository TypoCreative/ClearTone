# Mission: Fix App Performance (Lagging & Heavy)

## M1: Critical Performance Fixes | status: completed

### T1.1: GPU/Hardware Acceleration | agent:Commander
- [x] S1.1.1: Remove disable-gpu and disableHardwareAcceleration from main process
- [x] S1.1.2: Keep no-sandbox (required for native subprocess)

### T1.2: Render Loop Optimization | agent:Commander
- [x] S1.2.1: Add debouncing (100ms) to snapshot updates in useEngineSnapshot hook
- [x] S1.2.2: Memoize AppView, TrayView, StatusBadge with React.memo
- [x] S1.2.3: Memoize MetricsGrid with React.memo + useMemo for metrics array

### T1.3: Reduce Unnecessary Work | agent:Commander
- [x] S1.3.1: Only push snapshots to visible windows in main process
- [x] S1.3.2: Memoize deriveControlState with useMemo
- [x] S1.3.3: Remove React.lazy/Suspense from App.tsx
- [x] S1.3.4: Optimize StrengthSlider — remove redundant internal state, use controlled component
- [x] S1.3.5: Memoize StartStopControls, DeviceSelect, AppDeviceSelect, TrayDeviceSelect

### T1.4: Verification | status: completed
- [x] S1.4.1: TypeScript compiles clean (no errors)
- [x] S1.4.2: LSP diagnostics clean
