from dotenv import load_dotenv
load_dotenv()

import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import init_db, AsyncSessionLocal
from models import User
from auth import hash_password
from sqlalchemy import select
from routers.auth_router import router as auth_router
from routers.media_router import router as media_router
from routers.admin_router import router as admin_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()

    async with AsyncSessionLocal() as db:
        # Compte demo
        res = await db.execute(select(User).where(User.email == "demo@smartmedia.com"))
        if not res.scalar_one_or_none():
            db.add(User(email="demo@smartmedia.com", password=hash_password("demo123"), role="user"))
            await db.commit()
            print("✅ Compte demo créé : demo@smartmedia.com / demo123")

        # Compte admin
        admin_email = os.getenv("ADMIN_EMAIL", "admin@smartmedia.com")
        admin_pass  = os.getenv("ADMIN_PASSWORD", "admin123")
        res = await db.execute(select(User).where(User.email == admin_email))
        if not res.scalar_one_or_none():
            db.add(User(email=admin_email, password=hash_password(admin_pass), role="admin"))
            await db.commit()
            print(f"✅ Compte admin créé : {admin_email} / {admin_pass}")
        else:
            print(f"ℹ️  Admin existe déjà : {admin_email}")

    # Pré-charger les modèles IA en arrière-plan
    import asyncio
    asyncio.create_task(_preload_models())

    yield


async def _preload_models():
    import asyncio
    loop = asyncio.get_running_loop()
    print("⏳ Pré-chargement des modèles IA...")
    try:
        await loop.run_in_executor(None, _load_models)
        print("✅ Modèles IA chargés et prêts")
    except Exception as e:
        print(f"⚠️  Erreur chargement modèles: {e}")


def _load_models():
    try:
        from faiss_index import _st, _clip_idx, _text_idx
        _st()        # sentence-transformers
        _clip_idx()  # FAISS CLIP index
        _text_idx()  # FAISS text index
        from ai_analyzer import get_clip_text_embedding
        get_clip_text_embedding("test")  # charge CLIP
    except Exception as e:
        print(f"⚠️  Modèle partiel: {e}")


app = FastAPI(title="SmartMedia API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
upload_dir = os.getenv("UPLOAD_DIR", os.path.join(BASE_DIR, "uploads"))
os.makedirs(upload_dir, exist_ok=True)

# Route manuelle pour servir les uploads avec CORS
from fastapi.responses import FileResponse
@app.get("/uploads/{filename}")
async def serve_upload(filename: str):
    file_path = os.path.join(upload_dir, filename)
    if not os.path.exists(file_path):
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Fichier introuvable")
    return FileResponse(file_path)

app.include_router(auth_router)
app.include_router(media_router)
app.include_router(admin_router)


@app.get("/")
def root():
    return {"status": "SmartMedia API running"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=5000, reload=False)
