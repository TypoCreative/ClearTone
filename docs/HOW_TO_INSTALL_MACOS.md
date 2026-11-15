# How to install ClearTone on macOS

Download the DMG from https://github.com/TypoCreative/ClearTone/releases/latest:
choose **arm64** for Apple silicon (M1/M2/M3/M4 or newer) or **x64** for Intel.
This build is **not notarized by Apple**, so macOS may require manual approval.
Only approve a ClearTone download you trust from this repository.

1. Open `ClearTone-0.3.1-mac-<arch>.dmg`.
2. Drag **ClearTone.app** to **Applications**.
3. Eject the DMG, then open **ClearTone** from Applications.
4. If macOS blocks it, use either method below.

## Option A — Privacy & Security

1. Try opening ClearTone once. On the warning, choose **Done**, not Move to Trash.
2. Open **System Settings → Privacy & Security**.
3. Scroll to the ClearTone security notice and choose **Open Anyway**.
4. Authenticate if asked, then choose **Open**.

To open the settings pane from Terminal:

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy"
```

If the DMG itself is blocked, use the same Open Anyway steps for that DMG first.
Apple's instructions: https://support.apple.com/en-us/102445

## Option B — Terminal quarantine cleanup

After copying ClearTone to Applications, run:

```bash
codesign --verify --deep --strict "/Applications/ClearTone.app"
sudo xattr -dr com.apple.quarantine "/Applications/ClearTone.app"
open "/Applications/ClearTone.app"
```

Run the cleanup only if signature verification succeeds. `sudo` asks for your Mac
login password; no characters appear while typing. These commands remove only the
quarantine attribute from ClearTone, including its bundled driver installer.
They do not disable Gatekeeper globally or notarize the app.

If you cannot open the DMG at all, remove quarantine from that exact download
first, then open it. Example for Apple silicon in the default Downloads folder:

```bash
xattr -d com.apple.quarantine "$HOME/Downloads/ClearTone-0.3.1-mac-arm64.dmg"
open "$HOME/Downloads/ClearTone-0.3.1-mac-arm64.dmg"
```

Use `mac-x64.dmg` for Intel and adjust the path if your download is elsewhere.
“No such xattr” means that file already has no quarantine attribute.

## Microphone and virtual driver

Allow microphone access when prompted. In ClearTone, choose **Install Driver**
if the virtual microphone is unavailable, and follow the driver installer prompts.
If the bundled driver installer is blocked, approve that specific installer in
Privacy & Security, or use Option B on the installed app and retry Install Driver.
Restart or log out if ClearTone asks, then select **ClearTone Virtual Microphone**
in your meeting or recording app.
