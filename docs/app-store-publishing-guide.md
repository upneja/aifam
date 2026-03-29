# AI Fam — App Store Publishing Guide

Complete checklist to go from "builds on simulator" to "live in the App Store."

---

## MASTER CHECKLIST

### Phase 1: Developer Account (Do This First)
- [ ] Enable two-factor authentication on your Apple Account
- [ ] Enroll in Apple Developer Program ($99/year) at developer.apple.com/programs/enroll
- [ ] Wait for approval (up to 48 hours for individual)
- [ ] Note your Team ID from Membership Details page
- [ ] Personal account is fine for commercial apps — your name shows as "Seller"

### Phase 2: App Configuration
- [ ] Set `DEVELOPMENT_TEAM` in `project.yml` to your Team ID
- [ ] Open Xcode → Settings → Accounts → sign in with Developer account
- [ ] Register Bundle ID `com.aifam.app` in Developer portal with HealthKit + Push Notification capabilities
- [ ] Create 1024x1024 app icon (PNG, no transparency, no rounded corners — Apple applies the squircle)
- [ ] Add icon to Xcode asset catalog

### Phase 3: Compliance (CRITICAL for AI Apps)
- [ ] **Build AI consent screen (Guideline 5.1.2(i))**: Must appear before ANY data leaves the device. Must name "Anthropic" as the AI provider. Must explain what data is sent. Must have explicit Accept/Decline buttons.
- [ ] **Build separate HealthKit consent**: Health data sent to third-party AI gets extra scrutiny. Consider processing health data on-device only.
- [ ] **Write and host privacy policy** covering:
  - All data types collected (calendar, contacts, reminders, location, health, chat text)
  - Third-party AI disclosure naming Anthropic
  - HealthKit data restrictions (never sold, never used for ads, never used for data mining)
  - Data retention policy
  - User rights (access, delete, export)
  - Contact email for privacy inquiries
- [ ] Host privacy policy at a public URL (GitHub Pages, Vercel, Notion public page)
- [ ] Request permissions lazily (when user triggers feature), NOT all at launch

### Phase 4: App Store Connect Setup
- [ ] Go to appstoreconnect.apple.com
- [ ] Create app: name "AI Fam", bundle ID `com.aifam.app`, SKU `aifam-ios-001`
- [ ] Fill metadata:
  - Subtitle: "Your AI-powered life assistant" (max 30 chars)
  - Description: full feature description (max 4000 chars)
  - Keywords: `ai,assistant,calendar,health,reminders,family,planner` (max 100 chars)
  - Primary category: Productivity
  - Secondary category: Health & Fitness
  - Support URL, Privacy Policy URL, Copyright
- [ ] Complete age rating questionnaire (updated 2025 format)
- [ ] Fill privacy nutrition labels for ALL data types:
  - Contact Info, Contacts, Health & Fitness, Location, User Content, Identifiers
  - Purpose: App Functionality
  - Linked to identity: Yes
  - Used for tracking: No
- [ ] Write App Review notes explaining AI features and permissions

### Phase 5: Screenshots
- [ ] iPhone 6.9" screenshots: **1320 x 2868 px** (mandatory, minimum 1, aim for 5-6)
- [ ] iPad 13" screenshots: **2064 x 2752 px** (only if app runs on iPad)
- [ ] Format: PNG or JPEG, RGB, no transparency
- [ ] Must show actual app UI

### Phase 6: Backend Deployment
- [ ] Create Railway account at railway.com
- [ ] Push backend code to GitHub
- [ ] Deploy from GitHub on Railway ("New Project" → "Deploy from GitHub")
- [ ] Add `Procfile`: `web: uvicorn app.main:app --host 0.0.0.0 --port $PORT`
- [ ] Set environment variables in Railway:
  - `ANTHROPIC_API_KEY` = your key
  - `DATABASE_URL` = Railway Postgres or sqlite
  - `ENVIRONMENT` = production
- [ ] Generate Railway domain (free HTTPS at *.up.railway.app)
- [ ] Update iOS `APIClient.swift` production URL to Railway domain
- [ ] Verify: `curl https://your-domain.up.railway.app/health`

### Phase 7: Testing
- [ ] Test on a REAL physical iPhone (not just simulator)
- [ ] Test every permission denial path
- [ ] Test with no network connection
- [ ] Test AI consent flow (accept AND decline)
- [ ] Test onboarding with 0 permissions granted
- [ ] Upload build to TestFlight for internal testing (up to 100 testers, no Apple review needed)
- [ ] Test via TestFlight on multiple devices

### Phase 8: Submit
- [ ] In Xcode: select "Any iOS Device (arm64)" → Product → Archive
- [ ] In Organizer: Distribute App → App Store Connect → Upload
- [ ] Wait for processing email (10-30 minutes)
- [ ] In App Store Connect: select processed build under your version
- [ ] Double-check all metadata, screenshots, privacy labels
- [ ] Submit for Review
- [ ] Wait 24 hours to 7 days (first submission takes longer)

### Phase 9: If Rejected
- 40% of first submissions face delays/rejection
- Check Resolution Center in App Store Connect for specific guideline cited
- Common reasons: vague permission descriptions, missing AI disclosure, crashes, metadata issues
- Fix and resubmit — re-reviews are usually faster (24 hours)
- Can appeal if you think rejection is unfair

---

## COST BREAKDOWN

| Item | Cost | Frequency |
|------|------|-----------|
| Apple Developer Program | $99 | Annual |
| Railway Hobby Plan | $5/month | Monthly |
| Domain (optional) | ~$12 | Annual |
| **Just you + beta testers** | **~$175/year** | |

### Anthropic API Costs (per active user/month)

| Model | Cost/user/month (20 interactions/day) |
|-------|--------------------------------------|
| Claude Haiku 4.5 | ~$1.20 |
| Claude Sonnet 4.6 | ~$5.40 |

At 100 users on Haiku: ~$1,440/year for API. Use prompt caching (90% savings) and model routing to optimize.

---

## KEY COMPLIANCE REQUIREMENTS

### Guideline 5.1.2(i) — Third-Party AI (MUST DO)
- Name Anthropic as the AI provider in your app
- Get explicit opt-in consent BEFORE any data leaves the device
- Allow users to opt out of AI features
- Disclose in privacy policy

### HealthKit Rules
- Never use health data for advertising
- Never sell health data
- Never store health data in iCloud
- Must have a clear health/fitness purpose
- In review notes: explain exactly which health types you read and why

### Permission Descriptions (Must Be Specific)
Apple rejects vague descriptions. Use benefit-focused copy:
- Calendar: "AI Fam reads your calendar events to suggest schedule optimizations and prevent conflicts."
- Contacts: "AI Fam accesses your contacts to help coordinate plans with people you know."
- Health: "AI Fam reads your health data to provide wellness insights and activity suggestions."

---

## SIGNING (Use Automatic)

1. Xcode → Settings → Accounts → sign in
2. Target → Signing & Capabilities → select your Team
3. Set `DEVELOPMENT_TEAM` in project.yml
4. Done. Xcode handles certificates and provisioning profiles automatically.

---

## TESTFLIGHT

| | Internal | External |
|---|---|---|
| Max testers | 100 | 10,000 |
| Apple review needed? | No | Yes (first build only) |
| Access time | Immediate | 24-48 hours |
| Build expiry | 90 days | 90 days |
