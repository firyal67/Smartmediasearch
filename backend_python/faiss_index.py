import os, json
import numpy as np

BASE_DIR        = os.path.dirname(os.path.abspath(__file__))
CLIP_INDEX_PATH = os.path.join(BASE_DIR, "faiss_clip.bin")
CLIP_META_PATH  = os.path.join(BASE_DIR, "faiss_clip_meta.json")
TEXT_INDEX_PATH = os.path.join(BASE_DIR, "faiss_text.bin")
TEXT_META_PATH  = os.path.join(BASE_DIR, "faiss_text_meta.json")
CLIP_DIM = 512
TEXT_DIM = 384

_clip_index = None; _clip_meta = []
_text_index = None; _text_meta = []
_st_model   = None


# ── Chargement lazy des modèles ───────────────────────────────────────────────

def _st():
    global _st_model
    if _st_model is None:
        from sentence_transformers import SentenceTransformer
        _st_model = SentenceTransformer("all-MiniLM-L6-v2")
    return _st_model


def _clip_idx():
    global _clip_index, _clip_meta
    if _clip_index is None:
        import faiss
        if os.path.exists(CLIP_INDEX_PATH) and os.path.exists(CLIP_META_PATH):
            try:
                _clip_index = faiss.read_index(CLIP_INDEX_PATH)
                _clip_meta  = json.load(open(CLIP_META_PATH, encoding="utf-8"))
            except Exception:
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
                _text_meta  = json.load(open(TEXT_META_PATH, encoding="utf-8"))
            except Exception:
                _text_index = faiss.IndexFlatIP(TEXT_DIM)
                _text_meta  = []
        else:
            _text_index = faiss.IndexFlatIP(TEXT_DIM)
            _text_meta  = []
    return _text_index, _text_meta


# ── Sauvegarde ────────────────────────────────────────────────────────────────

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


# ── Ajout d'un média ──────────────────────────────────────────────────────────

def add_media(media_id: int, user_id: int, text: str, clip_embedding: list = None):
    # Index textuel (sentence-transformers)
    vec = _st().encode([text], normalize_embeddings=True).astype("float32")
    t_idx, t_meta = _text_idx()
    t_idx.add(vec)
    t_meta.append({"media_id": media_id, "user_id": user_id, "text": text})
    _save_text(t_idx, t_meta)

    # Index visuel CLIP
    if clip_embedding and len(clip_embedding) == CLIP_DIM:
        arr = np.array([clip_embedding], dtype="float32")
        n = np.linalg.norm(arr)
        if n > 0:
            arr = arr / n
        c_idx, c_meta = _clip_idx()
        c_idx.add(arr)
        c_meta.append({"media_id": media_id, "user_id": user_id})
        _save_clip(c_idx, c_meta)


# ── Traduction FR→EN pour CLIP ────────────────────────────────────────────────

# Dictionnaire de traduction des termes courants FR→EN
_FR_EN = {
    # Verbes / actions
    "boire": "drinking drink water bottle",
    "manger": "eating food meal",
    "courir": "running sport",
    "marcher": "walking",
    "dormir": "sleeping",
    "travailler": "working office",
    "jouer": "playing",
    "cuisiner": "cooking kitchen food",
    "lire": "reading book",
    "conduire": "driving car",
    "nager": "swimming",
    "danser": "dancing",
    "parler": "talking",
    "rire": "laughing",
    "pleurer": "crying",
    "assis": "sitting",
    "debout": "standing",
    "sauter": "jumping",
    # Objets
    "bouteille": "water bottle drink",
    "bouteille d'eau": "water bottle drinking",
    "nourriture": "food eating",
    "boisson": "drink drinking",
    "café": "coffee drinking",
    "fruit": "fruit food",
    "légume": "vegetable food",
    "fleur": "flower nature",
    "arbre": "tree nature forest",
    "voiture": "car vehicle driving",
    "téléphone": "phone technology",
    "ordinateur": "computer technology working",
    "livre": "book reading",
    "table": "table indoor",
    "chaise": "chair indoor",
    "lit": "bed sleeping",
    # Lieux
    "plage": "beach outdoor",
    "montagne": "mountain nature outdoor",
    "forêt": "forest nature outdoor",
    "ville": "city urban outdoor",
    "rue": "street city outdoor",
    "maison": "house indoor",
    "bureau": "office working indoor",
    "cuisine": "kitchen cooking food",
    "chambre": "bedroom sleeping indoor",
    "parc": "park outdoor nature",
    "restaurant": "restaurant food eating",
    "école": "school",
    "mer": "sea ocean beach outdoor",
    # Personnes
    "personnage": "person human character",
    "personne": "person human",
    "homme": "man person",
    "femme": "woman person",
    "enfant": "child kid person",
    "bébé": "baby child person",
    "visage": "face portrait person",
    "portrait": "portrait face person",
    "groupe": "group of people crowd",
    "famille": "family group of people",
    "ami": "friendship group of people",
    "amis": "friendship group of people",
    # Animaux
    "animal": "animal",
    "chien": "dog animal",
    "chat": "cat animal",
    "oiseau": "bird animal",
    "poisson": "fish animal",
    "cheval": "horse animal",
    # Nature / météo
    "nature": "nature landscape outdoor",
    "ciel": "sky outdoor",
    "nuage": "cloud sky outdoor",
    "soleil": "sun bright outdoor",
    "nuit": "night dark",
    "coucher de soleil": "sunset outdoor",
    "lever de soleil": "sunrise outdoor",
    "paysage": "landscape nature outdoor",
    # Thèmes
    "voyage": "travel outdoor",
    "sport": "sport",
    "musique": "music",
    "art": "art colorful",
    "technologie": "technology computer",
    "mode": "fashion",
    "fête": "party celebration",
    "mariage": "wedding celebration",
    "travail": "working office technology",
    "repas": "food eating meal",
    "shopping": "shopping food",
    # Couleurs
    "rouge": "red colorful",
    "bleu": "blue colorful",
    "vert": "green nature colorful",
    "jaune": "yellow colorful bright",
    "blanc": "white bright",
    "noir": "black dark",
    "coloré": "colorful",
    "sombre": "dark night",
    "lumineux": "bright colorful",
}

