from fastapi import FastAPI
from app.routes import chat, health

app = FastAPI(title="AI Fam Backend", version="0.1.0")

app.include_router(health.router, tags=["health"])
app.include_router(chat.router, tags=["chat"])
