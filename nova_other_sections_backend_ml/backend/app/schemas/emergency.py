from pydantic import BaseModel, Field


class EmergencyContactSetRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    phone_number: str = Field(min_length=5, max_length=30)


class EmergencyContactOut(BaseModel):
    id: str
    name: str
    phone_number: str


class EmergencyShareRequest(BaseModel):
    latitude: float
    longitude: float
    accuracy_meters: float | None = None


class EmergencyShareResponse(BaseModel):
    message: str
    sms_body: str
    phone_number: str | None = None
