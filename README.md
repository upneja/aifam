# AiFam

An iOS family productivity app that acts as a personal secretary — surfacing what matters across your calendar, contacts, tasks, and health, then letting you talk to it naturally.

## What It Does

AiFam ingests data from the native iOS sources you already use (Calendar, Contacts, Reminders, HealthKit) and maintains a unified **Binder** — a structured store of upcoming events, tasks, important dates, and notes. Every session opens with an AI-generated **briefing** that prioritises what needs attention, presented in the tone you prefer: casual, standard, or professional.

The **chat interface** lets you file things by conversation. Tell the app what's on your mind and it extracts actionable items — deadlines, appointments, special dates — and routes them into the correct Binder category automatically. A **home screen widget** surfaces the current briefing without opening the app.

Key capabilities:

- **AI secretary chat** — natural language intake powered by Claude (claude-sonnet-4-6); extracts and categorises calendar events, tasks, dates, and notes from free text
- **Contextual briefings** — insight engine detects calendar conflicts, overdue tasks, upcoming birthdays with no plan, busy days, and sleep quality; rendered per-tone
- **Data ingestion** — EventKit (with conflict detection), Contacts (birthday + relationship graph), Reminders, HealthKit (sleep stages, steps), CoreLocation
- **Background sync** — BGAppRefreshTask (15-min delta sync) and BGProcessingTask (overnight full sync on charger)
- **WidgetKit extension** — timeline-based widget that reads briefing data from a shared App Group container
- **Onboarding flow** — progressive permission cascade, 4-year historical calendar import

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    iOS App (SwiftUI 6)               │
│                                                     │
│  Views              Services              Models    │
│  ──────             ────────             ──────     │
│  ChatView           SecretaryService     BinderItem │
│  BinderHomeView     BriefingGenerator    Briefing   │
│  BriefingCardView   InsightEngine        ChatMessage│
│  OnboardingFlow     DataSyncCoordinator  UserProfile│
│                     CalendarIngestion               │
│                     ContactsIngestion               │
│                     HealthIngestion                 │
│                     RemindersIngestion              │
│                                                     │
│  ┌────────────────────────────────────────────────┐ │
│  │  SwiftData persistence (BinderItem, ChatMessage,│ │
│  │  UserProfile) + App Group shared container     │ │
│  └────────────────────────────────────────────────┘ │
└─────────────────────────────┬───────────────────────┘
                              │ HTTPS / JSON
                              ▼
┌─────────────────────────────────────────────────────┐
│                FastAPI Backend (Python 3.11)         │
│                                                     │
│  POST /chat                                         │
│    └─ SecretaryService                              │
│         └─ Anthropic SDK  ──►  Claude API           │
│              (structured JSON response)             │
│                                                     │
│  GET  /health                                       │
└─────────────────────────────────────────────────────┘
                              │
              ┌───────────────┘
              │
┌─────────────────────────────┐
│  WidgetKit Extension        │
│  AIFamWidget                │
│  ──────────────────────     │
│  BriefingTimelineProvider   │
│  BriefingWidgetView         │
│  Reads from App Group       │
└─────────────────────────────┘
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| iOS frontend | SwiftUI 6.0, Swift 6 strict concurrency |
| Persistence | SwiftData (ModelContainer, @Model, FetchDescriptor) |
| Widgets | WidgetKit, App Groups shared container |
| System integrations | EventKit, Contacts, HealthKit, CoreLocation, BackgroundTasks, NaturalLanguage, UserNotifications |
| Backend | FastAPI 0.115+, Python 3.11, Uvicorn |
| AI | Anthropic SDK (`anthropic` >= 0.52), claude-sonnet-4-6 |
| Validation | Pydantic v2, pydantic-settings |
| Dev tooling | Ruff (linting), pytest, XcodeGen (project.yml) |

---

## Project Structure

```
aifam/
├── AIFam/                    # iOS app source
│   ├── AIFamApp.swift        # App entry point, SwiftData container
│   ├── Views/
│   │   ├── Chat/             # Chat UI + view model
│   │   ├── Binder/           # Binder home, detail, briefing card
│   │   └── Onboarding/       # Permission cascade, welcome flow
│   ├── Models/               # SwiftData models + value types
│   ├── Services/             # All service layer logic
│   └── Theme/                # Design tokens, typography
├── AIFamWidget/              # WidgetKit extension
│   ├── BriefingTimelineProvider.swift
│   └── BriefingWidgetView.swift
├── backend/                  # FastAPI service
│   ├── app/
│   │   ├── main.py           # FastAPI app, router registration
│   │   ├── config.py         # pydantic-settings (reads .env)
│   │   ├── routes/chat.py    # POST /chat endpoint
│   │   ├── services/secretary.py  # Claude integration + prompt
│   │   └── models/schemas.py # Pydantic request/response models
│   ├── tests/
│   └── pyproject.toml
├── docs/                     # App Store publishing notes
└── project.yml               # XcodeGen configuration
```

---

## Running Locally

### Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env          # add your ANTHROPIC_API_KEY
uvicorn app.main:app --reload
```

The API will be at `http://localhost:8000`. Docs at `/docs`.

### iOS App

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Run `xcodegen generate` from the project root to produce `AIFam.xcodeproj`
3. Open in Xcode 16.3+, set a development team, and run on device (iOS 26+)

> The app requires a physical device for HealthKit, Contacts, and background tasks. The backend URL is configured in `AIFam/Services/APIClient.swift`.

---

## Environment Variables

| Variable | Description |
|---|---|
| `ANTHROPIC_API_KEY` | Claude API key (required) |
| `DATABASE_URL` | SQLite path, defaults to `sqlite:///./aifam.db` |
| `ENVIRONMENT` | `development` or `production` |

Never commit `.env` — use `.env.example` as the template.
