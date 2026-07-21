# Project Context — ClearTone

## Environment
- Swift 6.2 + TypeScript/React 19 + Electron 43
- macOS 13+, SPM + npm workspaces monorepo

## Current Status: Performance Fix Mission

### Completed Performance Fixes:
1. **GPU re-enabled** — Removed `disable-gpu` + `disableHardwareAcceleration()` from main/index.ts
2. **Snapshot debouncing** — useEngineSnapshot hook now debounces at 100ms
3. **Window-aware IPC** — pushSnapshot only sends to visible windows
4. **React.memo on all components** — AppView, TrayView, MetricsGrid, StatusBadge, StartStopControls, StrengthSlider, DeviceSelect, AppDeviceSelect, TrayDeviceSelect
5. **useMemo for derived values** — deriveControlState and metrics arrays
6. **Removed unnecessary React.lazy** — App.tsx now direct imports
7. **StrengthSlider optimized** — Removed redundant internal state (was double-rendering)
8. **All handlers memoized** — useCallback on every event handler

### Files Modified:
- `apps/src/main/index.ts` — GPU flags removed, visible-window-aware pushSnapshot
- `apps/src/renderer/src/App.tsx` — removed lazy/Suspense
- `apps/src/renderer/src/hooks/useEngineSnapshot.ts` — debounced snapshot updates
- `apps/src/renderer/src/views/AppView.tsx` — memo + useMemo
- `apps/src/renderer/src/views/TrayView.tsx` — memo + useMemo + useCallback
- `apps/src/renderer/src/components/MetricsGrid.tsx` — memo + useMemo
- `apps/src/renderer/src/components/StrengthSlider.tsx` — memo + removed state sync
- `apps/src/renderer/src/components/StartStopControls.tsx` — memo + useCallback
- `apps/src/renderer/src/components/DeviceSelect.tsx` — memo + useCallback
- `apps/src/renderer/src/components/AppDeviceSelect.tsx` — memo + useCallback
- `apps/src/renderer/src/components/TrayDeviceSelect.tsx` — memo + useCallback

### Verification:
- TypeScript compiles clean (no errors)
- LSP diagnostics clean
- Swift engine builds clean

### Pending:
- [ ] Build Electron app and run `npm run dev` to verify runtime
