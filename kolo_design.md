# Kolo — Design System & Component Specification
**Version:** 1.0.0  
**Extracted from:** Reference UI (fintech dashboard design)  
**Framework:** Flutter

---

## 1. Design Philosophy

Kolo's visual language is **clean, warm, and trustworthy** — not cold and corporate. It uses soft purple/lavender gradients, white card surfaces, and generous rounded corners to feel approachable and modern. The AI personality of Kolo should feel present in the UI — chat bubbles, friendly typography, and animated states reinforce that there's an intelligent companion behind the interface.

**Aesthetic Direction:** Soft Glassmorphic Fintech — white cards floating on a pastel gradient, dark accent card, clean hierarchy, no harsh edges.

---

## 2. Color Tokens

### Background
```dart
// App-wide gradient background
backgroundGradientStart: Color(0xFFE8D5F5)  // Soft lavender pink
backgroundGradientEnd:   Color(0xFFD4B8E0)  // Deeper muted purple
backgroundGradientAngle: 135deg (top-left to bottom-right)

// Screen scaffold background (below cards)
scaffoldBackground: Color(0xFFF5EEF8)
```

### Primary
```dart
primary:          Color(0xFF7C3AED)   // Rich purple — buttons, active states
primaryLight:     Color(0xFF9F67F5)   // Lighter purple — hover, secondary actions
primaryPastel:    Color(0xFFEDE9FE)   // Very light purple — tag backgrounds, chips
```

### Surface (Cards)
```dart
surfaceWhite:     Color(0xFFFFFFFF)   // Main card background
surfaceElevated:  Color(0xFFFAF8FF)   // Slightly tinted white for nested cards
surfaceDark:      Color(0xFF1E1B4B)   // Dark navy — hero card (bank card widget)
surfaceDarkLight: Color(0xFF2D2867)   // Lighter dark — card shimmer areas
```

### Text
```dart
textPrimary:      Color(0xFF1A1523)   // Near black — headings, balance
textSecondary:    Color(0xFF6B7280)   // Medium gray — labels, subtitles
textMuted:        Color(0xFF9CA3AF)   // Light gray — placeholder, timestamps
textOnDark:       Color(0xFFFFFFFF)   // White — text on dark card
textOnDarkMuted:  Color(0xFFB8B0D8)   // Muted white — secondary on dark card
```

### Semantic
```dart
income:    Color(0xFF10B981)   // Green — credit, positive
expense:   Color(0xFFEF4444)   // Red — debit, over budget
warning:   Color(0xFFF59E0B)   // Amber — caution, near limit
safe:      Color(0xFF10B981)   // Green — within budget
neutral:   Color(0xFF6B7280)   // Gray — neutral states
```

### Chart Colors
```dart
chartEarned:    Color(0xFF7C3AED)   // Purple
chartSpent:     Color(0xFFEF4444)   // Red/coral
chartAvailable: Color(0xFF10B981)   // Green
chartSavings:   Color(0xFFF59E0B)   // Amber/gold
chartBar1:      Color(0xFF7C3AED)
chartBar2:      Color(0xFFE9D5FF)   // Light purple (inactive bar)
```

### Overlay & Bubble
```dart
bubbleBackground:    Color(0xFF7C3AED)    // Kolo bubble — purple
bubbleShadow:        Color(0x557C3AED)    // Purple shadow glow
overlayBackground:   Color(0xF0FFFFFF)   // Overlay sheet background (near white)
overlayBarrier:      Color(0x30000000)   // Dim behind overlay
```

---

## 3. Typography

### Font Family
```dart
// Display / Headings — bold, characterful
displayFont: 'Sora'         // Google Font — rounded, modern, friendly

// Body / UI — clean, readable  
bodyFont: 'DM Sans'         // Google Font — neutral, highly legible

// Numbers / Monospace — balance, card numbers
monoFont: 'DM Mono'         // Google Font — clean monospace for amounts
```

