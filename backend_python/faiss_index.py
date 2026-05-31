"""
Moteur de recherche sémantique CLIP + FAISS.

Architecture :
- Index CLIP  : embeddings visuels 512D (image → vecteur normalisé)
- Index TEXT  : embeddings textuels 384D (sentence-transformers)
- Recherche   : similarité cosinus via IndexFlatIP (inner product sur vecteurs normalisés)
- Fusion      : score_final = max(score_clip, score_text * 0.85)
"""

import os
import json

# numpy importé uniquement si IA activée
_np = None
def _get_np():
    global _np
    if _np is None:
        import numpy as np
        _np = np
    return _np

BASE_DIR        = os.path.dirname(os.path.abspath(__file__))
CLIP_INDEX_PATH = os.path.join(BASE_DIR, "faiss_clip.bin")
CLIP_META_PATH  = os.path.join(BASE_DIR, "faiss_clip_meta.json")
TEXT_INDEX_PATH = os.path.join(BASE_DIR, "faiss_text.bin")
TEXT_META_PATH  = os.path.join(BASE_DIR, "faiss_text_meta.json")

CLIP_DIM = 512
TEXT_DIM = 384

# Seuil minimum de similarité pour retourner un résultat
CLIP_THRESHOLD = 0.25
TEXT_THRESHOLD = 0.45

_clip_index = None
_clip_meta  = []
_text_index = None
_text_meta  = []
_st_model   = None


# ── Modèles ───────────────────────────────────────────────────────────────────

def _st():
    global _st_model
    if _st_model is None:
        from sentence_transformers import SentenceTransformer
        # Modèle multilingue → comprend le français directement
        _st_model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")
    return _st_model


def _normalize(vec) -> object:
    np = _get_np()
    n = np.linalg.norm(vec)
    return vec / n if n > 1e-8 else vec


# ── Index FAISS ───────────────────────────────────────────────────────────────

def _clip_idx():
    global _clip_index, _clip_meta
    if _clip_index is None:
        import faiss
        if os.path.exists(CLIP_INDEX_PATH) and os.path.exists(CLIP_META_PATH):
            try:
                _clip_index = faiss.read_index(CLIP_INDEX_PATH)
                with open(CLIP_META_PATH, encoding="utf-8") as f:
                    _clip_meta = json.load(f)
            except Exception as e:
                print(f"[FAISS] Erreur chargement CLIP index: {e}")
                _clip_index = faiss.IndexFlatIP(CLIP_DIM)
                _clip_meta  = []
        else:
            _clip_index = faiss.IndexFlatIP(CLIP_DIM)
            _clip_meta  = []
    return _clip_index, _clip_meta


def _text_idx():
    global _text_index, _text_meta
    if _text_index is None:
        import faiss
        if os.path.exists(TEXT_INDEX_PATH) and os.path.exists(TEXT_META_PATH):
            try:
                _text_index = faiss.read_index(TEXT_INDEX_PATH)
                with open(TEXT_META_PATH, encoding="utf-8") as f:
                    _text_meta = json.load(f)
            except Exception as e:
                print(f"[FAISS] Erreur chargement TEXT index: {e}")
                _text_index = faiss.IndexFlatIP(TEXT_DIM)
                _text_meta  = []
        else:
            _text_index = faiss.IndexFlatIP(TEXT_DIM)
            _text_meta  = []
    return _text_index, _text_meta


def _save_clip(idx, meta):
    import faiss
    faiss.write_index(idx, CLIP_INDEX_PATH)
    with open(CLIP_META_PATH, "w", encoding="utf-8") as f:
        json.dump(meta, f)


def _save_text(idx, meta):
    import faiss
    faiss.write_index(idx, TEXT_INDEX_PATH)
    with open(TEXT_META_PATH, "w", encoding="utf-8") as f:
        json.dump(meta, f)


# ── Ajout ─────────────────────────────────────────────────────────────────────

