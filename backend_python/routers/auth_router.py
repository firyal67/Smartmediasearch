from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel, EmailStr
from database import get_db
from models import User
from auth import hash_password, verify_password, create_token

router = APIRouter(prefix="/api/auth", tags=["auth"])


class AuthBody(BaseModel):
    email: EmailStr
    password: str


def _user_dict(user: User, token: str) -> dict:
    return {
        "token": token,
        "user": {
            "id": user.id,
            "email": user.email,
            "role": user.role,
            "isActive": user.is_active,
        }
    }


@router.post("/register")
async def register(body: AuthBody, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="User already exists")

    user = User(email=body.email, password=hash_password(body.password), role="user")
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return _user_dict(user, create_token(user.id, user.role))


@router.post("/login")
async def login(body: AuthBody, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email))
    user = result.scalar_one_or_none()
    if not user or not verify_password(body.password, user.password):
        raise HTTPException(status_code=400, detail="Invalid credentials")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Compte désactivé")
    return _user_dict(user, create_token(user.id, user.role))
