# Kolo — Product Requirements Document
**Version:** 1.0.0  
**Status:** Planning  
**Platform:** Android (Flutter)  
**Backend:** Firebase (Firestore, Auth)
**AI:** Google Gemini REST via Flutter/Dio on Spark; Cloud Functions adapter retained for future Blaze deployment

---

## 1. Vision

Kolo is a personal AI-powered financial operating system built for young Nigerians with irregular income — students, freelancers, and early-career professionals. The name comes from the Nigerian slang for piggy bank.

Unlike traditional budget apps that require manual input and discipline, Kolo is proactive. It watches your phone, reads your transaction alerts automatically, intercepts you before you spend, and puts an AI fund manager between you and your bad financial decisions.

Kolo is not a bank. It does not move money. It is a financial intelligence layer that sits on top of your existing banking apps and makes you smarter about what you already have.

---

## 2. The Core Problem

- Income is irregular — money comes from parents, gigs, family, unpredictably
- Manual logging never sticks — users forget within days
- Spending on unnecessary things (snacks, impulse buys) drains limited funds
- No existing Nigerian app combines automatic transaction detection + AI coaching + spending intervention
- Users need help making a small, unpredictable income last

---

## 3. Target User (v1.0)

**Primary:** Personal-first user, with optional trusted sharing  
**Profile:**
- Nigerian student or young freelancer
- Uses Android phone
- Has accounts on at least one Nigerian bank or fintech (Kuda, Opay, GTB, Access, etc.)
- Receives income from multiple unpredictable sources
- Wants to save but lacks structure and accountability

---

## 4. What Kolo Is NOT

- Not a fintech / neobank — no money movement, no transfers
- Not a payment app — no Paystack, Flutterwave, VTPass integrations (v1)
- Not a loan or investment platform
- Not a social app or public finance feed — v1 sharing is limited to trusted partner visibility

---

## 5. Feature Specification

### 5.1 Authentication
- Email + password via Firebase Auth
- Google Sign-In
- Biometric unlock (fingerprint) after first login
- Onboarding flow on first launch (see User Flow doc)

---

### 5.2 Wallet & Balance
- Manual wallet — user sets their current real balance on setup
- Balance updates automatically when SMS/notification transactions are parsed
- User can also manually adjust balance at any time with a note
- Balance is the single source of truth for all AI decisions
- Supports Nigerian Naira (₦) only in v1

---

### 5.3 Transaction Engine

#### 5.3.1 SMS Listener
- Background service reads incoming SMS in real time
- Parses Nigerian bank SMS formats:
  - GTBank, Access Bank, First Bank, Zenith, UBA, Stanbic, Polaris
- Extracts: amount, type (debit/credit), merchant/sender, date, balance
- Logs parsed transaction automatically to Firestore
- Triggers floating bubble notification

#### 5.3.2 Notification Listener
- Android NotificationListenerService
- Monitors push notifications from user-selected apps
- Supported apps: Kuda, Opay, Palmpay, Moniepoint, Carbon, Fairmoney
- Parses notification content for transaction data
- Same extraction logic as SMS: amount, type, merchant, date

#### 5.3.3 Manual Transaction Logging
- Fallback for when auto-detection misses something
- Quick log from home screen or bubble
- Fields: amount, type (income/expense), category, note
- Category auto-suggested by AI based on description

#### 5.3.4 Transaction Categories
- Food & Snacks
- Transport
- Data & Airtime
- Entertainment
- Utilities & Bills
- Gig Income
- Family/Gift Income
- Savings
- Miscellaneous
- AI assigns category automatically, user can override

---

### 5.4 App Watcher
- User selects which apps to monitor from a list of installed apps
- Filtered to show only banking/fintech apps by default
- When user opens a watched app:
  - Floating bubble appears immediately
  - Kolo AI greets user and checks in: current balance, recent spending context
  - User can dismiss or engage with AI before proceeding
- Uses Android AccessibilityService to detect foreground app changes

---

### 5.5 Floating Bubble (Kolo Overlay)

The signature Kolo experience. A persistent floating bubble that lives on top of all other apps.

**Trigger conditions:**
- Incoming transaction SMS detected
- Notification from watched app detected
- User opens a watched banking app
- User manually taps bubble

