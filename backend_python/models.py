from sqlalchemy import Column, Integer, String, Boolean, Float, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
from database import Base


class User(Base):
    __tablename__ = "users"

    id            = Column(Integer, primary_key=True, index=True)
    email         = Column(String, unique=True, index=True, nullable=False)
    password      = Column(String, nullable=False)
    role          = Column(String, default="user")   # "user" | "admin"
    is_active     = Column(Boolean, default=True)
    created_at    = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    medias = relationship("Media", back_populates="owner", cascade="all, delete")


class Media(Base):
    __tablename__ = "medias"

    id            = Column(Integer, primary_key=True, index=True)
    user_id       = Column(Integer, ForeignKey("users.id"), nullable=False)
    filename      = Column(String, nullable=False)
    original_name = Column(String)
    type          = Column(String, nullable=False)
    size          = Column(Float, nullable=False)
    file_path     = Column(String)
    analyzed      = Column(Boolean, default=False)
    tags          = Column(String, default="[]")
    ai_objects    = Column(String, default="[]")
    ai_confidence = Column(Float, default=0.0)
    description   = Column(String, default="")   # description manuelle
    favorite      = Column(Boolean, default=False)
    created_at    = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    owner = relationship("User", back_populates="medias")
