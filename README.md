# SmartMedia Search

Application mobile de recherche intelligente de médias par IA.

## Structure du projet

```
smartmediasearch/
├── frontend/        → App Flutter (mobile + web)
├── backend/         → API FastAPI + SQLite + FAISS + CLIP
└── backend_old/     → Ancien backend Node.js (archivé)
```

## Lancer le projet

### Backend (FastAPI)
```bash
cd backend
py -m pip install -r requirements.txt
py -m uvicorn main:app --host 0.0.0.0 --port 5000 --reload
```

### Frontend (Flutter)
```bash
cd frontend
flutter pub get
flutter run -d edge --web-port 7777
```

## Compte de test
- Email : `demo@smartmedia.com`
- Mot de passe : `demo123`

## Stack IA
| Composant | Technologie |
|-----------|-------------|
| Classification images | MobileNetV3 (torchvision) |
| Analyse vidéos | OpenCV + MobileNetV3 |
| Embeddings image↔texte | CLIP ViT-B/32 (open-clip) |
| Recherche vectorielle | FAISS |
| Embeddings texte | SentenceTransformers |
