# AI Fam — Plan 1: Foundation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up the Xcode project, core data models, navigation shell, and backend API scaffold so all subsequent plans have a working foundation to build on.

**Architecture:** SwiftUI app with MVVM architecture. The iOS app handles all UI and on-device ML. A lightweight backend API (FastAPI on Railway) handles Claude API calls and persists the context graph. Communication via REST with JSON payloads. Local persistence via SwiftData for offline-first behavior.

**Tech Stack:** Swift 6.2, SwiftUI, SwiftData, iOS 26 SDK, FastAPI, PostgreSQL, Anthropic SDK (Python), Railway

---

## File Structure

### iOS App (`AIFam/`)

```
AIFam/
├── AIFamApp.swift                    # App entry point, scene setup
├── Info.plist                        # Privacy usage descriptions
├── Models/
│   ├── BinderItem.swift              # Core data model for all binder entries
│   ├── BinderCategory.swift          # Enum: calendar, tasks, dates, notes
│   ├── TonePreset.swift              # Enum: casual, default, professional
│   ├── ChatMessage.swift             # Chat message model
│   └── UserProfile.swift             # User preferences and onboarding state
├── Services/
│   ├── APIClient.swift               # HTTP client for backend communication
│   └── SecretaryService.swift        # Orchestrates chat → filing → binder updates
├── Views/
│   ├── AppShell.swift                # Tab bar navigation container
│   ├── Binder/
│   │   └── BinderHomeView.swift      # Daily briefing + category cards (stub)
│   ├── Chat/
│   │   └── ChatView.swift            # Scratchpad chat interface (stub)
│   └── Settings/
│       └── SettingsView.swift        # Tone preset picker + permissions (stub)
├── Theme/
│   ├── Colors.swift                  # Brand colors (gold, pastels, system)
│   └── Typography.swift              # SF Pro configuration
└── Preview Content/
    └── PreviewData.swift             # Sample data for Xcode previews
```

### Backend API (`backend/`)

```
backend/
├── pyproject.toml                    # Python project config (FastAPI, anthropic, etc.)
├── app/
│   ├── main.py                       # FastAPI app entry point
│   ├── config.py                     # Environment config (API keys, DB URL)
│   ├── routes/
│   │   ├── chat.py                   # POST /chat — send message, get response + filing
│   │   └── health.py                 # GET /health — healthcheck
│   ├── services/
│   │   └── secretary.py              # Claude API integration + filing logic
│   └── models/
│       ├── schemas.py                # Pydantic request/response models
│       └── database.py               # SQLAlchemy + PostgreSQL setup
└── tests/
    ├── test_chat.py                  # Chat endpoint tests
    └── test_secretary.py             # Secretary service tests
```

---

### Task 1: Create Xcode Project

**Files:**
- Create: `AIFam.xcodeproj` (via Xcode)
- Create: `AIFam/AIFamApp.swift`
- Create: `AIFam/Info.plist`

- [ ] **Step 1: Create the Xcode project**

Open Xcode → File → New → Project → App.
- Product Name: `AIFam`
- Team: (your team)
- Organization Identifier: `com.aifam`
- Interface: SwiftUI
- Language: Swift
- Storage: SwiftData
- Minimum Deployment: iOS 26.0

Save to `/Users/upneja/Projects/aifam/`.

- [ ] **Step 2: Configure Info.plist privacy descriptions**

Add these keys to `AIFam/Info.plist` (via Xcode target → Info tab → Custom iOS Target Properties):

```xml
<key>NSCalendarsFullAccessUsageDescription</key>
<string>See your schedule and catch conflicts before they happen.</string>
<key>NSRemindersFullAccessUsageDescription</key>
<string>Track what's on your plate and surface overdue items.</string>
<key>NSContactsUsageDescription</key>
<string>Know your people and never miss a birthday.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Learn your routine to give you context-aware briefings.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Detect when you're home, at work, or on the go for smarter briefings.</string>
<key>NSHealthShareUsageDescription</key>
<string>Factor in your sleep and wellness for daily recommendations.</string>
<key>NSUserTrackingUsageDescription</key>
<string>AI Fam never tracks you across apps.</string>
```

- [ ] **Step 3: Build and run on simulator to verify project compiles**

