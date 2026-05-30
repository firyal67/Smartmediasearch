import os
import numpy as np

_mobilenet = None
_mobilenet_pre = None
_labels = []
_clip_model = None
_clip_pre = None
_clip_tok = None

# ── Concepts sémantiques (en anglais, CLIP natif) ─────────────────────────────
SEMANTIC_CONCEPTS = [
    # Actions
    "a photo of someone drinking", "a photo of someone eating",
    "a photo of someone running", "a photo of someone walking",
    "a photo of someone sleeping", "a photo of someone working at a desk",
    "a photo of someone playing", "a photo of someone cooking",
    "a photo of someone reading", "a photo of someone driving",
    "a photo of someone swimming", "a photo of someone dancing",
    "a photo of people talking", "a photo of someone laughing",
    "a photo of someone sitting", "a photo of someone standing",
    # Objets
    "a water bottle", "a glass of water", "a drink",
    "food on a plate", "a cup of coffee", "fruits",
    "vegetables", "flowers", "trees", "a car",
    "a smartphone", "a computer", "a book", "a table",
    # Lieux
    "a beach", "a mountain", "a forest", "a city street",
    "a house", "an office", "a kitchen", "a bedroom",
    "a park", "a restaurant", "a school",
    # Personnes
    "a person", "a man", "a woman", "a child", "a baby",
    "a group of people", "a face portrait", "a selfie",
    # Animaux
    "a dog", "a cat", "a bird", "a fish", "a horse",
    # Thèmes
    "nature landscape", "travel photography", "sport activity",
    "music performance", "art painting", "technology gadget",
    "family together", "friends together", "a celebration party",
    "a wedding", "shopping",
    # Ambiance
    "a sunset", "a sunrise", "night scene",
    "indoor scene", "outdoor scene",
    "colorful image", "dark image", "bright image",
]


def _load_mobilenet():
    global _mobilenet, _mobilenet_pre, _labels
    if _mobilenet:
        return
    import torch
    import torchvision.models as models
    from torchvision import transforms
    w = models.MobileNet_V3_Small_Weights.DEFAULT
    _mobilenet = models.mobilenet_v3_small(weights=w)
    _mobilenet.eval()
    _mobilenet_pre = transforms.Compose([ 
        transforms.Resize(256),
        transforms.CenterCrop(224),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])
    _labels = w.meta["categories"]


def _load_clip():
    global _clip_model, _clip_pre, _clip_tok
    if _clip_model:
        return
    import open_clip
    _clip_model, _, _clip_pre = open_clip.create_model_and_transforms(
        "ViT-B-32", pretrained="openai"
    )
    _clip_model.eval()
    _clip_tok = open_clip.get_tokenizer("ViT-B-32")


def _normalize(vec: np.ndarray) -> np.ndarray:
    """Normalise L2 un vecteur numpy."""
    n = np.linalg.norm(vec)
    return vec / n if n > 1e-8 else vec


def _clip_img_emb(pil_img) -> list:
    """Retourne l'embedding CLIP normalisé d'une image PIL."""
    try:
        import torch
        _load_clip()
        t = _clip_pre(pil_img).unsqueeze(0)
        with torch.no_grad():
            f = _clip_model.encode_image(t)
        # Normalisation L2 propre
        f = f.squeeze(0).float().numpy()
        f = _normalize(f)
        return f.tolist()
    except Exception as e:
        print(f"[CLIP img emb] {e}")
        return []


def get_clip_text_embedding(text: str) -> list:
    """Retourne l'embedding CLIP normalisé d'un texte."""
    try:
        import torch
        _load_clip()
        # Tronquer à 77 tokens (limite CLIP)
        tokens = _clip_tok([text[:200]])
        with torch.no_grad():
            f = _clip_model.encode_text(tokens)
        f = f.squeeze(0).float().numpy()
        f = _normalize(f)
        return f.tolist()
    except Exception as e:
        print(f"[CLIP txt emb] {e}")
        return []


