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
