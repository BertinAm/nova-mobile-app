from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str
    database: str
    app: str
    environment: str