def get_clip_semantic_tags(pil_img, top_n: int = 8) -> list:
    """
    Utilise CLIP pour trouver les concepts les plus proches de l'image.
    Utilise la similarité cosinus brute (pas softmax) pour un seuillage correct.
    """
    try:
        import torch
        _load_clip()

        # Encoder l'image
        img_t = _clip_pre(pil_img).unsqueeze(0)
        with torch.no_grad():
            img_feat = _clip_model.encode_image(img_t)
        img_feat = img_feat.squeeze(0).float().numpy()
        img_feat = _normalize(img_feat)

        # Encoder tous les concepts en batch
        tokens = _clip_tok(SEMANTIC_CONCEPTS)
        with torch.no_grad():
            text_feat = _clip_model.encode_text(tokens)
        text_feat = text_feat.float().numpy()
        # Normaliser chaque vecteur texte
        norms = np.linalg.norm(text_feat, axis=1, keepdims=True)
        text_feat = text_feat / np.maximum(norms, 1e-8)

        # Similarité cosinus = produit scalaire (vecteurs normalisés)
        sims = text_feat @ img_feat  # shape: (N,)

        # Prendre les top_n concepts avec similarité > 0.20
        threshold = 0.20
        top_idx = np.argsort(sims)[::-1]
        matched = []
        for i in top_idx:
            if sims[i] >= threshold:
                # Extraire le concept sans "a photo of"
                concept = SEMANTIC_CONCEPTS[i]
                concept = concept.replace("a photo of someone ", "")
                concept = concept.replace("a photo of people ", "")
                concept = concept.replace("a photo of ", "")
                concept = concept.replace("an ", "").replace("a ", "")
                matched.append(concept.strip())
            if len(matched) >= top_n:
                break

        # Garantir au moins top-3 même sous le seuil
        if len(matched) < 3:
            for i in top_idx[:3]:
                concept = SEMANTIC_CONCEPTS[i]
                concept = concept.replace("a photo of someone ", "")
                concept = concept.replace("a photo of people ", "")
                concept = concept.replace("a photo of ", "")
                concept = concept.replace("an ", "").replace("a ", "")
                c = concept.strip()
                if c not in matched:
                    matched.append(c)

        return matched[:top_n]
    except Exception as e:
        print(f"[CLIP semantic tags] {e}")
        return []


def analyze_image(file_path: str) -> dict:
    try:
        from PIL import Image
        import torch
        _load_mobilenet()

        img = Image.open(file_path).convert("RGB")

        # MobileNet → labels précis ImageNet
        t = _mobilenet_pre(img).unsqueeze(0)
        with torch.no_grad():
            probs = torch.softmax(_mobilenet(t)[0], dim=0)
        top5 = torch.topk(probs, 5)
        objects = [_labels[i] for i in top5.indices.tolist()]

        # CLIP → embedding visuel normalisé
        embedding = _clip_img_emb(img)

        # CLIP → tags sémantiques via similarité cosinus
        semantic_tags = get_clip_semantic_tags(img)

        return {
            "objects": objects,
            "confidence": round(float(top5.values[0]), 4),
            "embedding": embedding,
            "semantic_tags": semantic_tags,
        }
    except Exception as e:
        print(f"[analyze_image] {e}")
        return {"objects": [], "confidence": 0.0, "embedding": [], "semantic_tags": []}


def analyze_video(file_path: str, fps_sample: int = 1) -> dict:
    try:
        import cv2
        from PIL import Image
        import torch
        from collections import Counter
        _load_mobilenet()

        cap = cv2.VideoCapture(file_path)
        if not cap.isOpened():
            return {"objects": [], "confidence": 0.0, "embedding": [], "frames_analyzed": 0, "semantic_tags": []}

        fps = cap.get(cv2.CAP_PROP_FPS) or 25
        interval = max(1, int(fps / fps_sample))
        all_obj = []
        embeddings = []
        all_semantic = []
        idx = 0

        while True:
            ret, frame = cap.read()
            if not ret:
                break
            if idx % interval == 0:
                pil = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
                t = _mobilenet_pre(pil).unsqueeze(0)
                with torch.no_grad():
                    probs = torch.softmax(_mobilenet(t)[0], dim=0)
                for i in torch.topk(probs, 3).indices.tolist():
                    all_obj.append(_labels[i])
                emb = _clip_img_emb(pil)
                if emb:
                    embeddings.append(emb)
                sem = get_clip_semantic_tags(pil)
                all_semantic.extend(sem)
            idx += 1
        cap.release()

        counter = Counter(all_obj)
        top_objects = [o for o, _ in counter.most_common(5)]

        # Moyenne des embeddings + renormalisation
        avg_emb = []
        if embeddings:
            arr = np.array(embeddings, dtype=np.float32).mean(axis=0)
            avg_emb = _normalize(arr).tolist()

        sem_counter = Counter(all_semantic)
        top_semantic = [t for t, _ in sem_counter.most_common(8)]

        return {
            "objects": top_objects,
            "confidence": round(counter.most_common(1)[0][1] / max(1, idx // interval), 4) if counter else 0.0,
            "embedding": avg_emb,
            "frames_analyzed": idx // max(1, interval),
            "semantic_tags": top_semantic,
        }
    except Exception as e:
        print(f"[analyze_video] {e}")
        return {"objects": [], "confidence": 0.0, "embedding": [], "frames_analyzed": 0, "semantic_tags": []}
