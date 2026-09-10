# Design System

ClearTone uses native SwiftUI and AppKit components with macOS materials. There is
no web renderer, CSS framework, shadcn, Tailwind, or custom font dependency.

## Visual language

- The background uses the system window color with restrained blue and cyan
  gradients.
- Cards use `ultraThinMaterial`, 22 pt corner radii, one-pixel highlights, and soft
  shadows to create an Apple-style glass hierarchy.
- Blue indicates controls and the selected Voice Engine node. Green indicates
  active processing or virtual routing. Red is reserved for stopping and errors;
  orange represents transitions.
- Typography uses the macOS system font. Rounded system faces and monospaced digits
  are limited to headings and measurements where they improve scanning.
- The existing `ClearTone.icns` remains the app icon. The menu-bar item uses a
  monochrome SF Symbol at 16 pt within an 18 × 18 pt frame.

## Dashboard hierarchy

The desktop window is a scrollable two-column grid with four primary cards:

1. Voice Engine: status, explanation, and the primary Start/Stop action.
2. Audio Routing: Input → Voice Engine → Output plus Virtual Microphone.
3. Audio Setup: input picker, suppression slider, and voice-profile control.
4. System Health: compact audio and process metrics.

The decorative waveform previously shown at the right of Voice Engine is removed
so the primary action and routing state carry the visual hierarchy.

## Menu-bar interface

The 380 pt menu-bar popup keeps the same interaction model in a compact layout. It
includes Start/Stop, Audio Setup, the routing grid, Virtual Microphone, metrics,
Tray Only, Open Window when applicable, and Quit.

## Accessibility

- Native controls preserve keyboard and VoiceOver behavior.
- Decorative icons and backgrounds are hidden from accessibility.
- Routing nodes expose combined labels containing their role and current state.
- Transitioning Start/Stop controls are disabled and explain why through an
  accessibility hint.
- Error banners expose readable text and an explicit dismiss action.
