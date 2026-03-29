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