def _translate_query(query: str) -> str:
    """Traduit les mots-clés français en anglais pour améliorer CLIP."""
    q_lower = query.lower().strip()
    # Chercher d'abord les expressions multi-mots
    for fr, en in sorted(_FR_EN.items(), key=lambda x: -len(x[0])):
        if fr in q_lower:
            q_lower = q_lower.replace(fr, en)
    return q_lower


# ── Recherche ─────────────────────────────────────────────────────────────────

def search_media(user_id: int, query: str, top_k: int = 10) -> list:
    import faiss
    results = {}

    # Traduire la requête FR→EN pour CLIP
    query_en = _translate_query(query)

    # 1. Recherche CLIP avec requête traduite EN + originale FR
    try:
        from ai_analyzer import get_clip_text_embedding
        # Essayer avec la version anglaise d'abord
        for q in [query_en, query]:
            clip_vec = get_clip_text_embedding(q)
            if clip_vec and len(clip_vec) == CLIP_DIM:
                arr = np.array([clip_vec], dtype="float32")
                norm = np.linalg.norm(arr)
                if norm > 0:
                    arr = arr / norm
                c_idx, c_meta = _clip_idx()
                if c_idx.ntotal > 0:
                    k = min(top_k * 3, c_idx.ntotal)
                    scores, indices = c_idx.search(arr, k)
                    for s, i in zip(scores[0], indices[0]):
                        if 0 <= i < len(c_meta) and c_meta[i]["user_id"] == user_id:
                            mid = c_meta[i]["media_id"]
                            results[mid] = max(results.get(mid, 0.0), float(s))
    except Exception as e:
        print(f"[FAISS CLIP] {e}")

    # 2. Recherche sémantique textuelle — aussi avec traduction
    try:
        for q in [query_en, query]:
            vec = _st().encode([q], normalize_embeddings=True).astype("float32")
            t_idx, t_meta = _text_idx()
            if t_idx.ntotal > 0:
                k = min(top_k * 3, t_idx.ntotal)
                scores, indices = t_idx.search(vec, k)
                for s, i in zip(scores[0], indices[0]):
                    if 0 <= i < len(t_meta) and t_meta[i]["user_id"] == user_id:
                        mid = t_meta[i]["media_id"]
                        text_score = float(s) * 0.8
                        results[mid] = max(results.get(mid, 0.0), text_score)
    except Exception as e:
        print(f"[FAISS TEXT] {e}")

    sorted_r = sorted(results.items(), key=lambda x: x[1], reverse=True)[:top_k]
    return [{"media_id": mid, "score": round(s, 4)} for mid, s in sorted_r]


# ── Suppression (reconstruction propre de l'index) ───────────────────────────

def remove_media(media_id: int):
    global _clip_index, _clip_meta, _text_index, _text_meta
    import faiss

    # Reconstruire l'index CLIP sans ce média
    _, c_meta = _clip_idx()
    new_c_meta = [m for m in c_meta if m["media_id"] != media_id]
    new_c_idx  = faiss.IndexFlatIP(CLIP_DIM)
    # Récupérer les embeddings depuis l'ancien index
    old_c_idx = _clip_index
    if old_c_idx is not None and old_c_idx.ntotal > 0:
        kept_positions = [i for i, m in enumerate(c_meta) if m["media_id"] != media_id]
        if kept_positions:
            all_vecs = old_c_idx.reconstruct_n(0, old_c_idx.ntotal)
            kept_vecs = np.array([all_vecs[i] for i in kept_positions], dtype="float32")
            new_c_idx.add(kept_vecs)
    _clip_index = new_c_idx
    _clip_meta  = new_c_meta
    _save_clip(new_c_idx, new_c_meta)

    # Reconstruire l'index TEXT sans ce média
    _, t_meta = _text_idx()
    new_t_meta = [m for m in t_meta if m["media_id"] != media_id]
    new_t_idx  = faiss.IndexFlatIP(TEXT_DIM)
    old_t_idx  = _text_index
    if old_t_idx is not None and old_t_idx.ntotal > 0:
        kept_positions = [i for i, m in enumerate(t_meta) if m["media_id"] != media_id]
        if kept_positions:
            all_vecs = old_t_idx.reconstruct_n(0, old_t_idx.ntotal)
            kept_vecs = np.array([all_vecs[i] for i in kept_positions], dtype="float32")
            new_t_idx.add(kept_vecs)
    _text_index = new_t_idx
    _text_meta  = new_t_meta
    _save_text(new_t_idx, new_t_meta)