### Type Scale
```dart
// Display
displayXL:   fontSize: 32, fontWeight: w700, fontFamily: Sora
displayL:    fontSize: 28, fontWeight: w700, fontFamily: Sora
displayM:    fontSize: 24, fontWeight: w600, fontFamily: Sora

// Headings
headingL:    fontSize: 20, fontWeight: w600, fontFamily: DM Sans
headingM:    fontSize: 18, fontWeight: w600, fontFamily: DM Sans
headingS:    fontSize: 16, fontWeight: w600, fontFamily: DM Sans

// Body
bodyL:       fontSize: 16, fontWeight: w400, fontFamily: DM Sans
bodyM:       fontSize: 14, fontWeight: w400, fontFamily: DM Sans
bodyS:       fontSize: 12, fontWeight: w400, fontFamily: DM Sans

// Amount / Balance (monospace)
amountXL:    fontSize: 36, fontWeight: w700, fontFamily: DM Mono
amountL:     fontSize: 28, fontWeight: w700, fontFamily: DM Mono
amountM:     fontSize: 20, fontWeight: w600, fontFamily: DM Mono
amountS:     fontSize: 16, fontWeight: w500, fontFamily: DM Mono

// Labels
labelM:      fontSize: 12, fontWeight: w500, fontFamily: DM Sans, letterSpacing: 0.3
labelS:      fontSize: 10, fontWeight: w500, fontFamily: DM Sans, letterSpacing: 0.5
```

---

## 4. Spacing & Layout

```dart
// Base unit: 4px
spaceXXS:  2px
spaceXS:   4px
spaceS:    8px
spaceM:    12px
spaceL:    16px
spaceXL:   20px
spaceXXL:  24px
space3XL:  32px
space4XL:  40px
space5XL:  48px

// Screen padding
screenPaddingH:  20px   // Horizontal page padding
screenPaddingV:  24px   // Top padding from safe area

// Card internal padding
cardPaddingM:    16px
cardPaddingL:    20px
cardPaddingXL:   24px
```

---

## 5. Border Radius

```dart
radiusXS:    4px    // Tags, small chips
radiusS:     8px    // Small elements
radiusM:     12px   // Buttons, input fields
radiusL:     16px   // Cards (secondary)
radiusXL:    20px   // Cards (primary), bottom sheets
radiusXXL:   24px   // Hero cards
radius3XL:   32px   // Bank card widget
radiusFull:  999px  // Pills, bubbles, toggle
```

---

## 6. Elevation & Shadow

```dart
// Card shadow (white cards on gradient background)
shadowCard: BoxShadow(
  color: Color(0x14000000),  // 8% black
  blurRadius: 20,
  offset: Offset(0, 4),
  spreadRadius: 0,
)

// Elevated card shadow
shadowCardElevated: BoxShadow(
  color: Color(0x1F000000),  // 12% black
  blurRadius: 30,
  offset: Offset(0, 8),
  spreadRadius: -4,
)

// Floating bubble shadow
shadowBubble: BoxShadow(
  color: Color(0x557C3AED),   // Purple glow
  blurRadius: 20,
  offset: Offset(0, 4),
  spreadRadius: 0,
)

// Bottom sheet / overlay
shadowOverlay: BoxShadow(
  color: Color(0x20000000),
  blurRadius: 40,
  offset: Offset(0, -8),
)
```

---

## 7. Component Specifications

### 7.1 Scaffold & Background
```
Widget: Stack
  - Gradient container (full screen)
    LinearGradient: backgroundGradientStart → backgroundGradientEnd
    angle: 135deg
  - SafeArea content
  - Floating bubble (positioned)
```

### 7.2 App Bar (Home)
```
Height: 60px
Background: transparent (shows gradient through)
Left: Hamburger menu icon (3 lines) — Color: textPrimary
Center: (empty on home) / Screen title on inner screens — headingM
Right: Notification bell icon + User avatar (32px circle)
```

### 7.3 Bank Card Widget (Hero Card)
```
Size: full width, height ~180px
Background: surfaceDark (#1E1B4B)
Border radius: radius3XL (32px)
Padding: cardPaddingXL

Layout:
  Top row:
    Left: Card logo (small Apple/bank icon, white)
    Right: Masked card number dots "•••• •••• 2585"
  
  Second row (below):
    Left: Another card option (Apple card) with number "•••• •••• 7845"

  Bottom section:
    Label "Balance" — labelM, textOnDarkMuted
    Amount "₦50,000.00" — amountXL, textOnDark (DM Mono)
    
    Right column:
      Label "Exp. Date" — labelS, textOnDarkMuted
      Value "08/26" — bodyS, textOnDark
    
    Bottom row:
      Name "USER NAME" — bodyM, textOnDark
      Button "+ Add Card" — pill button, surfaceWhite bg, textPrimary text, 
                            fontSize 12, padding H:16 V:8

Decoration: Subtle circular gradient overlay in top-right corner
            Color: Color(0x207C3AED) — slight purple tint
```