Run: Build via XcodeBuildMCP or `xcodebuild -scheme AIFam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED, blank SwiftUI "Hello, world!" app launches.

- [ ] **Step 4: Initialize git repo and commit**

```bash
cd /Users/upneja/Projects/aifam
git init
echo '.DS_Store\n*.xcuserdata\n.build/\n.swiftpm/\n.superpowers/\nbackend/.venv/\nbackend/__pycache__/\n.env' > .gitignore
git add .
git commit -m "feat: initialize Xcode project with privacy descriptions"
```

---

### Task 2: Define Brand Theme

**Files:**
- Create: `AIFam/Theme/Colors.swift`
- Create: `AIFam/Theme/Typography.swift`

- [ ] **Step 1: Write Colors.swift**

```swift
import SwiftUI

enum AppColors {
    // Secretary brand
    static let gold = Color(red: 0.72, green: 0.59, blue: 0.31)         // #b8964e
    static let goldLight = Color(red: 0.98, green: 0.96, blue: 0.93)    // #f9f5ee

    // Category colors
    static let calendar = Color(red: 0.20, green: 0.66, blue: 0.33)     // #34a853
    static let calendarBg = Color(red: 0.91, green: 0.96, blue: 0.95)   // #e8f5f3
    static let tasks = Color(red: 0.79, green: 0.53, blue: 0.04)        // #c9860a
    static let tasksBg = Color(red: 1.00, green: 0.95, blue: 0.89)      // #fef3e2
    static let dates = Color(red: 0.84, green: 0.19, blue: 0.19)        // #d63031
    static let datesBg = Color(red: 0.99, green: 0.91, blue: 0.91)      // #fde8e8
    static let notes = Color(red: 0.49, green: 0.23, blue: 0.93)        // #7c3aed
    static let notesBg = Color(red: 0.93, green: 0.91, blue: 0.96)      // #ede8f5

    // System
    static let background = Color(uiColor: .systemGroupedBackground)     // #f2f2f7
    static let cardBackground = Color(uiColor: .systemBackground)        // #ffffff
    static let primaryText = Color(uiColor: .label)                      // #1c1c1e
    static let secondaryText = Color(uiColor: .secondaryLabel)           // #8e8e93
}
```

- [ ] **Step 2: Write Typography.swift**

```swift
import SwiftUI

enum AppTypography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let title = Font.system(size: 28, weight: .bold, design: .default)
    static let title2 = Font.system(size: 22, weight: .bold, design: .default)
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let callout = Font.system(size: 15, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 13, weight: .regular, design: .default)
    static let footnote = Font.system(size: 12, weight: .regular, design: .default)
    static let caption = Font.system(size: 11, weight: .semibold, design: .default)

    static let categoryLabel = Font.system(size: 11, weight: .semibold, design: .default)
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme AIFam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add AIFam/Theme/
git commit -m "feat: add brand colors and typography"
```

---

### Task 3: Define Core Data Models

**Files:**
- Create: `AIFam/Models/BinderCategory.swift`
- Create: `AIFam/Models/TonePreset.swift`
- Create: `AIFam/Models/BinderItem.swift`
- Create: `AIFam/Models/ChatMessage.swift`
- Create: `AIFam/Models/UserProfile.swift`

- [ ] **Step 1: Write BinderCategory.swift**

```swift
import SwiftUI

enum BinderCategory: String, Codable, CaseIterable, Identifiable {
    case calendar
    case tasks
    case dates
    case notes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .calendar: "Calendar"
        case .tasks: "Tasks"
        case .dates: "Dates"
        case .notes: "Notes"
        }
    }

    var color: Color {
        switch self {
        case .calendar: AppColors.calendar
        case .tasks: AppColors.tasks
        case .dates: AppColors.dates
        case .notes: AppColors.notes
        }
    }

    var backgroundColor: Color {
        switch self {
        case .calendar: AppColors.calendarBg
        case .tasks: AppColors.tasksBg
        case .dates: AppColors.datesBg
        case .notes: AppColors.notesBg
        }
    }

    var icon: String {
        switch self {
        case .calendar: "calendar"
        case .tasks: "checklist"
        case .dates: "gift"
        case .notes: "doc.text"
        }
    }
}
```

- [ ] **Step 2: Write TonePreset.swift**

```swift
import Foundation

