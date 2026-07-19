# ClearTone web landing page design

## Goal

Create a new `web` folder in the project root containing a single self-contained `index.html` file. The page should present ClearTone as a polished customer- and investor-facing product landing page that explains what the app does, what functions it offers, and how a person would use it.

## Scope

In scope:
- Create `web/index.html`
- Use plain HTML with embedded CSS
- Keep the page single-file and directly openable in a browser
- Present accurate product-facing copy based on current project context
- Use a premium visual style aligned with the product's glassy macOS direction

Out of scope:
- No React, Tailwind build step, or bundler setup
- No multi-page website
- No backend integration
- No analytics, forms, or live download flow
- No screenshots generated from the app unless the user requests them later

## Audience

Primary audience:
- Potential customers
- Early investors or stakeholders

Secondary audience:
- Anyone who needs a quick product overview without reading technical project files

## Content strategy

The page should explain ClearTone in product language, not internal engineering language. Copy should stay grounded in the known project direction:
- ClearTone is a macOS AI microphone app
- It improves voice input quality and usability
- It offers simple control over microphone processing
- It is designed for desktop workflows such as calls, streaming, recording, and everyday communication

The page must avoid unsupported claims such as benchmark numbers, enterprise integrations, or features not established in project context.

## Page structure

### Hero

Purpose:
- Establish product identity quickly
- Communicate the main value in one screen

Content:
- Product name: `ClearTone`
- Short tagline about being an AI microphone for macOS
- Short supporting sentence explaining cleaner, more controlled voice input
- One primary CTA-style button such as `Explore Features`
- One secondary CTA-style button such as `How It Works`

### Product overview

Purpose:
- Explain the product in one short section

Content:
- A concise description of ClearTone as a desktop microphone enhancement experience
- Short emphasis on simplicity, clarity, and quick control

### Key functions

Purpose:
- Show what the app can do in a scannable format

Feature cards should cover:
- AI microphone enhancement
- Quick start and stop control
- Adjustable strength or processing level
- Input device awareness and switching focus
- Lightweight desktop workflow for calls, streaming, and recordings

### How to use

Purpose:
- Make the product feel simple and usable

Use a 3-step flow:
1. Open ClearTone and choose your microphone
2. Start processing and tune the strength
3. Use it during calls, recording, or streaming

### Why it matters

Purpose:
- Translate features into user value

Content themes:
- Better clarity in everyday communication
- Faster setup than more complex audio tooling
- Cleaner workflow on macOS
- Designed for people who want audio improvement without heavy setup

### Final CTA and footer

Purpose:
- End with a confident summary

Content:
- Short closing line reinforcing the product promise
- Compact footer with product name and a brief label such as `Built for macOS`

## Visual design

The page should feel premium, modern, and polished. It should visually relate to the app's established glassy macOS aesthetic without trying to duplicate the application UI exactly.

Design traits:
- Dark theme as the default presentation
- Soft background gradients
- Frosted or glass-like panels using transparency and blur
- Rounded containers and subtle borders
- Spacious typography and generous section spacing
- Clear contrast and readable hierarchy

Typography:
- Prefer modern system-safe or web-safe sans-serif styling that resembles the current product direction
- Large display heading in the hero
- Short, readable supporting paragraphs

Layout:
- Single-column landing page with centered content
- Responsive sections that stack cleanly on smaller widths
- Card grid for features
- Horizontal or stacked step layout for usage flow depending on viewport size

## File structure

Final deliverable:
- `web/index.html`

No additional required files unless a later design revision adds images or assets.

## Technical approach

Implementation should use:
- Semantic HTML sections
- Embedded `<style>` block for all styling
- Minimal or no JavaScript

JavaScript is optional and should only be used for minor enhancements such as smooth anchor scrolling or button interactions. The page must remain fully understandable without JavaScript.

## Content and interaction behavior

Expected interactions:
- Navigation by scrolling through the single page
- CTA buttons can link to section anchors inside the same document

The page does not need:
- Form submission
- Modal windows
- Dynamic data loading
- External API calls

## Error handling

Since this is a static page, error handling is mostly about resilience:
- The page should render correctly without external dependencies
- Fonts should fall back to local sans-serif stacks
- Buttons and anchors should still work without script
- The layout should remain readable on narrower screens

## Verification

The implementation will be considered correct if:
- A `web` folder exists at the project root
- `web/index.html` opens directly in a browser
- The page includes sections for hero, overview, features, usage, value, and CTA
- The copy reflects ClearTone accurately and avoids unsupported feature claims
- The layout looks polished and readable on desktop width and narrow width

## Risks and mitigations

Risk:
- The copy may drift into marketing claims beyond current project reality

Mitigation:
- Keep wording high-level and consistent with the known app scope

Risk:
- A single-file page can become visually heavy if over-designed

Mitigation:
- Prefer restrained premium styling over animation-heavy presentation

## Recommendation

Proceed with a single self-contained `web/index.html` product landing page using a dark glassy aesthetic, concise product-facing copy, and a clear section-based structure. This approach matches the user's request, fits the existing project identity, and avoids unnecessary setup.
