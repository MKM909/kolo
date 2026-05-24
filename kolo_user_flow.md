# Kolo — User Flow Document
**Version:** 1.0.0

---

## 1. App Entry Points

Kolo can be entered in three ways:

1. **Direct launch** — user taps app icon
2. **Floating bubble tap** — user taps persistent overlay bubble
3. **Notification tap** — from a Kolo alert notification

---

## 2. First Launch — Onboarding Flow

```
App Opens
    │
    ▼
Splash Screen (Kolo logo, 1.5s)
    │
    ▼
Have account? ──Yes──► Login Screen
    │                       │
    No                      ▼
    │               Email + Password
    ▼               OR Google Sign In
Sign Up Screen              │
    │                       ▼
    │               Biometric Setup (optional)
    ▼                       │
Email + Password            ▼
    │               ────────────────────
    ▼               Goes to Home (returning user)
Verify Email
    │
    ▼
Onboarding — AI Setup Chat (new user only)
    │
    ▼
[Step 1] Kolo introduces itself
    "Hey! I'm Kolo, your personal money manager.
     Before we start, let me get to know your situation."
    │
    ▼
[Step 2] Income question
    "How do you usually get money? 
     (allowance, freelance, family, mix?)"
    User types freely
    │
    ▼
[Step 3] Income frequency
    "Is it regular or does it come when it comes?"
    User types freely
    │
    ▼
[Step 4] Current balance
    "What's your balance right now across all your accounts?
     Just an estimate is fine."
    User enters number
    │
    ▼
[Step 5] Biggest money problem
    "What's your biggest money problem right now?"
    User types freely
    │
    ▼
[Step 6] Savings goal
    "Is there something specific you're saving towards?"
    User types freely or skips
    │
    ▼
AI generates budget plan
    "Okay, based on what you told me here's how 
     I'd suggest splitting your money..."
    Shows generated budget with categories
    │
    ├── User accepts ──► Budget saved to Firestore
    │                        │
    └── User adjusts         ▼
         │             Permission Setup Screen
         ▼             │
      Chat to adjust   ▼
      categories    [Permissions needed]
         │          - SMS access (for auto-detection)
         ▼          - Notification access
      Re-generates  - Overlay permission
                    - Accessibility access (for app watcher)
                         │
                         ├── Grant all ──► Home Screen
                         │
                         └── Skip ──► Home Screen (reduced features, 
                                       prompted again later)
```

---

## 3. Home Screen Flow

```
Home Screen
    │
    ├── Balance card (tap) ──► Balance detail / adjust screen
    │
    ├── Quick Actions
    │       ├── [Log Income] ──► Quick income log sheet
    │       ├── [Log Expense] ──► Quick expense log sheet
    │       ├── [Vaults] ──► Savings Vaults screen
    │       └── [Owings] ──► Owings Tracker screen
    │
    ├── Upcoming bills banner (if any due soon)
    │       └── Tap ──► Bills screen
    │
    ├── Budget Summary card
    │       └── Tap ──► Budget screen
    │
    ├── Recent Transactions list
    │       ├── Tap transaction ──► Transaction detail sheet
    │       └── "View All" ──► Transactions screen
    │
    └── Floating Kolo bubble (always visible)
            └── See Section 5
```

---

## 4. Bottom Navigation

Five tabs:

| Tab | Icon | Screen |
|---|---|---|
| Home | House | Dashboard |
| Transactions | Receipt | Full transaction history |
| Kolo AI | Bubble/Chat | AI fund manager chat |
| Budget | Chart | Budget overview + analytics |
| Profile | Person | Settings + profile |

---

## 5. Floating Bubble Flow

```
Bubble idle (edge of screen, draggable)
    │
    Trigger conditions:
    ├── Incoming bank SMS detected
    ├── Notification from watched app
    ├── User opens watched banking app
    └── User taps bubble manually
    │
    ▼
Bubble pulses / shows badge
    │
    ▼
User taps expanded bubble
    │
    ▼
Overlay chat expands (over current app)
    │
    ├── [Transaction detected]
    │       AI: "GTB just debited ₦2,500. 
    │            That's food category, you're at ₦7,200/₦10,000 
    │            for the month. Noted."
    │       Options: [Got it] [That's wrong category] [Tell me more]
    │
    ├── [Watched app opened]
    │       AI: "You just opened Kuda. 
    │            Your balance is ₦4,800. 
    │            You have ₦2,100 left in spending budget.
    │            What are you about to do?"
    │       User types or selects: [Just checking] [Sending money] [Top up]
    │           │
    │           ├── [Sending money] ──► Justification flow (Section 6)
    │           └── [Just checking] ──► AI gives balance summary, bubble closes
    │
    └── [Manual tap]
            User can ask anything ──► Full AI chat response
```

