# Kolo — Added Features PRD
**Version:** 1.1.0
**Status:** Addendum to kolo_prd.md
**Scope:** App Block Mode + Aether Visual System

---

## Feature 1: App Block Mode

### Overview
An optional, per-app financial gatekeeper. When enabled for a watched banking app, Kolo intercepts the app launch with a full-screen overlay. The user cannot access the app until they interact with Kolo AI. Unlike the default soft bubble (which can be dismissed), Block Mode creates a mandatory checkpoint.

This is distinct from the existing App Watcher feature in `kolo_prd.md`. App Watcher shows a dismissible bubble. Block Mode shows a full-screen mandatory overlay. Both are independent toggles per app.

---

### Three Block Levels
Configurable per watched app in Settings → Watched Apps → [App Name] → Block Level.

#### Level 1 — Soft (Default, existing behavior)
- Floating bubble appears, pulsing
- User can dismiss without interaction
- No change to existing implementation

#### Level 2 — Explain Mode *(new)*
- Full-screen aether overlay covers the app
- Kolo bubble renders centered on overlay
- User must type an explanation before proceeding
- AI reads explanation, logs it with context, always allows through
- Purpose: friction + audit trail. Forces conscious decision.
- Override: always available — AI never blocks, just logs and notes

#### Level 3 — Hard Lock *(new)*
- Full-screen aether overlay covers the app
- Kolo bubble renders centered on overlay
- User must type an explanation
- AI evaluates against current budget, balance, and spending context
- Decision outcomes:
  - **Approved** → overlay dismisses, app accessible
  - **Caution** → AI warns, user can override with one extra tap ("Proceed anyway")
  - **Advised Against** → AI blocks with reasoning, user can still override with typed confirmation ("I understand, let me in")
- Purpose: active financial intervention. AI acts as a real gatekeeper.
- Hard override always exists — Kolo never truly imprisons the user, but adds maximum friction

---

### Technical Implementation

#### Mechanism
Uses the existing `AccessibilityService` (already required for App Watcher) combined with `SYSTEM_ALERT_WINDOW` (already required for the bubble). No new permissions needed.

**Flow:**
```
AccessibilityService detects watched app → foreground
    │
    Is Block Mode enabled for this app?
    ├── No → existing soft bubble behavior
    └── Yes →
            Immediately show full-screen overlay window
            (TYPE_APPLICATION_OVERLAY, fully opaque, captures all touches)
            │
            Render aether background animation
            Render Kolo bubble centered
            Bubble auto-expands to chat state
            │
            User interacts with AI
            │
            ├── Explain Mode: any response → log → dismiss overlay
            └── Hard Lock: AI evaluates → approved/caution/block
                    │
                    On dismiss → overlay removed
                    On cancel → GLOBAL_ACTION_BACK (send user away from app)
```

#### Key Android Implementation Notes
- Window type: `TYPE_APPLICATION_OVERLAY` (API 26+)
- Window flags: `FLAG_NOT_FOCUSABLE` removed (overlay must capture keyboard input for chat)
- Window flags: `FLAG_LAYOUT_IN_SCREEN`, `FLAG_FULLSCREEN`
- Back button: intercepted by overlay, triggers cancel flow
- Home button: cannot be intercepted (Android restriction) — if user presses home, overlay is dismissed and re-triggers next time app is opened
- Banking app anti-overlay detection: some banking apps use `filterTouchesWhenObscured`. This affects pass-through touches only. Since Kolo's overlay is fully opaque and captures all touches itself, this does not apply.
- Android 17 Advanced Protection Mode restricts AccessibilityService — this affects a small minority of security-conscious users. Show a graceful fallback (soft bubble) if AccessibilityService is unavailable.

#### State Management
```dart
enum BlockLevel { soft, explain, hardLock }

class WatchedAppConfig {
  final String packageName;
  final String appName;
  final bool isWatched;
  final BlockLevel blockLevel;  // NEW
}
```

Store per-app block level in Firestore under `users/{uid}/watchedApps`.

