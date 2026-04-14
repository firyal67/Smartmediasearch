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

    yield


app = FastAPI(title="SmartMedia API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

upload_dir = os.getenv("UPLOAD_DIR", "uploads")
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