enum TonePreset: String, Codable, CaseIterable, Identifiable {
    case casual
    case standard
    case professional

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .casual: "Casual"
        case .standard: "Default"
        case .professional: "Professional"
        }
    }

    var description: String {
        switch self {
        case .casual: "Your organized roommate who actually has it together"
        case .standard: "Friendly and clear, like a great assistant"
        case .professional: "The executive assistant you wish you could afford"
        }
    }

    var systemPromptFragment: String {
        switch self {
        case .casual:
            "You speak casually like a close friend. Use lowercase, contractions, and informal language. Be direct and a little playful. Example: 'yo heads up — sarah's bday is in 4 days and you haven't planned anything yet.'"
        case .standard:
            "You speak in a friendly, clear tone. Warm but not overly casual. Like a trusted assistant who genuinely cares. Example: 'Sarah's birthday is in 4 days. No plans yet — want me to look into options?'"
        case .professional:
            "You speak formally and efficiently. Precise language, no contractions, structured responses. Like a top-tier executive assistant. Example: 'Reminder: Sarah's birthday dinner is April 12th. Reservations have not been made.'"
        }
    }
}
```

- [ ] **Step 3: Write BinderItem.swift**

```swift
import Foundation
import SwiftData

@Model
final class BinderItem {
    var id: UUID
    var title: String
    var detail: String
    var category: BinderCategory
    var dueDate: Date?
    var isCompleted: Bool
    var urgencyDays: Int?
    var relatedNotes: [String]
    var source: String
    var createdAt: Date
    var updatedAt: Date