### 7.4 Quick Action Buttons (Home Grid)
```
Layout: Row, evenly spaced, 4 items
Each item:
  Column:
    - Icon container: 48x48px, borderRadius radiusM
      Background: surfaceWhite
      Shadow: shadowCard
      Icon: 20px, color primary
    - Label: labelM, textSecondary, marginTop: 8px

Actions: Send, Request, TopUp, More
```

### 7.5 Surface Card (Generic White Card)
```
Background: surfaceWhite
Border radius: radiusXL (20px)
Shadow: shadowCard
Padding: cardPaddingL (20px)
Margin: H: screenPaddingH, V: spaceS
```

### 7.6 Section Header Row
```
Layout: Row, spaceBetween
Left: Text — headingS, textPrimary
Right: Text "View All" — bodyS, primary (tappable)
Margin bottom: spaceM
```

### 7.7 Transaction List Item
```
Height: 64px
Layout: Row
  Left: Avatar/Icon (40px circle)
    - For person: initials or profile photo
    - For merchant: category emoji or icon in colored circle
  Center: Column
    - Title: bodyM, textPrimary, fontWeight w500
    - Subtitle: bodyS, textSecondary (date + time)
  Right: Column, crossAxisAlignment: end
    - Amount: amountS, 
      Credit → income green, prefix "+"
      Debit → expense red, prefix "-"
    - Optional: category chip

Divider: none (use spacing between items: spaceM)
```

### 7.8 Toggle Pill (Income / Expense)
```
Container: pill shape (radiusFull), background: surfaceWhite or light gray
Height: 36px
Two options side by side
  Active: background primary, text white, fontWeight w600
  Inactive: background transparent, text textSecondary
Animation: slide transition on toggle
```

### 7.9 Budget Category Card
```
Size: ~(screenWidth/2 - 28px) × auto (grid, 2 columns)
Background: surfaceWhite
Border radius: radiusL (16px)
Shadow: shadowCard
Padding: cardPaddingM

Layout:
  Top row:
    Icon: emoji in 36px container, background primaryPastel, radiusS
    Right: item count label — labelS, textMuted "12 items"
  
  Category name: bodyM, textPrimary, marginTop spaceS
  Amount: amountS, textPrimary, fontWeight w700
  
  Progress bar:
    Height: 4px
    Background: Color(0xFFE9D5FF)
    Fill: primary → warning → expense (based on % used)
    Border radius: radiusFull
    MarginTop: spaceS
```

### 7.10 Donut Chart (Analytics)
```
Library: fl_chart (PieChart)
Size: ~180px diameter
Hole radius: 60% (donut style)
Center label:
  "Total Balance" — labelS, textMuted
  "₦8,182" — amountM, textPrimary

Segments:
  Earned — chartEarned
  Spent — chartSpent  
  Available — chartAvailable
  Savings — chartSavings

Legend (right side):
  Each item: colored dot (8px) + label + amount
  Layout: column, spacing spaceS
```

### 7.11 Weekly Bar Chart
```
Library: fl_chart (BarChart)
Height: 160px
X-axis: Mon Tue Wed Thu Fri Sat Sun — labelS, textMuted
Y-axis: hidden
Bar: width 20px, border radius top only (4px)
  Default: chartBar2 (light purple)
  Selected/Today: chartBar1 (purple) with tooltip
Tooltip: small pill above selected bar
  Background: surfaceDark
  Text: amount — labelM, textOnDark
Grid: light horizontal lines, Color(0x20000000)
```

### 7.12 Account Selector (Analytics)
```
Container: surfaceWhite card, radiusL, padding cardPaddingM
Layout: Row
  Left: Bank icon (24px)
  Center: Column
    Account name — bodyM, textPrimary, w500
    Masked number — labelM, textMuted
  Right: Balance amount + dropdown chevron icon
    Amount — amountS, textPrimary
    Icon: chevron down, textSecondary
```

### 7.13 Transfer Row (Transactions Screen)
```
Section header: "Transfer to"
Layout: Row
  Left: Avatar (40px circle, initials)
  Center: Column
    Name — bodyM, textPrimary, w500
    Phone — bodyS, textMuted
  Right: "Change" button — text button, primary color

Amount field:
  Large text input, amountL style, textPrimary
  Label above: "Transfer Amount" — labelM, textMuted
  
Edit button: small pill, surfaceWhite border, "Edit" label

Add notes: bodyS, textMuted, italic — tappable row

Save checkbox: small checkbox + "Save this account" label
```