**Bubble states:**
- **Idle:** Small avatar bubble, draggable, stays on screen edge
- **Alert:** Pulses/animates when triggered, shows badge
- **Expanded:** Full chat interface slides up (bottom sheet style) over current app

**Expanded bubble features:**
- Shows Kolo AI message at top
- Chat input for user response
- Quick action buttons (Dismiss, Log it, Tell me more)
- Current balance shown in header
- Does not close the app underneath

**Permissions required:**
- `SYSTEM_ALERT_WINDOW` — overlay on other apps
- `BIND_NOTIFICATION_LISTENER_SERVICE` — read notifications
- `RECEIVE_SMS` + `READ_SMS` — read bank SMS
- `BIND_ACCESSIBILITY_SERVICE` — detect app switches
- `FOREGROUND_SERVICE` — keep background service alive

---

### 5.6 Kolo AI — The Fund Manager

The core intelligence of the app. Powered by Google Gemini through a direct Flutter/Dio REST adapter while the Firebase project is on Spark, with a Cloud Functions adapter retained for future Blaze deployment.

#### 5.6.1 Onboarding Conversation
On first launch, Kolo AI has a setup conversation:
- Asks about income sources and frequency
- Asks about monthly/weekly goals
- Asks about current financial situation
- Asks what they want to save for
- Generates an initial budget from the conversation
- Stores budget + context in Firestore

#### 5.6.2 Budget Generation
AI creates a budget based on conversation. Structure:
```
{
  monthlyIncome: estimated (could be range),
  incomeType: "irregular",
  categories: [
    { name, emoji, allocatedAmount, priority }
  ],
  savingsTarget: amount or percentage,
  savingsGoal: string description,
  aiNotes: string (AI's reasoning)
}
```
Budget is regenerated whenever user requests it or income pattern changes significantly.

#### 5.6.3 Spending Context
Every AI call includes full context:
- Current balance
- Budget plan
- All transactions for current period
- Spending per category vs budget
- Days since last income
- Time of day / day of week patterns

#### 5.6.4 Intervention Mode
When user opens a watched app or is about to transact:
- AI checks current financial state
- Crafts a context-aware opening message
- Examples:
  - "You've spent ₦6,400 on food this week, you budgeted ₦5,000. What are you about to do?"
  - "Your balance is ₦2,100, your data renewal is due in 3 days. Be careful."
  - "You just got ₦5k from your dad. Want me to plan it before you touch it?"

#### 5.6.5 Spending Justification
When user wants to log a large or over-budget expense:
- AI prompts user to explain
- User types justification in chat
- AI evaluates against budget and context
- AI responds with: Approved / Caution / Advised Against
- Logs AI decision with transaction for history

#### 5.6.6 Pattern Recognition
Over time AI notices:
- "You spend a lot on food late at night"
- "You haven't had gig income in 6 weeks"
- "You always overspend the week after you get paid"
- Surfaces these as weekly insights

#### 5.6.7 Ongoing Chat
- User can open AI chat anytime
- Ask "can I afford this?"
- Ask for budget adjustments
- Ask for weekly summary
- Ask for savings advice
- AI always responds with full financial context in mind

---

### 5.7 Budget & Analytics

- **Budget Overview:** Category cards with allocated vs spent, progress bars
- **Analytics screen:** Donut chart (earned, spent, available, savings), weekly bar chart
- **Period toggle:** Weekly / Monthly view
- **Income vs Expense toggle** on transactions screen
- **Budget editing:** User can adjust category limits manually or ask AI to re-plan

---

### 5.8 Savings Vaults

- User creates named savings goals (e.g. "New Phone", "Emergency Fund")
- Sets target amount
- AI mentally locks funds — warns user when spending would dip into vault
- User can contribute to vault manually
- Vault progress shown on home screen
- AI celebrates milestones

---

### 5.9 Owings Tracker

- Log money you lent to someone: name, amount, date, optional note
- Log money you owe someone: name, amount, due date
- Kolo AI reminds you when debts are overdue
- AI helps draft a message to collect from someone ("Send reminder")
- Total net owed shown on home screen

---

### 5.10 Gig Tracker