    init(
        title: String,
        detail: String = "",
        category: BinderCategory,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        urgencyDays: Int? = nil,
        relatedNotes: [String] = [],
        source: String = "chat"
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.category = category
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.urgencyDays = urgencyDays
        self.relatedNotes = relatedNotes
        self.source = source
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

- [ ] **Step 4: Write ChatMessage.swift**

```swift
import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID
    var content: String
    var isUser: Bool
    var filedCategories: [BinderCategory]
    var createdAt: Date

    init(content: String, isUser: Bool, filedCategories: [BinderCategory] = []) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.filedCategories = filedCategories
        self.createdAt = Date()
    }
}
```

- [ ] **Step 5: Write UserProfile.swift**

```swift
import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var tonePreset: TonePreset
    var hasCompletedOnboarding: Bool
    var grantedPermissions: [String]
    var createdAt: Date

    init(name: String = "", tonePreset: TonePreset = .standard) {
        self.id = UUID()
        self.name = name
        self.tonePreset = tonePreset
        self.hasCompletedOnboarding = false
        self.grantedPermissions = []
        self.createdAt = Date()
    }
}
```

- [ ] **Step 6: Build to verify models compile**

Run: `xcodebuild -scheme AIFam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add AIFam/Models/
git commit -m "feat: add core data models — BinderItem, ChatMessage, UserProfile"
```

---

### Task 4: Build Navigation Shell

**Files:**
- Create: `AIFam/Views/AppShell.swift`
- Create: `AIFam/Views/Binder/BinderHomeView.swift`
- Create: `AIFam/Views/Chat/ChatView.swift`
- Create: `AIFam/Views/Settings/SettingsView.swift`
- Modify: `AIFam/AIFamApp.swift`

- [ ] **Step 1: Write AppShell.swift**

```swift
import SwiftUI

struct AppShell: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Binder", systemImage: "book.closed.fill", value: 0) {
                BinderHomeView()
            }
            Tab("Chat", systemImage: "bubble.left.fill", value: 1) {
                ChatView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: 2) {
                SettingsView()
            }
        }
        .tint(AppColors.gold)
    }
}
```

- [ ] **Step 2: Write stub BinderHomeView.swift**

```swift
import SwiftUI

struct BinderHomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Good morning.")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.primaryText)

                    Text("Your binder is empty. Start chatting to fill it up.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.secondaryText)
                }
                .padding()
            }
            .background(AppColors.background)
        }
    }
}
```

- [ ] **Step 3: Write stub ChatView.swift**

```swift
import SwiftUI

struct ChatView: View {
    @State private var messageText = ""

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                HStack(spacing: 12) {
                    TextField("Talk to your secretary...", text: $messageText)
                        .padding(12)
                        .background(AppColors.background)
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                    Button(action: {}) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                }
                .padding()
            }
            .navigationTitle("Chat")
        }
    }
}
```

- [ ] **Step 4: Write stub SettingsView.swift**

```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Tone") {
                    Text("Default")
                }
                Section("Permissions") {
                    Text("Manage permissions")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

- [ ] **Step 5: Update AIFamApp.swift to use AppShell**

```swift
import SwiftUI
import SwiftData

@main
struct AIFamApp: App {
    var body: some Scene {
        WindowGroup {
            AppShell()
        }
        .modelContainer(for: [BinderItem.self, ChatMessage.self, UserProfile.self])
    }
}
```

- [ ] **Step 6: Build and run on simulator**

Run: Build and run via XcodeBuildMCP on iPhone 17 Pro simulator.
Expected: App launches with a tab bar (Binder, Chat, Settings). Each tab shows its stub content. Gold tint on tab bar.

- [ ] **Step 7: Commit**

```bash
git add AIFam/Views/ AIFam/AIFamApp.swift
git commit -m "feat: add navigation shell with tab bar — binder, chat, settings stubs"
```

---

### Task 5: Build Preview Data

**Files:**
- Create: `AIFam/Preview Content/PreviewData.swift`

- [ ] **Step 1: Write PreviewData.swift**

```swift
import Foundation

enum PreviewData {
    static let binderItems: [BinderItem] = [
        BinderItem(
            title: "Sarah's Birthday Dinner",
            detail: "April 12 · Downtown · 8 people",
            category: .dates,
            dueDate: Calendar.current.date(byAdding: .day, value: 4, to: Date()),
            urgencyDays: 4,
            relatedNotes: ["3 restaurant options saved"],
            source: "chat"
        ),
        BinderItem(
            title: "Lease Renewal Due",
            detail: "April 30 · Reminder set for April 25",
            category: .tasks,
            dueDate: Calendar.current.date(byAdding: .day, value: 22, to: Date()),
            urgencyDays: 22,
            source: "chat"
        ),
        BinderItem(
            title: "Mom's Birthday",
            detail: "April 16 · From contacts",
            category: .dates,
            dueDate: Calendar.current.date(byAdding: .day, value: 8, to: Date()),
            urgencyDays: 8,
            relatedNotes: ["No gift or plan yet"],
            source: "contacts"
        ),
        BinderItem(
            title: "Team Standup",
            detail: "Daily at 2:30 PM · Conflicts with dentist",
            category: .calendar,
            source: "calendar"
        ),
        BinderItem(
            title: "Coffee pods running low",
            detail: "Last ordered 3 weeks ago",
            category: .tasks,
            source: "chat"
        ),
    ]

    static let chatMessages: [ChatMessage] = [
        ChatMessage(
            content: "hey sarah's bday is april 12 and we're doing dinner downtown for like 8 people. also lease renewal is end of month",
            isUser: true
        ),
        ChatMessage(
            content: "Filed both. Sarah's dinner is in Dates — want me to find restaurant options? Lease renewal is in Tasks with a reminder set for the 25th.",
            isUser: false,
            filedCategories: [.dates, .tasks]
        ),
        ChatMessage(content: "ya find some good spots", isUser: true),
        ChatMessage(
            content: "On it. I'll put options in Notes under \"Sarah's Birthday.\"",
            isUser: false,
            filedCategories: [.notes]
        ),
    ]
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme AIFam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add AIFam/Preview\ Content/
git commit -m "feat: add preview data for Xcode previews"
```

---

### Task 6: Scaffold Backend API

**Files:**
- Create: `backend/pyproject.toml`
- Create: `backend/app/main.py`
- Create: `backend/app/config.py`
- Create: `backend/app/routes/health.py`
- Create: `backend/app/routes/chat.py`
- Create: `backend/app/services/secretary.py`
- Create: `backend/app/models/schemas.py`

- [ ] **Step 1: Write pyproject.toml**

```toml
[project]
name = "aifam-backend"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "fastapi>=0.115.0",
    "uvicorn[standard]>=0.34.0",
    "anthropic>=0.52.0",
    "pydantic>=2.10.0",
    "python-dotenv>=1.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0.0",
    "httpx>=0.28.0",
    "ruff>=0.9.0",
]

[tool.ruff]
target-version = "py311"
line-length = 100
```

- [ ] **Step 2: Write config.py**

```python
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    anthropic_api_key: str = ""
    database_url: str = "sqlite:///./aifam.db"
    environment: str = "development"

    model_config = {"env_file": ".env"}


settings = Settings()
```

- [ ] **Step 3: Write schemas.py**

```python
from pydantic import BaseModel


class ChatRequest(BaseModel):
    message: str
    tone: str = "standard"
    context: list[dict] = []


class FiledItem(BaseModel):
    title: str
    detail: str
    category: str
    due_date: str | None = None
    urgency_days: int | None = None


class ChatResponse(BaseModel):
    reply: str
    filed_items: list[FiledItem]
    filed_categories: list[str]
```

- [ ] **Step 4: Write secretary.py**

```python
import anthropic
from app.config import settings
from app.models.schemas import ChatRequest, ChatResponse, FiledItem

SYSTEM_PROMPT = """You are a personal secretary for the AI Fam app. Your job is to:
1. Respond conversationally to the user
2. Extract any actionable items, dates, tasks, or notes from their message
3. File them into the appropriate category: calendar, tasks, dates, or notes

{tone_instruction}

Respond in JSON with this exact structure:
{{
  "reply": "your conversational response",
  "filed_items": [
    {{
      "title": "short title",
      "detail": "additional context",
      "category": "calendar|tasks|dates|notes",
      "due_date": "YYYY-MM-DD or null",
      "urgency_days": number or null
    }}
  ],
  "filed_categories": ["dates", "tasks"]
}}
"""

TONE_INSTRUCTIONS = {
    "casual": "You speak casually like a close friend. Use lowercase, contractions, informal language. Be direct and playful.",
    "standard": "You speak in a friendly, clear tone. Warm but not overly casual. Like a trusted assistant.",
    "professional": "You speak formally and efficiently. Precise language, no contractions, structured responses.",
}


async def process_message(request: ChatRequest) -> ChatResponse:
    client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)

