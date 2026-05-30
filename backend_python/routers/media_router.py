import os
import json
import asyncio
import uuid
from pathlib import Path
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from database import get_db
from models import Media
from auth import get_current_user
import faiss_index

router = APIRouter(prefix="/api/media", tags=["media"])

UPLOAD_DIR = os.getenv("UPLOAD_DIR", "uploads")
MAX_SIZE   = 50 * 1024 * 1024

ALLOWED_MIMETYPES = {
    "image/jpeg", "image/jpg", "image/png", "image/gif", "image/webp",
    "video/mp4", "video/mov", "video/quicktime", "video/avi", "video/webm",
    "video/x-msvideo", "video/x-matroska", "video/wmv", "video/x-ms-wmv",
    "audio/mpeg", "audio/mp3", "audio/wav", "audio/ogg", "audio/x-wav",
    "application/pdf", "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "text/plain",
}

EXT_MAP = {
    "image/jpeg": ".jpg", "image/jpg": ".jpg", "image/png": ".png",
    "image/gif": ".gif", "image/webp": ".webp",
    "video/mp4": ".mp4", "video/mov": ".mov", "video/quicktime": ".mov",
    "video/avi": ".avi", "video/x-msvideo": ".avi",
    "video/webm": ".webm", "video/x-matroska": ".mkv",
    "video/wmv": ".wmv", "video/x-ms-wmv": ".wmv",
    "audio/mpeg": ".mp3", "audio/mp3": ".mp3", "audio/wav": ".wav",
    "audio/ogg": ".ogg", "application/pdf": ".pdf",
    "application/msword": ".doc",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": ".docx",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": ".xlsx",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation": ".pptx",
    "text/plain": ".txt",
}

EXT_TO_MIME = {v: k for k, v in EXT_MAP.items()}


def _media_type(mime: str) -> str:
    if mime.startswith("image/"): return "image"
    if mime.startswith("video/"): return "video"
    if mime.startswith("audio/"): return "audio"
    return "document"


def _media_to_dict(m: Media, score: float | None = None) -> dict:
    d = {
        "_id": m.id, "id": m.id, "userId": m.user_id,
        "filename": m.filename, "originalName": m.original_name,
        "type": m.type, "size": m.size, "filePath": m.file_path,
        "analyzed": m.analyzed,
        "tags": json.loads(m.tags) if m.tags else [],
        "aiObjects": json.loads(m.ai_objects) if m.ai_objects else [],
        "aiConfidence": m.ai_confidence or 0.0,
        "description": m.description or "",
        "favorite": m.favorite or False,
        "createdAt": m.created_at.isoformat() if m.created_at else None,
    }
    if score is not None:
        d["similarityScore"] = score
    return d


async def _analyze_later(media_id, file_path, media_type, original_name, db_factory):
    await asyncio.sleep(1)
    try:
        loop = asyncio.get_running_loop()
        if media_type == "image":
            result = await loop.run_in_executor(None, _run_image, file_path)
        elif media_type == "video":
            result = await loop.run_in_executor(None, _run_video, file_path)
        else:
            result = {"objects": [media_type], "confidence": 1.0, "embedding": []}

        objects = result.get("objects", [])
        semantic_tags = result.get("semantic_tags", [])
        tags = list(dict.fromkeys(objects + semantic_tags + [media_type, "IA_analysed"]))

        async with db_factory() as db:
            res = await db.execute(select(Media).where(Media.id == media_id))
            media = res.scalar_one_or_none()
            if media:
                media.analyzed = True
                media.tags = json.dumps(tags)
                media.ai_objects = json.dumps(objects)
                media.ai_confidence = result.get("confidence", 0.0)
                await db.commit()
                # Texte enrichi avec semantic_tags pour FAISS
                text = f"{original_name} {media_type} {' '.join(tags)} {' '.join(semantic_tags)}"
                faiss_index.add_media(media_id, media.user_id, text, result.get("embedding", []))
    except Exception as e:
        print(f"❌ Analyse IA erreur: {e}")


def _run_image(fp):
    from ai_analyzer import analyze_image
    return analyze_image(fp)


def _run_video(fp):
    from ai_analyzer import analyze_video
    return analyze_video(fp)


