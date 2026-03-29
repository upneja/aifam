# AI Fam — Product Design Spec

## What It Is

A native iOS app that acts as a personal secretary keeping a structured file on your life. Chat is the input (scratchpad), an organized binder is the output. Everything you tell it gets auto-filed into color-coded tabs. Clear the conversation anytime — notes persist.

Not marketed as "AI." Marketed as the smartest organizer you've ever had. Competition is Apple Notes, not other AI apps.

## Core Metaphor

A nostalgic secretary with a physical binder — color-coded tabs, everything filed, always up to date. Inspired by Clippy's cultural rehabilitation (beloved nostalgia + anti-Big-Tech symbol as of 2025-2026). The branding leans into the secretary character: charming, organized, slightly retro.

## Design Language

Apple-native luxury. Light mode. Clean whites, soft pastels, SF Pro typography. Skeuomorphic minimalism — warm gold accent color (#b8964e) for the secretary brand. Feels like Apple made it. No generic AI aesthetics, no purple gradients, no Inter/Roboto.

---

## Core Screens

### 1. The Binder (Home)

The daily briefing. Opens with a personalized greeting and "Today's Briefing" — a prioritized list of things that need attention, surfaced proactively from calendar, contacts, reminders, health, and location data.

Below the briefing: four category cards in a 2x2 grid:
- **Calendar** (green) — event count this week
- **Tasks** (amber) — items needing attention
- **Dates** (red) — upcoming birthdays, anniversaries, deadlines
- **Notes** (purple) — filed items count

Each card taps into its full binder tab view.

### 2. The Scratchpad (Chat)

iMessage-style chat interface. User messages in blue bubbles (right), secretary responses in gray bubbles (left). The secretary responds conversationally and inline-tags where things got filed using colored chips (e.g., `Dates`, `Tasks`, `Notes`).

Voice input via microphone button. The secretary processes natural language — "hey sarah's bday is april 12 and we're doing dinner downtown for 8 people" becomes a structured Dates entry with restaurant research queued in Notes.

Bottom: text input field + mic button. No complex toolbars.

### 3. Binder Tabs (Detail Views)

Each tab (Calendar, Tasks, Dates, Notes) has its own structured view:
- **Dates:** List of tracked events with countdown badges (urgent red, soon amber), cross-references to related notes, proactive warnings ("No gift or plan yet").
- **Tasks:** Priority-sorted, overdue items surfaced first, completion tracking.
- **Calendar:** Week view with conflict detection, attendee context.
- **Notes:** Organized by topic, auto-categorized from chat, searchable.

### 4. Home Screen Widget (WidgetKit)

Medium or large widget showing the daily briefing: greeting, top 3 items needing attention, key stats (events today, sleep last night). Interactive buttons (iOS 17+) for quick actions. Refreshes ~40-70x/day via timeline.

### 5. Siri Integration (App Intents)

"Hey Siri, morning briefing from AI Fam" returns a spoken + visual summary. Registered as App Shortcuts — appears in Spotlight and Shortcuts app with zero user setup.

---

## Three Tone Presets

Selected during onboarding, changeable in settings.

### Casual
Target: AI-forward users. Voice: your organized roommate who has their shit together.
> "yo heads up — sarah's bday is in 4 days and you haven't planned anything yet. want me to find dinner spots?"

### Default (Primary)
Target: mainstream users who don't use AI much. Voice: friendly and clear, like a great assistant.
> "Sarah's birthday is in 4 days. No plans yet — want me to look into restaurant options for 8 downtown?"

### Professional
Target: AI skeptics hiring a "free employee." Voice: the executive assistant you wish you could afford.
> "Reminder: Sarah's birthday dinner is April 12th. Reservations have not been made. Shall I compile options for a party of 8?"

---

## Onboarding: "It Just Knows"

### Flow (target: 60 seconds total)

**Screen 1 — Welcome:**
Secretary icon + "Meet your secretary. I'll organize your life. But first, I need to look through your files." CTA: "Let me take a look." Subtext: "Everything stays on your device."

**Screen 2 — Permission Cascade:**
Sequential permission requests, each with a custom pre-permission screen showing the benefit, then the system dialog. Real-time checklist shows progress. Order:
1. Calendar — "See your schedule, catch conflicts"
2. Contacts — "Know your people, remember birthdays"
3. Reminders — "Track what's on your plate"
4. Location (When In Use) — "Learn your home, work, routine"
5. Notifications — "Heads up when something matters"
6. Health — "Sleep + wellness awareness"

Each can be skipped. "Skip any — I'll work with what you give me."

**Screen 3 — Building Phase:**
"Building your file..." with live progress bars:
- Reading your calendar... (247 events)
- Mapping your people... (142 contacts)
- Finding patterns... (working)
- Building your briefing...

On-device processing via Apple Foundation Models + Natural Language framework. ~15 seconds.

**Screen 4 — Instant Value:**
"Your file is ready. Here's what I found." Pre-populated briefing with real insights from their data. "Life at a Glance" stats grid. CTA: "Open Your Binder."

### Graceful Degradation

- **Full access (all permissions):** Complete life map. Proactive wellness briefings. Location-aware context. Social graph.
- **Partial (3-4 permissions):** Calendar + Contacts + Reminders = strong core. Schedule management, birthday tracking, task overview.
- **Minimal (1-2 permissions):** Chat scratchpad still works. Manual input + organization. AI still structures everything you tell it.

---

## Data Sources

### Input (iOS Permissions)

| Source | Framework | What We Extract | Key Limitation |
|--------|-----------|----------------|----------------|
| Calendar | EventKit | 4yr history, attendees (social graph), recurrence (routines), structured locations, conflicts | Need `fullAccess` tier (iOS 17+) |
| Contacts | CNContact | Family relations, shared addresses (household), birthdays, organizations | iOS 18 "Limited Access" — may get subset |
| Reminders | EventKit | All lists, due dates, priorities, completion rates | Need `fullAccess` tier |
| Location | CoreLocation (CLVisit) | Home/work/gym detection, commute patterns | Ultra-low battery. ~100m accuracy. Need "Always" for background (progressive upgrade from "When In Use") |
| Health | HealthKit | Sleep stages, steps, heart rate, workouts | Per-type consent. Cannot detect denials. |
| Notifications | UNUserNotificationCenter | Output channel only | Cannot read other apps' notifications |

### On-Device Intelligence (iOS 26)

- **Apple Foundation Models** (~3B param on-device LLM): Structured entity extraction via `@Generable` macros. Extract people, dates, commitments, action items from natural language. Zero API cost, full privacy.
- **Vision Framework**: OCR on screenshots (VNRecognizeTextRequest). Extract text from chat screenshots, receipts, documents.
- **Natural Language Framework**: Named entity recognition (people, places, orgs). Sentiment analysis. Fast, lightweight, no model loading.
- **Core ML**: Custom embedding models for context graph vector representations.

### Context Graph

Built using Graphiti (open-source temporal knowledge graph by Zep):
- Episode subgraph: raw events/messages with timestamps
- Semantic entity subgraph: extracted entities in 1024-dim embedding space
- Community subgraph: clustered strongly-connected entities
- Bi-temporal modeling: tracks how facts change over time

### Background Processing

- **BGAppRefreshTask**: Light delta syncs (~30 sec, system-scheduled, ~15min-hours apart)
- **BGProcessingTask**: Heavy graph building overnight (1-10 min, prefers charging)
- **BGContinuedProcessingTask** (iOS 26): Extended runtime for first-launch processing with system progress UI
- **HealthKit Background Delivery**: Event-driven wakeups when health data changes

---

## Technical Architecture

### iOS App
- **Language:** Swift 6, SwiftUI
- **Min deployment:** iOS 26 (to use Foundation Models framework)
- **Build tooling:** XcodeBuildMCP by Sentry for Claude Code integration

### Backend API
- **Framework:** Next.js API routes or FastAPI (TBD based on complexity)
- **AI:** Anthropic Claude API for chat responses and complex reasoning (on-device Foundation Models handles extraction, Claude handles conversation quality)
- **Database:** PostgreSQL for structured data
- **Context graph:** Graphiti + Neo4j or FalkorDB
- **Hosting:** Railway or Fly.io

### Data Flow
1. User inputs text via chat or grants permission to data source
2. On-device: Foundation Models extracts entities, NL framework does NER
3. Structured entities sent to backend API (encrypted)
4. Backend: Claude API generates conversational response + filing decisions
5. Context graph updated with new entities and relationships
6. Binder tabs updated with new structured data
7. Background: periodic delta syncs from calendar/contacts/reminders, overnight graph recomputation

---

## v1 Scope

### Ships
- Native iOS app (SwiftUI) in App Store
- Binder home with daily briefing
- Chat scratchpad with auto-filing
- Binder tabs: Calendar, Tasks, Dates, Notes
- 3 tone presets (Casual, Default, Professional)
- "It Just Knows" onboarding with permission cascade
- On-device context graph building
- Calendar + Contacts + Reminders integration
- Location-aware context (CLVisit)
- HealthKit wellness briefings
- Push notification briefings
- Home screen widget (WidgetKit)
- Siri integration (App Intents)

### Deferred (v2+)
- Splitwise / financial integrations
- Group chat integration (WhatsApp @mention)
- Household sharing (invite partner/roommates to shared binder)
- Action execution (Amazon reordering, restaurant reservations)
- Photo library intelligence (travel history, OCR on screenshots)
- Android app
- Email integration (Gmail/Outlook via OAuth)
- Monetization

---

## Monetization

None for v1. Free experiment to test product-market fit. Potential future models:
- Freemium (free tier with limited integrations, paid for full binder)
- Subscription for household sharing features
- Premium tone packs or secretary personalities

---

## Success Metrics

- **Activation:** User completes onboarding and views pre-populated binder
- **Retention signal:** Opens binder 3+ times in first week
- **Engagement:** Sends 5+ messages to scratchpad in first week
- **Widget adoption:** Adds home screen widget within 7 days
