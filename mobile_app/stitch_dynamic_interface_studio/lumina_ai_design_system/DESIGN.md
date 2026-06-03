---
name: Lumina AI Design System
colors:
  surface: '#0b1326'
  surface-dim: '#0b1326'
  surface-bright: '#31394d'
  surface-container-lowest: '#060e20'
  surface-container-low: '#131b2e'
  surface-container: '#171f33'
  surface-container-high: '#222a3d'
  surface-container-highest: '#2d3449'
  on-surface: '#dae2fd'
  on-surface-variant: '#cbc3d7'
  inverse-surface: '#dae2fd'
  inverse-on-surface: '#283044'
  outline: '#958ea0'
  outline-variant: '#494454'
  surface-tint: '#d0bcff'
  primary: '#d0bcff'
  on-primary: '#3c0091'
  primary-container: '#a078ff'
  on-primary-container: '#340080'
  inverse-primary: '#6d3bd7'
  secondary: '#c0c1ff'
  on-secondary: '#1000a9'
  secondary-container: '#3131c0'
  on-secondary-container: '#b0b2ff'
  tertiary: '#2fd9f4'
  on-tertiary: '#00363e'
  tertiary-container: '#009fb4'
  on-tertiary-container: '#002f36'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e9ddff'
  primary-fixed-dim: '#d0bcff'
  on-primary-fixed: '#23005c'
  on-primary-fixed-variant: '#5516be'
  secondary-fixed: '#e1e0ff'
  secondary-fixed-dim: '#c0c1ff'
  on-secondary-fixed: '#07006c'
  on-secondary-fixed-variant: '#2f2ebe'
  tertiary-fixed: '#a2eeff'
  tertiary-fixed-dim: '#2fd9f4'
  on-tertiary-fixed: '#001f25'
  on-tertiary-fixed-variant: '#004e5a'
  background: '#0b1326'
  on-background: '#dae2fd'
  surface-variant: '#2d3449'
typography:
  display-lg:
    fontFamily: Hanken Grotesk
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Hanken Grotesk
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Hanken Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-sm:
    fontFamily: Hanken Grotesk
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 8px
  gutter: 16px
  margin-mobile: 20px
  margin-desktop: 40px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 32px
---

## Brand & Style

The design system is built for a forward-thinking educational environment where technology and security meet. The brand personality is **intelligent, reliable, and frictionless**, aiming to evoke a sense of high-tech efficiency in school administrators and students alike.

The visual style is a fusion of **Corporate Modern** and **Glassmorphism**, utilizing deep obsidian surfaces punctuated by vibrant violet light sources. This "Dynamic Dark" aesthetic creates a high-contrast environment that feels futuristic while remaining highly accessible. We utilize subtle gradients and soft glows to simulate an AI presence that is helpful rather than intimidating.

## Colors

The palette is rooted in a deep, nocturnal base to allow the AI-driven elements to pop.

*   **Primary (Vivid Violet):** Used for primary actions, success states, and the AI "pulse." It signifies intelligence and innovation.
*   **Secondary (Electric Indigo):** Used for navigation elements and secondary interactive states.
*   **Tertiary (Cyber Cyan):** Reserved for technical data points, scanning indicators, and highlights that suggest "active processing."
*   **Neutral (Space Obsidian):** A range of deep blues and purples used for surfaces to maintain high contrast without the harshness of pure black.

All interactive elements must maintain a minimum contrast ratio of 4.5:1 against the background to ensure accessibility for all users within the school environment.

## Typography

This design system utilizes **Hanken Grotesk** across all interfaces. It is a highly legible, contemporary sans-serif that balances a technical feel with approachable geometry.

*   **Scale:** We use a tight typographic scale to maintain professional density.
*   **Weight:** Headlines use SemiBold (600) or Bold (700) to anchor the page, while body text remains at Regular (400) for maximum readability during long scanning tasks.
*   **High-Tech Accents:** For AI-specific data (like timestamps or confidence scores), use the Label-sm style with uppercase transformed text and increased letter spacing to differentiate "machine-read" data from "human-read" content.

## Layout & Spacing

The layout follows an **8px grid system**, ensuring vertical rhythm and consistent alignment across complex dashboards.

*   **Grid Model:** A 12-column fluid grid for desktop and a 4-column fluid grid for mobile.
*   **Container Strategy:** Use a fixed-width centered container on desktop (max-width 1200px) to prevent data spanning too wide for comfortable eye-tracking.
*   **Dynamic Padding:** Components like cards and list items use 16px (stack-md) internal padding for a spacious, modern feel.

## Elevation & Depth

Hierarchy is established through **Tonal Layering** and **Aura Shadows**.

1.  **Base Layer:** The darkest shade (#0F172A), used for the application background.
2.  **Surface Layer:** A slightly lighter obsidian (#1E293B) used for cards and containers, featuring a 1px subtle border (#334155).
3.  **Active Layer (AI Pulse):** High-importance elements (like the "Mark Attendance" button) utilize an outer glow rather than a traditional shadow. This glow uses the Primary Violet color at 20% opacity with a 20px blur radius to simulate a light-emitting surface.
4.  **Glassmorphism:** Overlays and modals should use a backdrop blur (12px) with a semi-transparent background (White at 5%) to maintain context of the screen behind them.

## Shapes

The shape language is characterized by **generous, soft corners** to offset the "coldness" of the dark tech aesthetic.

*   **Standard Components:** Buttons, inputs, and small cards use a 0.5rem (8px) radius.
*   **Large Containers:** Dashboard cards and modal windows use a "2xl" style, defined here as 1.5rem (24px) for a soft, friendly silhouette.
*   **Selection Indicators:** Active states in navigation or list items use pill-shaped (full-round) ends to provide a distinct visual contrast from square-like data cards.

## Components

### Buttons
*   **Primary:** Solid Primary Violet background with white text. Apply a subtle linear gradient (top-to-bottom) from a lighter violet to the base primary color.
*   **Secondary:** Ghost style with a Primary Violet border (2px) and transparent background.
*   **Iconography:** Use "duotone" icons where the secondary color is at 30% opacity to reinforce the AI theme.

### Attendance Cards
*   Cards should feature a "Status Glow" on the left edge—a 4px vertical bar that glows Green (Present), Red (Absent), or Violet (Processing).

### Input Fields
*   Dark backgrounds with a 1px border. On focus, the border transitions to Primary Violet with a 4px soft outer glow.

### AI Scanning Interface
*   Use a "Scanning Line" animation: a horizontal Cyan gradient bar that moves vertically across the face-recognition viewport.
*   Corners of the viewport should be bracketed with "L-shaped" technical strokes in Tertiary Cyan.

### Chips & Tags
*   Small, high-contrast pills. For "AI Verified" states, include a small spark icon next to the label.