    tone_instruction = TONE_INSTRUCTIONS.get(request.tone, TONE_INSTRUCTIONS["standard"])
    system = SYSTEM_PROMPT.format(tone_instruction=tone_instruction)

    messages = [{"role": m["role"], "content": m["content"]} for m in request.context]
    messages.append({"role": "user", "content": request.message})

    response = await client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        system=system,
        messages=messages,
    )

    import json

    raw = response.content[0].text
    parsed = json.loads(raw)

    return ChatResponse(
        reply=parsed["reply"],
        filed_items=[FiledItem(**item) for item in parsed.get("filed_items", [])],
        filed_categories=parsed.get("filed_categories", []),
    )
```

- [ ] **Step 5: Write chat.py route**

```python
from fastapi import APIRouter, HTTPException
from app.models.schemas import ChatRequest, ChatResponse
from app.services.secretary import process_message

router = APIRouter()


@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest) -> ChatResponse:
    try:
        return await process_message(request)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

- [ ] **Step 6: Write health.py route**

```python
from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health() -> dict:
    return {"status": "ok", "service": "aifam-backend"}
```

- [ ] **Step 7: Write main.py**

```python
from fastapi import FastAPI
from app.routes import chat, health

app = FastAPI(title="AI Fam Backend", version="0.1.0")

app.include_router(health.router, tags=["health"])
app.include_router(chat.router, tags=["chat"])
```

- [ ] **Step 8: Create .env template**

Create `backend/.env.example`:
```
ANTHROPIC_API_KEY=your-key-here
DATABASE_URL=sqlite:///./aifam.db
ENVIRONMENT=development
```

- [ ] **Step 9: Install dependencies and verify**