def add_media(media_id: int, user_id: int, text: str, clip_embedding: list = None):
    if os.getenv("DISABLE_AI"):
        return
    np = _get_np()
    vec = _st().encode([text], normalize_embeddings=True).astype("float32")
    t_idx, t_meta = _text_idx()
    t_idx.add(vec)
    t_meta.append({"media_id": media_id, "user_id": user_id, "text": text[:300]})
    _save_text(t_idx, t_meta)

    if clip_embedding and len(clip_embedding) == CLIP_DIM:
        arr = np.array([clip_embedding], dtype="float32")
        arr[0] = _normalize(arr[0])
        c_idx, c_meta = _clip_idx()
        c_idx.add(arr)
        c_meta.append({"media_id": media_id, "user_id": user_id})
        _save_clip(c_idx, c_meta)


# ── Traduction FR → EN pour CLIP ──────────────────────────────────────────────
# CLIP est entraîné en anglais → on traduit les requêtes françaises

_FR_EN = {
    # Verbes
    "boire": "drinking a drink",
    "manger": "eating food",
    "courir": "running",
    "marcher": "walking",
    "dormir": "sleeping",
    "travailler": "working at a desk",
    "jouer": "playing",
    "cuisiner": "cooking in kitchen",
    "lire": "reading a book",
    "conduire": "driving a car",
    "nager": "swimming",
    "danser": "dancing",
    "parler": "talking",
    "rire": "laughing",
    "pleurer": "crying",
    "assis": "sitting",
    "debout": "standing",
    "sauter": "jumping",
    # Objets
    "bouteille d'eau": "water bottle",
    "bouteille": "bottle",
    "nourriture": "food",
    "boisson": "drink",
    "café": "coffee",
    "fruit": "fruits",
    "légume": "vegetables",
    "fleur": "flowers",
    "arbre": "tree",
    "voiture": "car",
    "téléphone": "smartphone",
    "ordinateur": "computer",
    "livre": "book",
    # Lieux
    "plage": "beach",
    "montagne": "mountain",
    "forêt": "forest",
    "ville": "city",
    "rue": "street",
    "maison": "house",
    "bureau": "office",
    "cuisine": "kitchen",
    "chambre": "bedroom",
    "parc": "park",
    "restaurant": "restaurant",
    "mer": "sea ocean",
    # Personnes
    "personnage": "person",
    "personne": "person",
    "homme": "man",
    "femme": "woman",
    "enfant": "child",
    "bébé": "baby",
    "visage": "face",
    "portrait": "portrait",
    "groupe": "group of people",
    "famille": "family",
    "amis": "friends",
    "ami": "friend",
    # Animaux
    "animal": "animal",
    "chien": "dog",
    "chat": "cat",
    "oiseau": "bird",
    "poisson": "fish",
    "cheval": "horse",
    # Nature
    "nature": "nature landscape",
    "ciel": "sky",
    "nuage": "clouds",
    "soleil": "sun",
    "nuit": "night",
    "coucher de soleil": "sunset",
    "lever de soleil": "sunrise",
    "paysage": "landscape",
    # Thèmes
    "voyage": "travel",
    "sport": "sport",
    "musique": "music",
    "art": "art",
    "technologie": "technology",
    "fête": "party celebration",
    "mariage": "wedding",
    "travail": "work office",
    "repas": "meal food",
    "shopping": "shopping",
    # Couleurs
    "rouge": "red",
    "bleu": "blue",
    "vert": "green",
    "jaune": "yellow",
    "blanc": "white",
    "noir": "black",
    "coloré": "colorful",
    "sombre": "dark",
    "lumineux": "bright",
}


def _build_clip_query(query: str) -> str:
    """
    Construit une requête CLIP optimale depuis une requête utilisateur.
    CLIP fonctionne mieux avec des phrases descriptives en anglais.
    """
    q = query.lower().strip()

    # Traduire les termes français
    for fr, en in sorted(_FR_EN.items(), key=lambda x: -len(x[0])):
        if fr in q:
            q = q.replace(fr, en)

    # Formater comme une description d'image pour CLIP
    if not q.startswith("a photo") and not q.startswith("an image"):
        q = f"a photo of {q}"

    return q


# ── Recherche ─────────────────────────────────────────────────────────────────

