import os, numpy as np
from pathlib import Path

_mobilenet = None; _mobilenet_pre = None; _labels = []
_clip_model = None; _clip_pre = None; _clip_tok = None


def _load_mobilenet():
    global _mobilenet, _mobilenet_pre, _labels
    if _mobilenet: return
    import torch
    import torchvision.models as models
    from torchvision import transforms
    w = models.MobileNet_V3_Small_Weights.DEFAULT
    _mobilenet = models.mobilenet_v3_small(weights=w); _mobilenet.eval()
    _mobilenet_pre = transforms.Compose([
        transforms.Resize(256), transforms.CenterCrop(224),
        transforms.ToTensor(),
        transforms.Normalize([0.485,0.456,0.406],[0.229,0.224,0.225]),
    ])
    _labels = w.meta["categories"]


def _load_clip():
    global _clip_model, _clip_pre, _clip_tok
    if _clip_model: return
    import open_clip
    _clip_model, _, _clip_pre = open_clip.create_model_and_transforms("ViT-B-32", pretrained="openai")
    _clip_model.eval()
    _clip_tok = open_clip.get_tokenizer("ViT-B-32")


def _clip_img_emb(pil_img):
    try:
        import torch; _load_clip()
        t = _clip_pre(pil_img).unsqueeze(0)
        with torch.no_grad():
            f = _clip_model.encode_image(t)
            f = f / f.norm(dim=-1, keepdim=True)
        return f[0].tolist()
    except Exception as e:
        print(f"[CLIP img] {e}"); return []


def get_clip_text_embedding(text: str):
    try:
        import torch; _load_clip()
        t = _clip_tok([text])
        with torch.no_grad():
            f = _clip_model.encode_text(t)
            f = f / f.norm(dim=-1, keepdim=True)
        return f[0].tolist()
    except Exception as e:
        print(f"[CLIP txt] {e}"); return []


def analyze_image(file_path: str) -> dict:
    try:
        from PIL import Image; import torch; _load_mobilenet()
        img = Image.open(file_path).convert("RGB")
        t = _mobilenet_pre(img).unsqueeze(0)
        with torch.no_grad():
            probs = torch.softmax(_mobilenet(t)[0], dim=0)
        top5 = torch.topk(probs, 5)
        objects = [_labels[i] for i in top5.indices.tolist()]
        return {"objects": objects, "confidence": round(float(top5.values[0]), 4), "embedding": _clip_img_emb(img)}
    except Exception as e:
        print(f"[AI img] {e}"); return {"objects": [], "confidence": 0.0, "embedding": []}


def analyze_video(file_path: str, fps_sample: int = 1) -> dict:
    try:
        import cv2; from PIL import Image; import torch
        from collections import Counter
        _load_mobilenet()
        cap = cv2.VideoCapture(file_path)
        if not cap.isOpened(): return {"objects": [], "confidence": 0.0, "embedding": [], "frames_analyzed": 0}
        interval = max(1, int((cap.get(cv2.CAP_PROP_FPS) or 25) / fps_sample))
        all_obj = []; embeddings = []; idx = 0
        while True:
            ret, frame = cap.read()
            if not ret: break
            if idx % interval == 0:
                pil = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
                t = _mobilenet_pre(pil).unsqueeze(0)
                with torch.no_grad():
                    probs = torch.softmax(_mobilenet(t)[0], dim=0)
                for i in torch.topk(probs, 3).indices.tolist():
                    all_obj.append(_labels[i])
                emb = _clip_img_emb(pil)
                if emb: embeddings.append(emb)
            idx += 1
        cap.release()
        counter = Counter(all_obj)
        top = [o for o, _ in counter.most_common(5)]
        avg_emb = []
        if embeddings:
            arr = np.array(embeddings, dtype=np.float32).mean(axis=0)
            n = np.linalg.norm(arr)
            avg_emb = (arr / n).tolist() if n > 0 else arr.tolist()
        return {"objects": top, "confidence": round(counter.most_common(1)[0][1] / max(1, idx//interval), 4) if counter else 0.0, "embedding": avg_emb, "frames_analyzed": idx//max(1,interval)}
    except Exception as e:
        print(f"[AI vid] {e}"); return {"objects": [], "confidence": 0.0, "embedding": [], "frames_analyzed": 0}
