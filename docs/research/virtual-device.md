# Virtual Microphone Device

## Overview

A virtual microphone device appears as a selectable input in macOS, allowing any app (Zoom, Discord, OBS) to use ClearTone's denoised output as their microphone source.

## Status: Non-Goal for V1

The V1 spec explicitly lists virtual microphone routing as a non-goal:
> "Shipping virtual microphone routing in v1" — V1 Design Spec

## Approaches

### 1. Core Audio Aggregate Device
Create a virtual aggregate device that exposes the processed audio as an input.

### 2. AudioDriverKit (macOS 11+)
Apple's modern driver framework for creating virtual audio devices. Requires:
- DriverKit entitlement
- System Extension (requires notarization)
- C++ implementation

### 3. Core Audio Server Plugin (Legacy)
The traditional approach (deprecated but still works):
- Install a `.driver` bundle in `/Library/Audio/Plug-Ins/HAL/`
- Requires admin privileges for installation
- No notarization needed for the plugin itself

### 4. Soundflower / BlackHole Pattern
Open-source virtual audio drivers as reference:
- [BlackHole](https://github.com/ExistentialAudio/BlackHole) — modern, AudioDriverKit
- [Soundflower](https://github.com/mattingalls/Soundflower) — legacy, widely used

### 5. Loopback (Commercial)
[Rogue Amoeba's Loopback](https://rogueameoba.com/loopback/) is a polished commercial virtual audio router. ClearTone could potentially route through it.

## V1 Workaround

Without a virtual mic, users can still test ClearTone:
1. The denoised audio plays through the speaker/headphones (monitoring)
2. Users hear the effect in real-time
3. Next step: route to a virtual mic for app integration

## Recommendation

Build V1 without virtual mic, but architect the `AudioEngineController` so that:
- The output sink is pluggable (currently: monitor output, later: virtual mic)
- After V1 is stable, implement the cheapest viable virtual mic (likely BlackHole integration or a minimal AudioDriverKit extension)

## References

- BlackHole: https://github.com/ExistentialAudio/BlackHole
- AudioDriverKit: https://developer.apple.com/documentation/audiodriverkit
- Creating aggregate devices: https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioUnitHostingGuide/AudioUnitHostingFundamentals/AudioUnitHostingFundamentals.html