### 7.14 Input Field
```
Height: 52px
Background: surfaceWhite
Border: 1px solid Color(0xFFE5E7EB) — default
        1px solid primary — focused
Border radius: radiusM (12px)
Padding: H: spaceL, V: spaceM
Font: bodyM, textPrimary
Label: bodyS, textSecondary — above field, marginBottom: spaceXS
Prefix: currency symbol (₦) in textSecondary for amount fields
```

### 7.15 Primary Button
```
Height: 52px
Background: primary (#7C3AED)
Border radius: radiusM (12px)
Text: headingS, white, fontWeight w600
Padding: H: spaceXXL
Shadow: BoxShadow(color: 0x407C3AED, blurRadius: 12, offset: Offset(0,4))

States:
  Default: as above
  Pressed: scale(0.97), brightness darken 10%
  Disabled: opacity 0.5
  Loading: CircularProgressIndicator (white, size 20px) replaces text
```

### 7.16 Secondary Button
```
Height: 52px
Background: transparent
Border: 1.5px solid primary
Border radius: radiusM (12px)
Text: headingS, primary, fontWeight w600
```

### 7.17 Bottom Navigation Bar
```
Height: 72px (+ safe area bottom)
Background: surfaceWhite
Shadow: shadowOverlay (top shadow)
Border radius top: radiusXL

5 items: Home, Transactions, AI, Budget, Profile
Each item:
  Icon: 22px
  Label: labelS (shown only on active or all?)
  
Active indicator:
  Pill shape behind active item
  Background: primaryPastel (#EDE9FE)
  Icon: primary color
  Label: primary color, fontWeight w600
  
Inactive:
  Icon: textMuted
  Label: textMuted

Special: AI (center) tab:
  Larger icon container: 52px circle
  Background: primary
  Icon: white
  Elevated above bar (negative margin-top: 12px)
  Shadow: shadowBubble
```

### 7.18 Floating Bubble (Kolo Overlay)
```
Size idle: 56px × 56px circle
Background: primary (#7C3AED)
Shadow: shadowBubble
Content: Kolo logo / face icon (white, 28px)

Badge (when alert):
  12px circle, expense red
  Top-right of bubble
  Count number inside (white, 9px)

Animation idle → alert:
  Pulse scale 1.0 → 1.15 → 1.0, duration 600ms, repeat 3x

Draggable: snaps to left or right edge with spring animation

Expanded state (bottom sheet):
  Slides up from bottom, height ~60% screen
  Background: overlayBackground (0xF0FFFFFF)
  Border radius top: radiusXXL (24px)
  Shadow: shadowOverlay
  
  Handle bar: 40px × 4px, Color(0xFFE5E7EB), radiusFull, centered top
  
  Header:
    Kolo avatar (36px) + "Kolo" label — row, left aligned
    Balance chip (right): "₦X,XXX" — pill, primaryPastel bg, primary text
  
  Message area: scrollable chat bubbles
  Input area: fixed bottom
```

### 7.19 Chat Bubble (AI Chat & Overlay)
```
AI bubble (left aligned):
  Background: surfaceWhite
  Border radius: radiusL, bottomLeft: radiusXS
  Padding: spaceM spaceL
  Text: bodyM, textPrimary
  Max width: 80% of container
  Avatar: 28px circle (Kolo icon) to left of bubble

User bubble (right aligned):
  Background: primary
  Border radius: radiusL, bottomRight: radiusXS
  Padding: spaceM spaceL
  Text: bodyM, white
  Max width: 80% of container

Timestamp: labelS, textMuted, centered between message groups

Typing indicator (AI thinking):
  3 dots animated bounce
  Inside AI bubble shape
```

### 7.20 Savings Vault Card
```
Background: surfaceWhite card
Layout:
  Top row: vault icon (emoji) + vault name + target amount
  Progress bar (full width): radiusFull, height 8px
    Background: primaryPastel
    Fill: primary (animated on load)
  Bottom row: 
    Left: "₦current saved" — amountS, primary
    Right: "₦target" — bodyS, textMuted
```

### 7.21 Owing Card
```
Layout: Row
  Left: Person initials circle (40px), background primaryPastel, primary text
  Center: Column
    Person name — bodyM, textPrimary, w500
    Date + "X days ago" — bodyS, textMuted
  Right: Column, crossAxisAlignment: end
    Amount — amountS, income (they owe me) or expense (I owe)
    "Remind" or "Settle" text button — labelM, primary
```