```bash
cd /Users/upneja/Projects/aifam/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

- [ ] **Step 10: Run the server and test health endpoint**

```bash
cd /Users/upneja/Projects/aifam/backend
source .venv/bin/activate
uvicorn app.main:app --port 8000 &
sleep 2
curl http://localhost:8000/health
kill %1
```

Expected: `{"status":"ok","service":"aifam-backend"}`

- [ ] **Step 11: Commit**

```bash
cd /Users/upneja/Projects/aifam
git add backend/ .gitignore
git commit -m "feat: scaffold FastAPI backend with chat endpoint and secretary service"
```

---

### Task 7: Build iOS API Client

**Files:**
- Create: `AIFam/Services/APIClient.swift`
- Create: `AIFam/Services/SecretaryService.swift`

- [ ] **Step 1: Write APIClient.swift**

```swift
import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodingFailed(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .requestFailed(let code): "Request failed with status \(code)"
        case .decodingFailed(let error): "Decoding failed: \(error.localizedDescription)"
        case .networkError(let error): "Network error: \(error.localizedDescription)"
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    #if DEBUG
    private let baseURL = "http://localhost:8000"
    #else
    private let baseURL = "https://aifam-api.railway.app"
    #endif

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func post<Request: Encodable, Response: Decodable>(
        path: String,
        body: Request
    ) async throws -> Response {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.requestFailed(statusCode: 0)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
}
```

- [ ] **Step 2: Write SecretaryService.swift**

```swift
import Foundation
import SwiftData

struct ChatRequestDTO: Encodable {
    let message: String
    let tone: String
    let context: [[String: String]]
}

struct FiledItemDTO: Decodable {
    let title: String
    let detail: String
    let category: String
    let due_date: String?
    let urgency_days: Int?
}

struct ChatResponseDTO: Decodable {
    let reply: String
    let filed_items: [FiledItemDTO]
    let filed_categories: [String]
}

@Observable
final class SecretaryService {
    var isProcessing = false

    func sendMessage(
        _ text: String,
        tone: TonePreset,
        recentMessages: [ChatMessage],
        modelContext: ModelContext
    ) async throws -> ChatMessage {
        isProcessing = true
        defer { isProcessing = false }

        let context = recentMessages.suffix(10).map { msg in
            ["role": msg.isUser ? "user" : "assistant", "content": msg.content]
        }

        let request = ChatRequestDTO(
            message: text,
            tone: tone.rawValue,
            context: context
        )

        let response: ChatResponseDTO = try await APIClient.shared.post(
            path: "/chat",
            body: request
        )

        let categories = response.filed_categories.compactMap { BinderCategory(rawValue: $0) }

        // Create binder items from filed items
        for item in response.filed_items {
            guard let category = BinderCategory(rawValue: item.category) else { continue }

            var dueDate: Date?
            if let dateString = item.due_date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                dueDate = formatter.date(from: dateString)
            }

            let binderItem = BinderItem(
                title: item.title,
                detail: item.detail,
                category: category,
                dueDate: dueDate,
                urgencyDays: item.urgency_days,
                source: "chat"
            )
            modelContext.insert(binderItem)
        }

        // Create the assistant message
        let assistantMessage = ChatMessage(
            content: response.reply,
            isUser: false,
            filedCategories: categories
        )
        modelContext.insert(assistantMessage)

        try modelContext.save()

        return assistantMessage
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme AIFam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add AIFam/Services/
git commit -m "feat: add API client and secretary service for chat → binder pipeline"
```

---

### Task 8: Write Backend Tests

**Files:**
- Create: `backend/tests/test_health.py`
- Create: `backend/tests/test_chat.py`

- [ ] **Step 1: Write test_health.py**

```python
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health_returns_ok():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["service"] == "aifam-backend"
```

- [ ] **Step 2: Write test_chat.py**

```python
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient
from app.main import app
from app.models.schemas import ChatResponse, FiledItem

client = TestClient(app)


def test_chat_endpoint_returns_response():
    mock_response = ChatResponse(
        reply="Filed both. Sarah's dinner is in Dates.",
        filed_items=[
            FiledItem(
                title="Sarah's Birthday Dinner",
                detail="April 12 · Downtown · 8 people",
                category="dates",
                due_date="2026-04-12",
                urgency_days=4,
            )
        ],
        filed_categories=["dates"],
    )

    with patch("app.routes.chat.process_message", new_callable=AsyncMock) as mock:
        mock.return_value = mock_response
        response = client.post(
            "/chat",
            json={"message": "sarah's bday is april 12", "tone": "standard", "context": []},
        )

    assert response.status_code == 200
    data = response.json()
    assert data["reply"] == "Filed both. Sarah's dinner is in Dates."
    assert len(data["filed_items"]) == 1
    assert data["filed_items"][0]["category"] == "dates"


def test_chat_endpoint_handles_error():
    with patch("app.routes.chat.process_message", new_callable=AsyncMock) as mock:
        mock.side_effect = Exception("API error")
        response = client.post(
            "/chat",
            json={"message": "test", "tone": "standard", "context": []},
        )

    assert response.status_code == 500
```

- [ ] **Step 3: Run tests**

```bash
cd /Users/upneja/Projects/aifam/backend
source .venv/bin/activate
pytest tests/ -v
```

Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
cd /Users/upneja/Projects/aifam
git add backend/tests/
git commit -m "test: add backend tests for health and chat endpoints"
```

---

## Plan Summary

After completing all 8 tasks, the foundation is in place:

- Xcode project with iOS 26 target, all privacy descriptions configured
- Brand theme (colors, typography) matching the Apple-native design spec
- Core data models (BinderItem, ChatMessage, UserProfile) with SwiftData persistence
- Navigation shell (tab bar: Binder, Chat, Settings) with stub views
- Preview data for Xcode development
- Backend API with FastAPI, Claude integration, and the chat→filing pipeline
- iOS API client connecting the app to the backend
- Backend tests verifying the API contract

Plans 2-5 build on this foundation: data ingestion populates the binder, UI brings the screens to life, intelligence adds the ML layer, and surfaces extend to widgets/Siri/notifications.
