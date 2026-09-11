# Windows virtual microphone boundary

ClearTone 0.3.0 intentionally does not ship a Windows kernel driver. A custom
virtual capture endpoint requires a WDK/AVStream driver and a Microsoft-approved
production signing path. Omitting signing does not make that requirement disappear
for normal end users; it only makes test-mode driver development possible.

The current Windows app therefore sends cleaned audio to the selected/default
WASAPI playback endpoint. To expose that stream as an input in Zoom, Teams, OBS,
Discord, or another app, use an already-installed virtual audio cable as the
playback endpoint and select its paired microphone endpoint in the destination.

No certificate, driver package, silent installer, or signing secret is included in
this repository or requested by the Windows workflows.
