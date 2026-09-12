# Tasks

## Complete

- [x] Move platform code under `apps/macos` and `apps/windows`.
- [x] Update macOS scripts, package aliases, and workflow paths.
- [x] Preserve the existing macOS icon and reuse its artwork for Windows.
- [x] Add native Windows Win32 UI and tray lifecycle.
- [x] Add WASAPI capture/render with 48 kHz mono conversion.
- [x] Compile and run RNNoise on 480-sample Windows frames.
- [x] Add Windows status, strength, and compact live metrics.
- [x] Add lightweight Windows CPU/private-memory metrics without a helper process.
- [x] Add a Windows playback-device picker for virtual-cable routing.
- [x] Keep Windows quality builds unsigned and sign Windows release artifacts.
- [x] Upload Windows ZIP directly to GitHub Releases without `upload-artifact`.
- [x] Use `npm run build` as the single signed build command for macOS and Windows.
- [x] Synchronize README and product-plan documentation.

## Physical-platform validation

- [ ] Confirm the Windows build on GitHub Actions and a Windows 10 machine.
- [ ] Confirm Windows 11 Mica, tray scaling, keyboard navigation, and screen reader.
- [ ] Test default-device changes, unplug/replug, sleep/wake, and one-hour processing.
- [ ] Compare Windows RNNoise output with macOS reference recordings.
- [ ] Validate macOS Core Audio integration outside the restricted sandbox.

## Deliberately excluded

- [ ] Provide the private Windows application certificate through CI secrets.
- [ ] Windows WDK virtual-microphone driver and Microsoft driver signing.