def search_media(user_id: int, query: str, top_k: int = 10) -> list:
    """
    Recherche sémantique hybride :
    1. CLIP  : requête texte → embedding → similarité cosinus avec embeddings images
    2. TEXT  : requête → embedding multilingue → similarité avec textes indexés
    3. Fusion: score_final = max(clip_score, text_score * 0.85)
    """
    if os.getenv("DISABLE_AI"):
        return []
    np = _get_np()
    results = {}

    # ── 1. Recherche CLIP (texte → espace visuel) ──────────────────────────
    try:
        from ai_analyzer import get_clip_text_embedding

        clip_query = _build_clip_query(query)
        print(f"[CLIP query] '{query}' → '{clip_query}'")

        clip_vec = get_clip_text_embedding(clip_query)

        if clip_vec and len(clip_vec) == CLIP_DIM:
            arr = np.array([clip_vec], dtype="float32")
            arr[0] = _normalize(arr[0])

            c_idx, c_meta = _clip_idx()
            if c_idx.ntotal > 0:
                k = min(top_k * 2, c_idx.ntotal)
                scores, indices = c_idx.search(arr, k)

                for s, i in zip(scores[0], indices[0]):
                    if i < 0 or i >= len(c_meta):
                        continue
                    if c_meta[i]["user_id"] != user_id:
                        continue
                    score = float(s)
                    if score < CLIP_THRESHOLD:
                        continue
                    mid = c_meta[i]["media_id"]
                    results[mid] = max(results.get(mid, 0.0), score)
                    print(f"  [CLIP] media {mid}: {score:.4f}")
    except Exception as e:
        print(f"[FAISS CLIP] {e}")

    # ── 2. Recherche textuelle multilingue (sentence-transformers) ──────────
    try:
        # Le modèle multilingue comprend directement le français
        vec = _st().encode([query], normalize_embeddings=True).astype("float32")

        t_idx, t_meta = _text_idx()
        if t_idx.ntotal > 0:
            k = min(top_k * 2, t_idx.ntotal)
            scores, indices = t_idx.search(vec, k)

            for s, i in zip(scores[0], indices[0]):
                if i < 0 or i >= len(t_meta):
                    continue
                if t_meta[i]["user_id"] != user_id:
                    continue
                score = float(s) * 0.85  # légère pondération inférieure à CLIP
                if score < TEXT_THRESHOLD * 0.85:
                    continue
                mid = t_meta[i]["media_id"]
                results[mid] = max(results.get(mid, 0.0), score)
                print(f"  [TEXT] media {mid}: {score:.4f}")
    except Exception as e:
        print(f"[FAISS TEXT] {e}")

    sorted_r = sorted(results.items(), key=lambda x: x[1], reverse=True)[:top_k]
    return [{"media_id": mid, "score": round(s, 4)} for mid, s in sorted_r]


# ── Suppression ───────────────────────────────────────────────────────────────

def remove_media(media_id: int):
    """Reconstruit les index FAISS sans le média supprimé."""
def remove_media(media_id: int):
    """Reconstruit les index FAISS sans le média supprimé."""
    if os.getenv("DISABLE_AI"):
        return
    global _clip_index, _clip_meta, _text_index, _text_meta
    import faiss
    np = _get_np()

    # Reconstruire index CLIP
    _, c_meta = _clip_idx()
    kept = [i for i, m in enumerate(c_meta) if m["media_id"] != media_id]
    new_c_idx  = faiss.IndexFlatIP(CLIP_DIM)
    new_c_meta = [c_meta[i] for i in kept]
    if _clip_index is not None and _clip_index.ntotal > 0 and kept:
        all_vecs  = _clip_index.reconstruct_n(0, _clip_index.ntotal)
        kept_vecs = np.array([all_vecs[i] for i in kept], dtype="float32")
        new_c_idx.add(kept_vecs)
    _clip_index = new_c_idx
    _clip_meta  = new_c_meta
    _save_clip(new_c_idx, new_c_meta)

    # Reconstruire index TEXT
    _, t_meta = _text_idx()
    kept = [i for i, m in enumerate(t_meta) if m["media_id"] != media_id]
    new_t_idx  = faiss.IndexFlatIP(TEXT_DIM)
    new_t_meta = [t_meta[i] for i in kept]
    if _text_index is not None and _text_index.ntotal > 0 and kept:
        all_vecs  = _text_index.reconstruct_n(0, _text_index.ntotal)
        kept_vecs = np.array([all_vecs[i] for i in kept], dtype="float32")
        new_t_idx.add(kept_vecs)
    _text_index = new_t_idx
    _text_meta  = new_t_meta
    _save_text(new_t_idx, new_t_meta)