---

## 6. Spending Justification Flow

```
User about to spend / over budget in category
    │
    ▼
Kolo AI flags it
    "You've already hit your food budget for the week.
     What's this for?"
    │
    ▼
User types explanation
    │
    ▼
AI evaluates (Cloud Function call with full context)
    │
    ├── APPROVED
    │       "Okay, birthday food is valid. 
    │        Just know you're ₦1,200 over food budget now.
    │        I'll tighten food next week."
    │       Transaction logged with AI note: "Approved - special occasion"
    │
    ├── CAUTION
    │       "That's your third snack run today. 
    │        You can afford it but you won't last the week.
    │        Your call."
    │       User: [Do it anyway] or [I'll skip it]
    │
    └── ADVISED AGAINST
            "Your balance is ₦1,400 and your data renews 
             in 2 days for ₦1,000. I wouldn't do this."
            User: [Override] or [You're right, skip]
                │
                └── [Override] ──► Logs with note: "User overrode AI advice"
```

---

## 7. Kolo AI Chat Screen Flow

```
Kolo AI tab
    │
    ▼
Full screen chat interface
    │
    ├── Previous messages loaded from Firestore
    │
    ├── User types message
    │       Examples:
    │       "Can I afford a new pair of shoes?"
    │       "How much have I spent on food this month?"
    │       "Redo my budget, I just got a gig"
    │       "Who owes me money?"
    │
    ▼
Cloud Function → Gemini API (with full context injected)
    │
    ▼
AI responds in chat
    │
    ├── [Budget update requested]
    │       AI generates new budget ──► Shows preview ──► User accepts/adjusts
    │
    ├── [Spending question]
    │       AI answers with exact figures from transaction history
    │
    ├── [Savings advice]
    │       AI recommends vault allocation
    │
    └── [Gig/income related]
            AI acknowledges, updates context, re-plans if needed
```

---

## 8. Transaction Logging Flows

### 8.1 Auto-detected (SMS/Notification)
```
SMS/Notification received
    │
    ▼
Background service parses it
    │
    ▼
Transaction object created:
    {amount, type, merchant, category (AI-assigned), source: "sms"}
    │
    ▼
Logged to Firestore
    │
    ▼
Balance updated
    │
    ▼
Bubble triggered with summary
    │
    ▼ (if category seems wrong)
User can correct category from bubble
```

### 8.2 Manual Log
```
Home ──► "Log Expense" or "Log Income"
    │
    ▼
Quick bottom sheet
    - Amount (number pad)
    - Type: Income / Expense
    - Description (text)
    - Category (AI suggests, user can override)
    - Date (defaults to now)
    │
    ▼
Save ──► Firestore + balance update + AI acknowledgement in bubble
```

---

## 9. Budget Screen Flow

```
Budget tab
    │
    ▼
Budget Overview
    │
    ├── Period toggle: [This Week] [This Month]
    │
    ├── Total budget bar (spent / total)
    │
    ├── Category cards (grid)
    │       Each shows: emoji, name, ₦spent / ₦limit, progress bar
    │       Color: green (safe) → yellow (warning) → red (over)
    │       Tap category ──► Category detail + transaction breakdown
    │
    ├── [Ask Kolo to re-plan] button
    │       ──► Opens AI chat with prompt pre-filled
    │
    └── [Edit budget manually] 
            ──► Editable category list
                User adjusts limits
                Save ──► Updated Firestore budget
```

---

## 10. Analytics Screen Flow

```
Analytics (inside Budget tab or separate)
    │
    ▼
Account selector (if multiple sources tracked)
    │
    ▼
Donut chart
    - Earned (total income this period)
    - Spent (total expenses)
    - Available (balance)
    - Savings (in vaults)
    │
    ▼
Weekly bar chart
    - 7 days, income vs expense bars
    │
    ▼
Budget for period
    - Category breakdown grid
    - Each category: item count + total amount
```

---

## 11. Savings Vaults Flow

```
Home ──► Vaults quick action OR Profile ──► Vaults
    │
    ▼
Vaults list
    - Each vault: name, progress bar, ₦current / ₦target
    │
    ├── Tap vault ──► Vault detail
    │       - Contribution history
    │       - Add funds (manual allocation from balance)
    │       - Edit target
    │       - Delete vault
    │
    └── [+ New Vault]
            - Name
            - Target amount
            - Optional deadline
            - Optional: "Tell Kolo about this" ──► AI acknowledges and 
              will protect these funds in future decisions
```

