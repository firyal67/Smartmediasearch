const Media = require('../models/Media');
const path = require('path');
const fs = require('fs');
const multer = require('multer');

// ══════════════════════════════════════════
//  CONFIGURATION MULTER
// ══════════════════════════════════════════
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = 'uploads/';
    if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const extFromMime = {
      'image/jpeg': '.jpg', 'image/jpg': '.jpg', 'image/png': '.png',
      'image/gif': '.gif', 'image/webp': '.webp',
      'video/mp4': '.mp4', 'video/mov': '.mov', 'video/quicktime': '.mov',
      'audio/mpeg': '.mp3', 'audio/mp3': '.mp3', 'audio/wav': '.wav',
      'audio/ogg': '.ogg',
      'application/pdf': '.pdf',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document': '.docx',
      'application/msword': '.doc',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '.xlsx',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation': '.pptx',
      'text/plain': '.txt',
    };
    const originalExt = path.extname(file.originalname).toLowerCase();
    const ext = originalExt || extFromMime[file.mimetype] || '';
    const uniqueName = Date.now() + '-' + Math.round(Math.random() * 1E9) + ext;
    cb(null, uniqueName);
  }
});

const ALLOWED_MIMETYPES = [
  'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp',
  'video/mp4', 'video/mov', 'video/quicktime', 'video/avi',
  'audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/ogg', 'audio/x-wav',
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'text/plain',
];

const ALLOWED_EXTENSIONS = /\.(jpeg|jpg|png|gif|webp|mp4|mov|avi|mp3|wav|ogg|pdf|docx|doc|xlsx|pptx|txt)$/i;

const fileFilter = (req, file, cb) => {
  const mimeOk = ALLOWED_MIMETYPES.includes(file.mimetype);
  const extOk  = ALLOWED_EXTENSIONS.test(path.extname(file.originalname).toLowerCase());
  if (mimeOk || extOk) return cb(null, true);
  console.warn(`[Upload] Rejeté — mimetype: ${file.mimetype}, originalname: ${file.originalname}`);
  cb(new Error(`Type de fichier non supporté: ${file.mimetype}`));
};

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 50 * 1024 * 1024 } // 50 MB
}).single('media');

// ══════════════════════════════════════════
//  UPLOAD
// ══════════════════════════════════════════
exports.uploadMedia = (req, res) => {
  upload(req, res, async (err) => {
    if (err) {
      console.error('[Upload] Erreur multer:', err.message);
      return res.status(400).json({ msg: err.message });
    }
    if (!req.file) {
      console.error('[Upload] req.file est undefined');
      return res.status(400).json({ msg: 'Aucun fichier reçu. Vérifiez le champ "media".' });
    }

    let type = 'document';
    if (req.file.mimetype.startsWith('image/')) type = 'image';
    else if (req.file.mimetype.startsWith('video/')) type = 'video';
    else if (req.file.mimetype.startsWith('audio/')) type = 'audio';

    try {
      const newMedia = new Media({
        userId: req.user.id,
        filename: req.file.filename,
        originalName: req.file.originalname || req.file.filename,
        type: type,
        size: req.file.size,
        filePath: req.file.path,
        analyzed: false,
        tags: []
      });
      await newMedia.save();

      // Simulation analyse IA asynchrone
      setTimeout(async () => {
        try {
          newMedia.analyzed = true;
          newMedia.tags = ['IA_analysed', type, 'automatic'];
          await newMedia.save();
          console.log(`✅ Analyse terminée pour ${newMedia.filename}`);
        } catch (e) {
          console.error('Erreur analyse async:', e);
        }
      }, 3000);

      res.json({ msg: 'Fichier uploadé, analyse en cours', media: newMedia });
    } catch (e) {
      console.error('[Upload] Erreur DB:', e);
      res.status(500).json({ msg: 'Erreur serveur lors de la sauvegarde' });
    }
  });
};

// ══════════════════════════════════════════
//  DASHBOARD
// ══════════════════════════════════════════
exports.getDashboard = async (req, res) => {
  try {
    const totalMedias    = await Media.countDocuments({ userId: req.user.id });
    const analyzedMedias = await Media.countDocuments({ userId: req.user.id, analyzed: true });
    const recentMedias   = await Media.find({ userId: req.user.id }).sort({ createdAt: -1 }).limit(5);
    const sizeResult     = await Media.aggregate([
      { $match: { userId: req.user.id } },
      { $group: { _id: null, totalSize: { $sum: '$size' } } }
    ]);
    const totalStorage = sizeResult[0]?.totalSize || 0;
    const storageInGB  = (totalStorage / (1024 * 1024 * 1024)).toFixed(2);
    res.json({ totalMedias, analyzedMedias, totalStorage: `${storageInGB} GB`, recentMedias });
  } catch (err) {
    console.error(err);
    res.status(500).send('Server error');
  }
};

// ══════════════════════════════════════════
//  GET ALL MEDIA
// ══════════════════════════════════════════
exports.getMedia = async (req, res) => {
  try {
    const media = await Media.find({ userId: req.user.id }).sort({ createdAt: -1 });
    res.json(media);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server error');
  }
};

// ══════════════════════════════════════════
//  DELETE MEDIA
// ══════════════════════════════════════════
exports.deleteMedia = async (req, res) => {
  try {
    const media = await Media.findById(req.params.id);

    if (!media) {
      return res.status(404).json({ msg: 'Média introuvable' });
    }

    // ✅ Utilise userId (cohérent avec le reste du controller)
    if (media.userId.toString() !== req.user.id) {
      return res.status(401).json({ msg: 'Non autorisé' });
    }

    // ✅ Supprime aussi le fichier physique du disque
    if (media.filePath && fs.existsSync(media.filePath)) {
      fs.unlinkSync(media.filePath);
    }

    await Media.findByIdAndDelete(req.params.id);

    res.status(200).json({ msg: 'Média supprimé avec succès' });
  } catch (err) {
    console.error('Erreur deleteMedia:', err.message);
    if (err.kind === 'ObjectId') {
      return res.status(404).json({ msg: 'Média introuvable (ID invalide)' });
    }
    res.status(500).json({ msg: 'Erreur serveur' });
  }
};