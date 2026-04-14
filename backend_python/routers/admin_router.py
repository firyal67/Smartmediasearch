"""
Routes réservées à l'administrateur :
GET  /api/admin/users          — liste tous les utilisateurs
GET  /api/admin/users/{id}     — détail d'un utilisateur
PUT  /api/admin/users/{id}     — modifier rôle / statut
DELETE /api/admin/users/{id}   — supprimer un utilisateur
GET  /api/admin/stats          — statistiques globales
GET  /api/admin/medias         — tous les médias de tous les users
DELETE /api/admin/medias/{id}  — supprimer n'importe quel média
"""
import os
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from pydantic import BaseModel
from typing import Optional

from database import get_db
from models import User, Media
from auth import require_admin, hash_password
import json

router = APIRouter(prefix="/api/admin", tags=["admin"])


# ── Schémas ───────────────────────────────────────────────────────────────────

class UpdateUserBody(BaseModel):
    role: Optional[str] = None       # "user" | "admin"
    is_active: Optional[bool] = None
    password: Optional[str] = None


# ── Helpers ───────────────────────────────────────────────────────────────────

def _user_dict(u: User) -> dict:
    return {
        "id": u.id,
        "email": u.email,
        "role": u.role,
        "isActive": u.is_active,
        "createdAt": u.created_at.isoformat() if u.created_at else None,
    }


def _media_dict(m: Media) -> dict:
    return {
        "id": m.id,
        "userId": m.user_id,
        "filename": m.filename,
        "originalName": m.original_name,
        "type": m.type,
        "size": m.size,
        "analyzed": m.analyzed,
        "tags": json.loads(m.tags) if m.tags else [],
        "aiObjects": json.loads(m.ai_objects) if m.ai_objects else [],
        "createdAt": m.created_at.isoformat() if m.created_at else None,
    }


# ── Stats globales ────────────────────────────────────────────────────────────

@router.get("/stats")
async def global_stats(
    admin=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    total_users  = (await db.execute(select(func.count()).select_from(User))).scalar() or 0
    total_medias = (await db.execute(select(func.count()).select_from(Media))).scalar() or 0
    analyzed     = (await db.execute(select(func.count()).where(Media.analyzed == True))).scalar() or 0  # noqa
    total_size   = (await db.execute(select(func.sum(Media.size)))).scalar() or 0
    admins       = (await db.execute(select(func.count()).where(User.role == "admin"))).scalar() or 0
    active_users = (await db.execute(select(func.count()).where(User.is_active == True))).scalar() or 0  # noqa

    return {
        "totalUsers": total_users,
        "activeUsers": active_users,
        "totalAdmins": admins,
        "totalMedias": total_medias,
        "analyzedMedias": analyzed,
        "totalStorage": f"{total_size / (1024**3):.2f} GB",
    }


# ── Gestion utilisateurs ──────────────────────────────────────────────────────

@router.get("/users")
async def list_users(
    admin=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).order_by(User.created_at.desc()))
    return [_user_dict(u) for u in result.scalars().all()]


@router.get("/users/{user_id}")
async def get_user(
    user_id: int,
    admin=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    medias = (await db.execute(select(func.count()).where(Media.user_id == user_id))).scalar() or 0
    d = _user_dict(user)
    d["totalMedias"] = medias
    return d


@router.put("/users/{user_id}")
async def update_user(
    user_id: int,
    body: UpdateUserBody,
    admin=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    if body.role is not None:
        if body.role not in ("user", "admin"):
            raise HTTPException(status_code=400, detail="Rôle invalide (user | admin)")
        user.role = body.role
    if body.is_active is not None:
        user.is_active = body.is_active
    if body.password:
        user.password = hash_password(body.password)

    await db.commit()
    await db.refresh(user)
    return _user_dict(user)


@router.delete("/users/{user_id}")
async def delete_user(
    user_id: int,
    admin=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    if user.role == "admin":
        raise HTTPException(status_code=400, detail="Impossible de supprimer un admin")
    await db.delete(user)
    await db.commit()
    return {"msg": f"Utilisateur {user.email} supprimé"}


# ── Gestion médias ────────────────────────────────────────────────────────────

@router.get("/medias")
async def list_all_medias(
    admin=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Media).order_by(Media.created_at.desc()))
    return [_media_dict(m) for m in result.scalars().all()]


@router.delete("/medias/{media_id}")
async def delete_any_media(
    media_id: int,
    admin=Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Media).where(Media.id == media_id))
    media = result.scalar_one_or_none()
    if not media:
        raise HTTPException(status_code=404, detail="Média introuvable")
    if media.file_path and os.path.exists(media.file_path):
        os.remove(media.file_path)
    await db.delete(media)
    await db.commit()
    return {"msg": "Média supprimé"}
