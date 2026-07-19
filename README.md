# ClearTone

Professional AI microphone for macOS.

## Open ClearTone If macOS Blocks It

If macOS shows a warning that `ClearTone.app` cannot be opened because it is from an unidentified developer, use one of the options below.

### Option A: Open Anyway From System Settings

Use this if you already tried to open the app once and macOS blocked it.

1. Open `System Settings`.
2. Go to `Privacy & Security`.
3. Scroll down until you find the message that `ClearTone` was blocked.
4. Click `Open Anyway`.
5. Confirm again if macOS asks for permission.

### Option B: Remove Quarantine From Terminal

Use this if the app was copied to the `Applications` folder and you want to remove the quarantine attribute manually.

```bash
sudo xattr -dr com.apple.quarantine /Applications/ClearTone.app
```

After that, try opening `ClearTone.app` again.

## Notes

- These steps are usually needed for unsigned or not-yet-notarized macOS builds.
- Make sure the app path matches your installation location before running the Terminal command.
