import json

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

IMPORTANT: Respond ONLY with valid JSON. No markdown, no code fences, no extra text."""

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

    raw = response.content[0].text
    parsed = json.loads(raw)

    return ChatResponse(
        reply=parsed["reply"],
        filed_items=[FiledItem(**item) for item in parsed.get("filed_items", [])],
        filed_categories=parsed.get("filed_categories", []),
    )