#### Overlay Lifecycle
```
onAppForeground(packageName)
    → check WatchedAppConfig.blockLevel
    → if explain or hardLock:
        overlayService.showBlockOverlay(packageName, blockLevel)

overlayService.showBlockOverlay()
    → inflate aether overlay window (see Visual Spec below)
    → start aether animation
    → expand Kolo bubble to chat
    → listen for AI decision

onAIDecision(approved)
    → if approved: overlayService.dismissBlockOverlay()
    → if denied: overlayService.dismissBlockOverlay() + performGlobalAction(BACK)

onUserCancel()
    → overlayService.dismissBlockOverlay()
    → performGlobalAction(BACK)
```

---

### Settings UI

**Location:** Settings → Watched Apps → tap any app → Block Level

```
[App row]
  App icon + name
  Toggle: Watch this app [ON/OFF]

  (if watched = ON, show:)
  Block Level:
    ○ Soft     — bubble only, dismissible
    ○ Explain  — must type reason, always allowed through
    ● Hard Lock — AI decides, override available

  Small description text under each option.
```

---

## Feature 2: Aether Visual System

### Overview
Kolo's signature visual identity for the block overlay and the floating bubble. Inspired by the soft, moving liquid-light aesthetic seen in OpenAI's Codex landing page — soft blues, purples, and whites moving slowly like light through water. Applied to two surfaces:

1. **Block Overlay Background** — full-screen aether canvas behind the Kolo bubble during app interception
2. **Kolo Bubble Orb** — the existing floating bubble already uses a contained liquid aether orb (dark, teal-tinged liquid motion inside a circle). This spec ensures both are consistent and the bubble renders correctly over the overlay.

---

### 2A — Block Overlay: Full-Screen Aether Background

#### Visual Description
A full-screen animated gradient that feels like soft light moving through mist or water. Colors shift slowly between soft lavender, ice blue, white, and pale purple. The motion is slow, organic, and non-repeating — like a living background. No hard edges, no geometric shapes. Pure ambient color movement.

#### Reference
OpenAI Codex website background: `https://openai.com/codex` — the background behind the Codex logo. Soft blue/lavender/white gradients that slowly drift and breathe.

#### Color Palette (Aether Background)
All colors pulled directly from `kolo_design.md` — no new tokens introduced.

```dart
// Orb 1 — primary lavender pink drift
aetherOrb1: backgroundGradientStart  // Color(0xFFE8D5F5) — Soft lavender pink

// Orb 2 — deeper purple mass
aetherOrb2: backgroundGradientEnd    // Color(0xFFD4B8E0) — Deeper muted purple

// Orb 3 — rich purple accent pool
aetherOrb3: primaryLight             // Color(0xFF9F67F5) — Lighter purple

// Orb 4 (optional, subtle) — very light purple edge wash
aetherOrb4: chartBar2                // Color(0xFFE9D5FF) — Light purple

// Canvas base (behind all orbs)
aetherCanvas: scaffoldBackground     // Color(0xFFF5EEF8) — Near white lavender

// Overlay veil (thin white layer over aether for legibility)
aetherVeil: Color(0x10FFFFFF)        // 6% white — same approach as overlayBarrier
```

#### Flutter Implementation — Shader/Animation Approach

**Option A (Recommended): Custom Painter + AnimationController**
```dart
// AetherBackground widget
// Uses multiple animated radial gradients that slowly orbit each other
// Each "orb" is a large soft radial gradient with low opacity
// They move in slow sinusoidal paths, overlapping and blending

class AetherBackground extends StatefulWidget { ... }

// Animation:
// - 3-4 color orbs, each on independent slow animation (8-15 second cycles)
// - Orb positions: sin/cos wave paths with different frequencies
// - Blend mode: BlendMode.screen or BlendMode.lighten for soft light feel
// - Canvas background: aetherMist (near white)
// - Each orb: RadialGradient, radius ~60-80% of screen, opacity 0.6-0.8

// Orb configs:
Orb(
  color: aetherBlue,
  size: 0.8,           // 80% of screen width as radius
  speed: 12.0,         // seconds per cycle
  pathRadius: 0.3,     // how far it wanders (30% of screen)
  startAngle: 0.0,
)
Orb(
  color: aetherLavender,
  size: 0.7,
  speed: 15.0,
  pathRadius: 0.25,
  startAngle: 2.1,     // offset start (2π/3)
)
Orb(
  color: aetherPurple,
  size: 0.5,
  speed: 10.0,
  pathRadius: 0.2,
  startAngle: 4.2,     // offset start (4π/3)
)
```