@router.post("/upload")
async def upload_media(
    media: UploadFile = File(...),
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    raw_ct = (media.content_type or "").split(";")[0].strip().lower()
    ext = Path(media.filename or "").suffix.lower()
    content_type = raw_ct if raw_ct in ALLOWED_MIMETYPES else EXT_TO_MIME.get(ext, raw_ct)

    if content_type not in ALLOWED_MIMETYPES:
        raise HTTPException(status_code=400, detail=f"Type non supporté: {content_type}")

    content = await media.read()
    if len(content) > MAX_SIZE:
        raise HTTPException(status_code=400, detail="Fichier trop grand (max 50 MB)")

    Path(UPLOAD_DIR).mkdir(parents=True, exist_ok=True)
    ext_final = ext or EXT_MAP.get(content_type, "")
    unique_name = f"{int(datetime.now(timezone.utc).timestamp()*1000)}-{uuid.uuid4().hex[:9]}{ext_final}"
    file_path = os.path.join(UPLOAD_DIR, unique_name)

    with open(file_path, "wb") as f:
        f.write(content)

    mtype = _media_type(content_type)
    new_media = Media(
        user_id=user["id"], filename=unique_name,
        original_name=media.filename, type=mtype,
        size=len(content), file_path=file_path,
        analyzed=False, tags=json.dumps([]),
        ai_objects=json.dumps([]), ai_confidence=0.0,
    )
    db.add(new_media)
    await db.commit()
    await db.refresh(new_media)

    from database import AsyncSessionLocal
    asyncio.create_task(_analyze_later(new_media.id, file_path, mtype, media.filename or unique_name, AsyncSessionLocal))
    return {"msg": "Fichier uploadé, analyse IA en cours", "media": _media_to_dict(new_media)}


@router.get("/dashboard")
async def get_dashboard(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    uid = user["id"]
    total    = (await db.execute(select(func.count()).where(Media.user_id == uid))).scalar() or 0
    analyzed = (await db.execute(select(func.count()).where(Media.user_id == uid, Media.analyzed == True))).scalar() or 0  # noqa
    size     = (await db.execute(select(func.sum(Media.size)).where(Media.user_id == uid))).scalar() or 0
    recent   = (await db.execute(select(Media).where(Media.user_id == uid).order_by(Media.created_at.desc()).limit(5))).scalars().all()
    return {
        "totalMedias": total, "analyzedMedias": analyzed,
        "totalStorage": f"{size/(1024**3):.2f} GB",
        "recentMedias": [_media_to_dict(m) for m in recent],
    }


@router.get("")
@router.get("/")
async def get_media(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Media).where(Media.user_id == user["id"]).order_by(Media.created_at.desc()))
    return [_media_to_dict(m) for m in result.scalars().all()]


@router.get("/search")
async def search_media(
    q: str,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    uid = user["id"]

    # 1. Recherche sémantique FAISS (CLIP + sentence-transformers)
    loop = asyncio.get_running_loop()
    hits = await loop.run_in_executor(None, faiss_index.search_media, uid, q)
    score_map = {h["media_id"]: h["score"] for h in hits} if hits else {}

    # 2. Recherche exacte par nom / description / tags / objets IA
    q_lower = q.lower()
    all_medias_res = await db.execute(select(Media).where(Media.user_id == uid))
    all_medias = all_medias_res.scalars().all()

    # Traduction FR→EN pour matcher les tags anglais
    from faiss_index import _build_clip_query
    q_en = _build_clip_query(q).lower().replace("a photo of ", "")

    name_matches = {}
    for m in all_medias:
        name = (m.original_name or "").lower()
        desc = (m.description or "").lower()
        tags = " ".join(json.loads(m.tags) if m.tags else []).lower()
        objs = " ".join(json.loads(m.ai_objects) if m.ai_objects else []).lower()
        combined = f"{name} {desc} {tags} {objs}"
        match_fr = q_lower in combined
        match_en = any(word in combined for word in q_en.split() if len(word) > 2)
        if match_fr or match_en:
            score = 1.0 if q_lower in name else (0.9 if match_en and any(word in objs for word in q_en.split() if len(word) > 2) else 0.75)
            name_matches[m.id] = score

    # Fusion : FAISS sémantique prioritaire, exact en complément
    # On prend le max des deux scores pour chaque média
    merged = {}
    all_ids = set(name_matches.keys()) | set(score_map.keys())
    for mid in all_ids:
        merged[mid] = max(name_matches.get(mid, 0.0), score_map.get(mid, 0.0))

    # Filtrer les résultats non pertinents (score trop bas)
    merged = {mid: s for mid, s in merged.items() if s >= 0.25}

    if not merged:
        return []

    result = await db.execute(select(Media).where(Media.id.in_(merged.keys()), Media.user_id == uid))
    medias = sorted(result.scalars().all(), key=lambda m: merged.get(m.id, 0), reverse=True)
    return [_media_to_dict(m, score=round(merged.get(m.id, 0.0), 4)) for m in medias]


from pydantic import BaseModel

class DescriptionBody(BaseModel):
    description: str


@router.post("/reindex")
async def reindex_all(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Réanalyse et réindexe tous les médias avec CLIP semantic tags."""
    uid = user["id"]
    result = await db.execute(select(Media).where(Media.user_id == uid))
    medias = result.scalars().all()
    loop = asyncio.get_running_loop()
    count = 0

    for m in medias:
        try:
            clip_emb = []
            semantic_tags = []

            if m.file_path and os.path.exists(m.file_path):
                if m.type == "image":
                    res = await loop.run_in_executor(None, _run_image, m.file_path)
                    clip_emb = res.get("embedding", [])
                    semantic_tags = res.get("semantic_tags", [])
                    objects = res.get("objects", [])
                    # Mettre à jour les tags enrichis en DB
                    new_tags = list(dict.fromkeys(objects + semantic_tags + [m.type, "IA_analysed"]))
                    m.analyzed = True
                    m.tags = json.dumps(new_tags)
                    m.ai_objects = json.dumps(objects)
                    m.ai_confidence = res.get("confidence", 0.0)
                elif m.type == "video":
                    res = await loop.run_in_executor(None, _run_video, m.file_path)
                    clip_emb = res.get("embedding", [])
                    semantic_tags = res.get("semantic_tags", [])
                    objects = res.get("objects", [])
                    new_tags = list(dict.fromkeys(objects + semantic_tags + [m.type, "IA_analysed"]))
                    m.analyzed = True
                    m.tags = json.dumps(new_tags)
                    m.ai_objects = json.dumps(objects)

            # Texte enrichi : nom + type + description + objets + semantic_tags
            existing_tags = json.loads(m.tags) if m.tags else []
            text = f"{m.original_name} {m.type} {m.description or ''} {' '.join(existing_tags)} {' '.join(semantic_tags)}"
            faiss_index.remove_media(m.id)
            faiss_index.add_media(m.id, uid, text, clip_emb)
            count += 1
            print(f"✅ Réindexé: {m.original_name} | semantic: {semantic_tags[:3]}")
        except Exception as e:
            print(f"[reindex] media {m.id} ({m.original_name}): {e}")

    await db.commit()
    return {"msg": f"{count} médias réindexés avec semantic tags CLIP"}


@router.patch("/{media_id}/favorite")
async def toggle_favorite(
    media_id: int,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Media).where(Media.id == media_id))
    media = result.scalar_one_or_none()
    if not media:
        raise HTTPException(status_code=404, detail="Média introuvable")
    if media.user_id != user["id"]:
        raise HTTPException(status_code=401, detail="Non autorisé")
    media.favorite = not (media.favorite or False)
    await db.commit()
    await db.refresh(media)
    return _media_to_dict(media)


@router.patch("/{media_id}/description")
async def update_description(
    media_id: int,
    body: DescriptionBody,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Media).where(Media.id == media_id))
    media = result.scalar_one_or_none()
    if not media:
        raise HTTPException(status_code=404, detail="Média introuvable")
    if media.user_id != user["id"]:
        raise HTTPException(status_code=401, detail="Non autorisé")

    media.description = body.description

    # Réindexer dans FAISS avec la nouvelle description
    tags = json.loads(media.tags) if media.tags else []
    text = f"{media.original_name} {media.type} {body.description} {' '.join(tags)}"
    faiss_index.remove_media(media_id)
    faiss_index.add_media(media_id, user["id"], text)

    await db.commit()
    await db.refresh(media)
    return _media_to_dict(media)


@router.delete("/{media_id}")
async def delete_media(
    media_id: int,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Media).where(Media.id == media_id))
    media = result.scalar_one_or_none()
    if not media:
        raise HTTPException(status_code=404, detail="Média introuvable")
    if media.user_id != user["id"] and user.get("role") != "admin":
        raise HTTPException(status_code=401, detail="Non autorisé")
    if media.file_path and os.path.exists(media.file_path):
        os.remove(media.file_path)
    faiss_index.remove_media(media_id)
    await db.delete(media)
    await db.commit()
    return {"msg": "Média supprimé avec succès"}