- Separate income category for freelance/gig work
- Log each gig: client name, amount, date received, project type
- AI tracks gig income trends
- Nudges user when it's been a long time since last gig
- Shows total gig earnings for the month/year

---

### 5.11 Bill Reminders

- User logs recurring bills: name, amount, frequency, due date
- Kolo reminds before due date (3 days, 1 day)
- Bills deducted from budget automatically when due date passes
- Upcoming bills shown on home screen

---

### 5.12 Partner Sharing

- User can invite one trusted partner to view selected financial summaries
- Sharing is opt-in per area: balance summary, budgets, vault goals, owings, bills, and weekly insights
- Partner cannot move money, edit transactions, or change budgets unless explicitly granted permission
- User can revoke access at any time
- Kolo can generate partner-friendly summaries without exposing sensitive transaction details by default

---

## 6. Firebase Architecture

### Firestore Collections
```
users/{uid}
  - profile: {name, email, createdAt, onboardingComplete}
  - balance: number
  - budgetPlan: {...}
  - watchedApps: [packageNames]

users/{uid}/transactions/{txId}
  - amount, type, category, description, source (sms/notification/manual)
  - date, merchantName, aiApproved, aiNote

users/{uid}/aiMessages/{msgId}
  - role (user/assistant), content, timestamp, context (intervention/chat/onboarding)

users/{uid}/vaults/{vaultId}
  - name, targetAmount, currentAmount, createdAt

users/{uid}/owings/{owingId}
  - type (lent/owe), person, amount, date, settled, note

users/{uid}/gigs/{gigId}
  - client, amount, date, projectType, note

users/{uid}/bills/{billId}
  - name, amount, frequency, nextDue, active

users/{uid}/partnerShares/{shareId}
  - partnerEmail, status, permissions, createdAt, revokedAt
```

### AI Adapter
- Direct Flutter/Dio Gemini REST adapter reads `GEMINI_API_KEY` from `--dart-define`
- Firebase Cloud Functions versions remain available in code for a later Blaze-plan migration
- `chatWithKolo`, `generateBudget`, `categorizeTransaction`, `evaluateSpendingJustification`, `analyzeSpending`, `draftReminder`, and `interventionMessage` call Gemini from Flutter on Spark
- SMS events use local parsing first, then the direct Gemini categorizer when needed

---

## 7. Technical Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter (Dart) |
| State Management | Riverpod |
| Backend | Firebase (Firestore, Auth) |
| AI | Google Gemini REST via Flutter/Dio; optional Firebase Functions adapter later |
| Local Storage | Hive (for offline cache) |
| Background Services | flutter_background_service |
| Overlay | flutter_overlay_window |
| SMS | Native Android SMS receiver + Flutter service boundary |
| Notifications | notification_listener_service |
| Accessibility | Custom platform channel (Android) |
| Charts | fl_chart |
| Animations | flutter_animate |

---

## 8. Permissions (Android)

```xml
SYSTEM_ALERT_WINDOW
RECEIVE_SMS
READ_SMS
BIND_NOTIFICATION_LISTENER_SERVICE
BIND_ACCESSIBILITY_SERVICE
FOREGROUND_SERVICE
FOREGROUND_SERVICE_DATA_SYNC
RECEIVE_BOOT_COMPLETED
INTERNET
```

---

## 9. Launch Scope (v1.0)

All planned Kolo features are launch scope for v1.0.

Must have for launch:
- [ ] Auth + onboarding
- [ ] Manual balance + transaction logging
- [ ] SMS auto-detection (top 5 Nigerian banks)
- [ ] Notification listener
- [ ] App watcher (AccessibilityService)
- [ ] Floating bubble
- [ ] Kolo AI chat (onboarding + ongoing)
- [ ] Budget generation
- [ ] Home dashboard
- [ ] Transactions screen
- [ ] Analytics screen
- [ ] Savings vaults (basic)
- [ ] Owings tracker
- [ ] Gig tracker
- [ ] Bill reminders
- [ ] Pattern insights
- [ ] Partner sharing

---

## 10. Success Metrics (Personal Use)

- Balance accuracy within ±5% of real balance at all times
- AI correctly categorizes >85% of SMS transactions
- User opens AI chat at least 3x per week
- Savings vault funded consistently
- Snack/impulse spending reduced month over month