**Option B: Flutter Shaders (GLSL) — Higher Quality**
```glsl
// aether.frag — GLSL fragment shader for Flutter
// Uses domain-warped noise for organic fluid motion
// Load via FragmentProgram from pubspec assets

uniform float time;
uniform vec2 resolution;

// Smooth noise + domain warping produces the flowing liquid light look
// Color palette maps noise values to the aether color range
// Much more organic than animated gradients
```
*Use Flutter's `FragmentProgram` API (available Flutter 3.7+). Reference: flutter.dev/go/fragment-shaders*

**Recommended package:** `flutter_shaders` — simplifies GLSL asset loading.

#### Overlay Composition
```
Stack (full screen, overlay window)
  │
  ├── AetherBackground()          // fills entire screen, animated
  │     opacity: 1.0
  │
  ├── BackdropFilter(             // subtle blur on anything behind
  │     filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20)
  │   )
  │
  ├── Container(                  // semi-transparent white veil
  │     color: Color(0x15FFFFFF)  // 8% white over aether
  │   )
  │
  └── Center(
        KoloBubbleExpanded()      // bubble + chat UI centered
      )
```

---

### 2B — Kolo Bubble Orb: Liquid Aether Orb

#### Visual Description
The existing floating bubble is a dark circle containing a moving liquid orb — deep navy/dark background with a teal/cyan/blue liquid mass that moves organically inside the circle, like a lava lamp or liquid planet. This is already implemented (referenced in current codebase as "liquid aether orb"). This spec documents it for consistency and ensures it renders correctly when placed over the full-screen aether background.

#### Reference
Second attached image in conversation: dark circular bubble with animated teal/blue liquid swirling inside. The liquid has depth — brighter teal highlights, darker navy shadows.

#### Bubble Orb Colors
All colors pulled directly from `kolo_design.md` — no new tokens introduced.

```dart
// Shell / background of the orb circle
orbBackground:  surfaceDark          // Color(0xFF1E1B4B) — Dark navy

// Liquid body — main mass inside the orb
orbLiquidMain:  primary              // Color(0xFF7C3AED) — Rich purple

// Liquid shadow / depth
orbLiquidDeep:  surfaceDark          // Color(0xFF1E1B4B) — Dark navy (darker pools)

// Liquid highlight / shimmer on top of mass
orbLiquidLight: primaryLight         // Color(0xFF9F67F5) — Lighter purple shimmer

// Liquid mid-tone
orbLiquidMid:   surfaceDarkLight     // Color(0xFF2D2867) — Lighter dark navy

// Orb rim border
orbRim:         surfaceDarkLight     // Color(0xFF2D2867) — Subtle dark border

// Orb glow shadow
orbGlow:        bubbleShadow         // Color(0x557C3AED) — Purple glow (already in design.md)

// Orb background fill (the bubble itself, not the liquid inside)
orbShell:       bubbleBackground     // Color(0xFF7C3AED) — matches existing bubble
```

#### Bubble Orb Implementation
```dart
// KoloOrbWidget — the animated liquid orb inside the bubble
//
// Layers (bottom to top):
// 1. Dark circle (surfaceDark / orbBackground) — base shell
// 2. Animated liquid shape (CustomPainter)
//    - Uses Path with cubic bezier control points
//    - Control points animated via AnimationController
//    - Fills with gradient: orbLiquidDeep → orbLiquidMain → orbLiquidLight
//      (surfaceDark → primary → primaryLight — all from design.md)
//    - The "blob" shape slowly morphs and shifts
// 3. Shimmer highlight (small bright ellipse, primaryLight)
//    - Positioned top-left of liquid mass
//    - Softly animated opacity 0.6 → 1.0
// 4. Rim border (surfaceDarkLight, width: 1.5px)
// 5. Drop shadow (bubbleShadow — Color(0x557C3AED), blurRadius: 16, spreadRadius: 2)

// Idle size: 56×56px
// Expanded (over block overlay): 80×80px, centered above chat panel
// Animation speed: 3-4 second morph cycle (slow and organic)
```

#### Bubble Over Aether Overlay — Rendering
When the block overlay is active, the bubble renders in the center of the screen in expanded state. The dark orb creates strong contrast against the light aether background — intentional. The bubble should feel like it's floating IN the aether, not on top of it.

