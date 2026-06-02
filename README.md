# 🎬 SmartMedia Search

Une médiathèque intelligente avec recherche sémantique par IA.

## 🌐 Site en ligne

👉 **[https://floral-cell-8b2a.feryelguehis86.workers.dev](https://floral-cell-8b2a.feryelguehis86.workers.dev)**

## 🔑 Comptes de démonstration

| Rôle | Email | Mot de passe |
|------|-------|--------------|
| Utilisateur | demo@smartmedia.com | demo123 |
| Admin | admin@smartmedia.com | admin123 |

## 🚀 Stack technique

- **Frontend** : Flutter Web (déployé sur Cloudflare Pages)
- **Backend** : FastAPI Python (déployé sur Render)
- **IA** : CLIP (OpenAI ViT-B-32) + FAISS + Sentence-Transformers
- **Base de données** : SQLite (aiosqlite)
- **Auth** : JWT + bcrypt

## ✨ Fonctionnalités

- Authentification (login / register / rôles admin & user)
- Upload de médias : images, vidéos, audio, documents (max 50MB)
- Analyse IA automatique après upload (MobileNet + CLIP)
- Recherche sémantique FAISS (texte → espace visuel)
- Dashboard avec statistiques
- Panel admin (gestion utilisateurs & médias)
- Favoris et descriptions manuelles

## 🛠️ Lancer en local

### Backend
```bash
cd backend_python
.venv_win/Scripts/python.exe main.py
```

### Frontend
```bash
cd appwebsmart
flutter run -d edge
```
