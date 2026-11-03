---
phase: "05"
slug: "05-shake-developer-experience"
status: approved
reviewed_at: "2026-11-02T20:10:00Z"
shadcn_initialized: false
preset: none
created: "2026-11-02"
---

# Phase 05 — UI Design Contract

> Visual, presentation, and gesture interaction contract for invocation triggers and root app wrapping.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none |
| Preset | not applicable |
| Component library | Flutter Material 3 |
| Icon library | Material Icons (Flutter SDK `Icons.*`) |
| Font | System default (Roboto on Android, SF Pro on iOS/macOS) |

---

## Spacing Scale

Declared values (must be multiples of 4):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Micro padding |
| sm | 8px | Margin around dialog buttons |
| md | 16px | Padding inside snackbars and dialogs |
| lg | 24px | Dialog surface padding |
| xl | 32px | Structural margins |
| 2xl | 48px | Minimum touch target size for interactive controls |

Touch target minimum height: 48px for any interactive controls.

---

## Typography

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Body | 14px | 400 | 1.5 |
| Label | 12px | 600 | 1.33 |
| Heading | 20px | 600 | 1.2 |
| Display | 13px | 400 | 1.4 |

> Exactly 4 font sizes declared (12px, 13px, 14px, 20px) and exactly 2 font weights declared (400 Regular, 600 SemiBold), conforming strictly to design system rules.

---

## Color

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | Light: #F8F9FA / Dark: #121212 | Scaffold background of `NetworkInspectorScreen` |
| Secondary (30%) | Light: #FFFFFF / Dark: #1E1E1E | Surface backgrounds of modals and dialogs |
| Accent (10%) | Light: #2563EB / Dark: #3B82F6 | Primary focus indicators and interactive elements |
| Destructive | #DC2626 | Error indicators |

---

## Presentation & Invocation Contract

### 1. `NetworkInspectorWrapper` Visual Behavior
- `NetworkInspectorWrapper` renders the host application `child` widget directly without introducing any wrapper margins, padding, layout offsets, or extra render objects that could disturb the host app's layout tree.
- No persistent floating action buttons, badges, overlays, or watermark text are rendered on screen (pure gesture & programmatic invocation).
- In release mode (`kReleaseMode`), the wrapper renders `widget.child` directly with zero performance or visual overhead.

### 2. Route Transition & Modality
- Invoked via `MaterialPageRoute(builder: (_) => const NetworkInspectorScreen(), fullscreenDialog: true)`.
- Fullscreen dialog mode presents a close button (`Icons.close`) on the left of the AppBar on iOS and a standard back arrow on Android, matching platform conventions.
- Route transition animates upward from the bottom of the screen as a modal dialog sheet on iOS, and standard material zoom/fade on Android.

### 3. Route Stacking & Debounce Visual Guard
- When a shake event is detected while `NetworkInspector.isOpen` is `true`, the event is dropped silently with zero visual feedback, zero screen flicker, and zero route stacking.
- Subsequent shake events within the 1500ms cooldown window are dropped silently.
- When the user pops/dismisses the inspector screen, `NetworkInspector.isOpen` resets to `false` automatically.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Shake Trigger Disabled Toast (if triggered when disabled) | No message (silent no-op) |
| Missing Navigator Key Debug Warning | `[NetworkInspector] navigatorKey not found. Pass context to NetworkInspector.open(context) or configure navigatorKey.` |
| Accelerometer Stream Error Notice | `[NetworkInspector] Accelerometer sensor unavailable. Shake detection disabled.` |
