---
name: Shadcn
foundation: "shadcn/ui"
themes: ["light", "dark"]
brandColors:
  primary: "#3B82F6"
  accent: "#8B5CF6"
  success: "#16A34A"
  warning: "#D97706"
  destructive: "#DC2626"
typography:
  sans: "Inter"
  mono: "ui-monospace"
  scale: "12/14/16/18/20/24/30"
  weights: "400, 500, 600, 700"
rounded:
  radius: 8px
spacing:
  sourceScale: "Tailwind default (4/8/12/16/24/32)"
---

## Overview

ClearTone uses a shadcn/ui-driven design system: Tailwind utilities + CSS variable tokens + accessible component primitives. The UI prioritizes clarity and scanability for a small utility dashboard and tray mini-popup.

## Foundations

- **Design system:** shadcn/ui conventions (Radix primitives + Tailwind + tokenized CSS variables)
- **Themes:** light + dark (theme is applied by a `.dark` class on the root element)
- **Typography goal:** modern, easy-to-read UI type with clear hierarchy for compact windows
- **Layout goal:** two-row utility dashboard + tray mini-popup, optimized for quick interactions

## Typography

Primary font is Inter with a robust system fallback. Monospace is used for metrics/values when alignment improves readability.

- **Sans stack:** `Inter, ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, Helvetica, Arial, "Apple Color Emoji", "Segoe UI Emoji"`
- **Mono stack:** `ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace`

Recommended type roles:

- **Display / Title:** 24–30px, weight 600–700
- **Section heading:** 16–18px, weight 600
- **Body:** 14–16px, weight 400–500
- **Label:** 12px, weight 500–600
- **Metric value:** 14–18px, mono, weight 500–600

## Color Tokens (shadcn style)

ClearTone uses shadcn-style semantic tokens (not raw hex in components). Tailwind should reference colors through `hsl(var(--token))`.

Brand palette anchors:

- **Primary:** `#3B82F6` (HSL ≈ `217 91% 60%`)
- **Accent:** `#8B5CF6` (HSL ≈ `258 90% 66%`)
- **Success:** `#16A34A` (HSL ≈ `142 76% 36%`)
- **Warning:** `#D97706` (HSL ≈ `33 95% 44%`)
- **Destructive:** `#DC2626` (HSL ≈ `0 72% 51%`)

Baseline tokens (reference template):

```css
:root {
  --background: 0 0% 100%;
  --foreground: 222 39% 11%;

  --card: 0 0% 100%;
  --card-foreground: 222 39% 11%;

  --popover: 0 0% 100%;
  --popover-foreground: 222 39% 11%;

  --primary: 217 91% 60%;
  --primary-foreground: 0 0% 100%;

  --secondary: 258 90% 66%;
  --secondary-foreground: 0 0% 100%;

  --muted: 210 40% 96%;
  --muted-foreground: 215 16% 47%;

  --accent: 258 90% 66%;
  --accent-foreground: 0 0% 100%;

  --destructive: 0 72% 51%;
  --destructive-foreground: 0 0% 100%;

  --border: 214 32% 91%;
  --input: 214 32% 91%;
  --ring: 217 91% 60%;

  --radius: 0.5rem;
}

.dark {
  --background: 222 47% 11%;
  --foreground: 210 40% 98%;

  --card: 222 47% 14%;
  --card-foreground: 210 40% 98%;

  --popover: 222 47% 14%;
  --popover-foreground: 210 40% 98%;

  --primary: 217 91% 60%;
  --primary-foreground: 222 47% 11%;

  --secondary: 258 90% 66%;
  --secondary-foreground: 222 47% 11%;

  --muted: 217 33% 18%;
  --muted-foreground: 215 20% 65%;

  --accent: 258 90% 66%;
  --accent-foreground: 222 47% 11%;

  --destructive: 0 72% 51%;
  --destructive-foreground: 210 40% 98%;

  --border: 217 33% 18%;
  --input: 217 33% 18%;
  --ring: 217 91% 60%;
}
```

## Radius, Spacing, Elevation

- **Radius:** `--radius = 8px` (0.5rem). Derive smaller/larger radii from this when needed.
- **Spacing:** Tailwind scale is the source of truth; avoid custom spacing tokens unless required.
- **Elevation:** prefer subtle `border` + `shadow-sm` over heavy shadows (especially in the tray popup).

## Components (shadcn/ui targets)

These are the intended shadcn component building blocks for the renderer UI:

- Button (primary, secondary, ghost, destructive)
- Card (for grouped blocks: device, strength, metrics)
- Slider (strength)
- Select (audio input device)
- Switch (optional toggles)
- Tooltip (explaining metrics)
- Separator (row divisions)
- Badge (engine status)
- Progress (optional for activity/levels)

## Layout Rules

- **Top row (controls):** Start/Stop on the left; Device + Strength on the right
- **Bottom row (metrics):** compact, aligned values; use mono for numeric readability
- **Window sizes:** ensure controls remain usable in tray popup dimensions (short labels, clear hit targets)

## Accessibility & Interaction

- **Focus:** use focus-visible ring (`--ring`) and keep it clearly visible on both themes
- **Hit targets:** minimum 32px; prefer 40px where space allows
- **Contrast:** keep foreground/background contrast high for quick scanning
- **Motion:** keep transitions subtle; respect reduced-motion preferences when implemented

- **Primary (#3B82F6):** Token from style foundations.
- **Secondary (#8B5CF6):** Token from style foundations.
- **Success (#16A34A):** Token from style foundations.
- **Warning (#D97706):** Token from style foundations.
- **Danger (#DC2626):** Token from style foundations.
- **Surface (#FFFFFF):** Token from style foundations.
- **Text (#111827):** Token from style foundations.
- **Neutral (#FFFFFF):** Derived from the surface token for official format compatibility.