```dart
// Positioning on block overlay:
// Bubble orb: centered horizontally, 30% from top vertically
// Chat panel: slides up from bottom (60% screen height)
// Orb sits at the join point between aether background and chat panel

Stack(
  children: [
    AetherBackground(),          // full screen aether
    Positioned(
      top: screenHeight * 0.22,
      left: 0, right: 0,
      child: Center(child: KoloOrbWidget(size: 80)),
    ),
    Positioned(
      bottom: 0, left: 0, right: 0,
      child: BlockChatPanel(),   // chat panel, 62% height
    ),
  ]
)
```

#### Block Chat Panel Design
```
Container:
  height: 62% of screen
  background: Color(0xF5FFFFFF)  — near white, 96% opacity
  borderRadius: top corners 28px
  shadow: BoxShadow(color: 0x20000000, blurRadius: 40, offset: Offset(0, -8))

Contents:
  Handle bar: 40×4px, Color(0xFFDDDDDD), radiusFull, margin top 12px, centered

  Header row (padding: 20px horizontal, 16px top):
    Left: "Kolo" — headingM, textPrimary, Sora font
    Right: balance chip — "₦X,XXX" pill, primaryPastel bg, primary text

  Context line (below header):
    "You're opening [App Name]" — bodyS, textSecondary, italic
    Example: "You're opening Kuda"

  AI message bubble (auto-appears, animates in):
    Standard AI chat bubble style from design.md
    Message varies by block level:
      Explain: "Before you go in — what's this for?"
      HardLock: "Hold on. You've spent ₦X,XXX on [category] this week.
                  Your budget allows ₦X,XXX. What's the plan?"

  Chat input (pinned bottom):
    Standard input field from design.md
    Placeholder: "Tell Kolo what's up..."
    Send button: primary circle, arrow icon

  Cancel link (below input):
    "Never mind, go back" — bodyS, textMuted, centered, tappable
```

---

## Feature 3: Block Mode Onboarding Prompt

When user first enables Hard Lock on any app, show a one-time explanation modal:

```
Modal (bottom sheet):
  Title: "Hard Lock is serious 🔒"
  Body: "When you try to open [App], Kolo will review your
         spending context and decide if it's a good idea.
         You can always override — Kolo never truly locks you out.
         But you'll have to explain yourself first."

  Button: "Got it, enable Hard Lock" — primary
  Link: "Use Explain Mode instead" — text, primary color
```

---

## Integration Notes for AI Agent

### Files to update:
- `lib/features/settings/watched_apps_screen.dart` — add block level selector UI
- `lib/services/overlay_service.dart` — add `showBlockOverlay()`, `dismissBlockOverlay()`
- `lib/services/accessibility_service.dart` — route to block overlay vs soft bubble
- `lib/features/overlay/block_overlay.dart` — NEW: full screen block overlay widget
- `lib/shared/widgets/aether_background.dart` — NEW: animated aether background
- `lib/shared/widgets/kolo_orb_widget.dart` — ensure existing orb works at 80px size
- `lib/shared/models/watched_app_config.dart` — add `BlockLevel` enum + field
- `firestore` — update `watchedApps` schema with `blockLevel` field
- `pubspec.yaml` — add `flutter_shaders` if GLSL route chosen; ensure `flutter_animate` present

### No new permissions required.
### No Firebase Cloud Function changes required (AI evaluation reuses existing `evaluateSpendingJustification` callable).
### Block level `explain` does NOT call AI evaluation — it only logs. Only `hardLock` calls the callable.

---

## Summary of New Components

| Component | Type | Description |
|---|---|---|
| `AetherBackground` | Flutter Widget | Full-screen animated soft gradient |
| `BlockOverlay` | Flutter Widget | Full-screen overlay window containing aether + orb + chat |
| `BlockChatPanel` | Flutter Widget | Bottom sheet chat panel inside block overlay |
| `KoloOrbWidget` (update) | Flutter Widget | Ensure renders at 80px over aether |
| `BlockLevel` | Dart Enum | soft / explain / hardLock |
| `WatchedAppConfig` (update) | Dart Model | Add blockLevel field |
| Block level selector | UI | 3-option radio in watched app settings |
| Hard lock onboarding modal | UI | One-time modal on first hard lock enable |