---

## 8. Animation Guidelines

```dart
// Standard durations
durationFast:    150ms    // Button press, micro-interactions
durationNormal:  250ms    // Page transitions, card appear
durationSlow:    400ms    // Sheet slide up, chart draw
durationVerySlow:600ms   // Onboarding, bubble pulse

// Curves
curveDefault:    Curves.easeInOut
curveEnter:      Curves.easeOut
curveExit:       Curves.easeIn
curveSpring:     Curves.elasticOut   // Bubble snap to edge
curveBounce:     Curves.bounceOut    // Vault milestone celebration

// Signature animations
pageTransition:  Slide from right, fade — 250ms easeOut
cardAppear:      Fade + slide up 16px — 300ms easeOut, staggered 60ms per card
balanceReveal:   Count up number animation — 800ms easeOut
chartDraw:       Sweep from 0 — 600ms easeInOut
bubbleExpand:    Slide up + fade — 350ms easeOut
bubblePulse:     Scale 1.0→1.15→1.0 — 600ms, x3
progressFill:    Width animation left to right — 500ms easeOut
```

---

## 9. Iconography

```
Style: Outlined (default), Filled (active states)
Library: Lucide Icons (lucide_flutter package) OR Material Symbols
Size: 20px (nav inactive), 22px (nav active), 24px (actions), 20px (list items)

Key icons:
  Home:          home / home_filled
  Transactions:  receipt_long
  AI / Kolo:     auto_awesome / sparkles  
  Budget:        pie_chart / donut_large
  Profile:       person_outline
  Send:          arrow_upward (rotated 45°) / send
  Receive:       arrow_downward (rotated 45°)
  TopUp:         add_circle_outline
  More:          more_horiz
  Notification:  notifications_none
  Settings:      settings
  Vault:         lock_outline
  Owing:         handshake / people_outline
  Gig:           work_outline
  Bills:         receipt_outlined
```

---

## 10. Onboarding Screen Spec

```
Background: full gradient (same as app)
Progress: dot indicators top center

Each step:
  Top 40%: Lottie animation or illustration (centered)
  Bottom 60%: white rounded container (radiusXXL top corners)
    Title: displayM, textPrimary
    Subtitle: bodyL, textSecondary
    Input or choice area (step-specific)
    Next button: primary button, full width

AI chat style onboarding (steps 2-6):
  Chat bubbles animate in one at a time
  Kolo asks question → user responds below
  Feels like a real conversation
  Input: rounded text field, send button (primary circle)
```

---

## 11. Flutter Theme Config

```dart
ThemeData koloTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme(
    primary: Color(0xFF7C3AED),
    secondary: Color(0xFF9F67F5),
    surface: Color(0xFFFFFFFF),
    background: Color(0xFFF5EEF8),
    error: Color(0xFFEF4444),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Color(0xFF1A1523),
    onBackground: Color(0xFF1A1523),
    onError: Colors.white,
    brightness: Brightness.light,
  ),
  fontFamily: 'DM Sans',
  textTheme: TextTheme(/* mapped to type scale above */),
  cardTheme: CardTheme(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    color: Colors.white,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Color(0xFF7C3AED), width: 1.5),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFF7C3AED),
      foregroundColor: Colors.white,
      minimumSize: Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: Color(0xFF7C3AED),
    unselectedItemColor: Color(0xFF9CA3AF),
    showSelectedLabels: true,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),
);
```

---

## 12. Folder Structure Recommendation

```
lib/
├── core/
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   ├── app_spacing.dart
│   │   └── app_theme.dart
│   ├── constants/
│   └── utils/
├── features/
│   ├── auth/
│   ├── home/
│   ├── transactions/
│   ├── ai_chat/
│   ├── budget/
│   ├── analytics/
│   ├── vaults/
│   ├── owings/
│   ├── gigs/
│   └── settings/
├── services/
│   ├── sms_service.dart
│   ├── notification_service.dart
│   ├── overlay_service.dart
│   ├── firebase_service.dart
│   └── ai_service.dart
├── shared/
│   ├── widgets/
│   │   ├── kolo_card.dart
│   │   ├── transaction_tile.dart
│   │   ├── budget_category_card.dart
│   │   ├── primary_button.dart
│   │   ├── chat_bubble.dart
│   │   └── ...
│   └── models/
└── main.dart
```
