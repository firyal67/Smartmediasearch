import os, json
import numpy as np

CLIP_INDEX_PATH = "faiss_clip.bin"
CLIP_META_PATH  = "faiss_clip_meta.json"
TEXT_INDEX_PATH = "faiss_text.bin"
TEXT_META_PATH  = "faiss_text_meta.json"
CLIP_DIM = 512
TEXT_DIM = 384

_clip_index = None; _clip_meta = []
_text_index = None; _text_meta = []
_st_model = None


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
        if os.path.exists(CLIP_INDEX_PATH):
            _clip_index = faiss.read_index(CLIP_INDEX_PATH)
            _clip_meta = json.load(open(CLIP_META_PATH))
        else:
            _clip_index = faiss.IndexFlatIP(CLIP_DIM); _clip_meta = []
    return _clip_index, _clip_meta


def _text_idx():
    global _text_index, _text_meta
    if _text_index is None:
        import faiss
        if os.path.exists(TEXT_INDEX_PATH):
            _text_index = faiss.read_index(TEXT_INDEX_PATH)
            _text_meta = json.load(open(TEXT_META_PATH))
        else:
            _text_index = faiss.IndexFlatIP(TEXT_DIM); _text_meta = []
    return _text_index, _text_meta


def _save_clip():
    import faiss
    idx, meta = _clip_idx()
    faiss.write_index(idx, CLIP_INDEX_PATH)
    json.dump(meta, open(CLIP_META_PATH, "w"))


def _save_text():
    import faiss
    idx, meta = _text_idx()
    faiss.write_index(idx, TEXT_INDEX_PATH)
    json.dump(meta, open(TEXT_META_PATH, "w"))


def add_media(media_id: int, user_id: int, text: str, clip_embedding: list = None):
    vec = _st().encode([text], normalize_embeddings=True).astype("float32")
    idx, meta = _text_idx()
    idx.add(vec)
    meta.append({"media_id": media_id, "user_id": user_id, "text": text})
    _save_text()

    if clip_embedding and len(clip_embedding) == CLIP_DIM:
        arr = np.array([clip_embedding], dtype="float32")
        n = np.linalg.norm(arr)
        if n > 0: arr = arr / n
        c_idx, c_meta = _clip_idx()
        c_idx.add(arr)
        c_meta.append({"media_id": media_id, "user_id": user_id})
        _save_clip()


def search_media(user_id: int, query: str, top_k: int = 10) -> list:
    results = {}

    try:
        from ai_analyzer import get_clip_text_embedding
        clip_vec = get_clip_text_embedding(query)
        if clip_vec and len(clip_vec) == CLIP_DIM:
            import faiss
            arr = np.array([clip_vec], dtype="float32")
            arr = arr / (np.linalg.norm(arr) + 1e-8)
            c_idx, c_meta = _clip_idx()
            if c_idx.ntotal > 0:
                scores, indices = c_idx.search(arr, min(top_k*3, c_idx.ntotal))
                for s, i in zip(scores[0], indices[0]):
                    if 0 <= i < len(c_meta) and c_meta[i]["user_id"] == user_id:
                        mid = c_meta[i]["media_id"]
                        results[mid] = max(results.get(mid, 0.0), float(s))
    except Exception as e:
        print(f"[FAISS CLIP] {e}")

    try:
        vec = _st().encode([query], normalize_embeddings=True).astype("float32")
        t_idx, t_meta = _text_idx()
        if t_idx.ntotal > 0:
            scores, indices = t_idx.search(vec, min(top_k*3, t_idx.ntotal))
            for s, i in zip(scores[0], indices[0]):
                if 0 <= i < len(t_meta) and t_meta[i]["user_id"] == user_id:
                    mid = t_meta[i]["media_id"]
                    results[mid] = max(results.get(mid, 0.0), float(s) * 0.7)
    except Exception as e:
        print(f"[FAISS TEXT] {e}")

    sorted_r = sorted(results.items(), key=lambda x: x[1], reverse=True)[:top_k]
    return [{"media_id": mid, "score": round(s, 4)} for mid, s in sorted_r]


def remove_media(media_id: int):
    global _clip_meta, _text_meta
    _, cm = _clip_idx(); _clip_meta = [m for m in cm if m["media_id"] != media_id]; _save_clip()
    _, tm = _text_idx(); _text_meta = [m for m in tm if m["media_id"] != media_id]; _save_text()