---

## 12. Owings Tracker Flow

```
Home ──► Owings quick action
    │
    ▼
Owings screen
    │
    ├── Two tabs: [They Owe Me] [I Owe Them]
    │
    ├── Each entry: person name, amount, date, days outstanding
    │
    ├── Tap entry ──► Detail sheet
    │       - [Mark as settled]
    │       - [Send reminder] ──► AI drafts message ──► User copies/sends
    │       - [Edit] [Delete]
    │
    └── [+ Add Owing]
            - Type: I lent / I owe
            - Person name
            - Amount
            - Date
            - Note (optional)
            - Due date (optional)
```

---

## 13. Gig Tracker Flow

```
Home or Profile ──► Gig Tracker
    │
    ▼
Gig dashboard
    │
    ├── Monthly/yearly gig earnings summary
    ├── Recent gigs list
    ├── Trend insight from Kolo
    │       "It's been 18 days since your last gig income."
    │
    └── [+ Log Gig]
            - Client name
            - Amount received
            - Date received
            - Project type
            - Note (optional)
            │
            ▼
        Save ──► Firestore + balance update + budget re-check
```

---

## 14. Bill Reminders Flow

```
Home upcoming bills banner OR Profile ──► Bill Reminders
    │
    ▼
Bills list
    │
    ├── Active recurring bills
    ├── Due soon section
    ├── Tap bill ──► Bill detail
    │       - Edit amount/frequency/date
    │       - Mark as paid
    │       - Pause/delete bill
    │
    └── [+ New Bill]
            - Name
            - Amount
            - Frequency
            - Next due date
            │
            ▼
        Save ──► Firestore + reminder schedule + budget reservation
```

---

## 15. Partner Sharing Flow

```
Profile ──► Partner Sharing
    │
    ▼
Sharing settings
    │
    ├── Invite partner by email
    │       Partner accepts invite
    │       Access saved to Firestore
    │
    ├── Choose shared areas
    │       - Balance summary
    │       - Budget summary
    │       - Vault goals
    │       - Owings
    │       - Bills
    │       - Weekly insights
    │
    ├── Partner view
    │       Read-only by default
    │       Sensitive transaction details hidden unless enabled
    │
    └── Revoke access
            Partner loses access immediately
```

---

## 16. App Watcher Setup Flow

```
Profile ──► Watched Apps
    │
    ▼
List of installed apps (filtered: banking/fintech first)
    │
    ▼
User toggles apps to watch
    │
    ▼
[Enable Accessibility Service] prompt if not granted
    User taken to Android Accessibility settings
    │
    ▼
Saved to Firestore + local
    │
    ▼
From now on: opening any toggled app triggers bubble
```

---

## 17. Permissions Setup Flow

```
First time any permission is needed:
    │
    ▼
Custom explanation screen (before Android system prompt)
    "Kolo needs [X] to [specific benefit]"
    [Grant] ──► Android permission dialog
    [Not now] ──► Feature disabled, reminder shown later
    │
    ▼
If denied:
    Feature shows locked state with "Enable in settings" option
    Non-blocking — rest of app still works
```

---

## 18. Profile & Settings Flow

```
Profile tab
    │
    ├── User info (name, email, avatar)
    ├── Balance adjustment (manual correction)
    ├── Watched Apps ──► Section 16
    ├── Budget Settings ──► Budget screen
    ├── Gig Tracker ──► Section 13
    ├── Bill Reminders ──► Section 14
    ├── Partner Sharing ──► Section 15
    ├── Notification preferences
    ├── AI chat history (view / clear)
    ├── About Kolo
    └── Sign out
```

---

## 19. Error & Edge Case Flows

| Scenario | Handling |
|---|---|
| No internet | App works offline, syncs when back online. AI chat shows "offline" state |
| SMS parsing fails | Transaction flagged as "unrecognized", user prompted to categorize manually |
| AI API fails | Friendly error in chat: "Having trouble thinking right now, try again in a sec" |
| Balance goes negative | Red balance shown, AI sends urgent bubble: "Your balance is in the red, let's talk" |
| Bubble permission revoked | App detects missing permission, prompts user on next open |
| User ignores AI advice 3x in a row | AI adjusts tone, acknowledges pattern: "I notice you've been overriding me a lot, want to adjust the budget instead?" |
