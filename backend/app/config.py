from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    anthropic_api_key: str = ""
    database_url: str = "sqlite:///./aifam.db"
    environment: str = "development"

    model_config = {"env_file": ".env"}


settings = Settings()
