from pydantic import BaseModel, EmailStr
from datetime import datetime


class UserRegister(BaseModel):
    display_name: str
    email: EmailStr
    password: str


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserOut(BaseModel):
    id: int
    display_name: str
    email: EmailStr
    created_at: datetime

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class ScanCreate(BaseModel):
    plant_name: str
    latin_name: str | None = None
    confidence: float
    saved_to_library: bool = False


class ScanOut(BaseModel):
    id: int
    plant_name: str
    latin_name: str | None
    confidence: float
    saved_to_library: bool
    created_at: datetime

    class Config:
        from_attributes = True


class ScanStats(BaseModel):
    total_scans: int
    species_identified: int
    avg_confidence: float
    saved_to_library: int
