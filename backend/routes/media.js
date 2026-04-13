const express = require('express');
const auth = require('../middleware/auth');
const { getDashboard, uploadMedia, getMedia, deleteMedia } = require('../controllers/mediaController');

const router = express.Router();

router.get('/dashboard', auth, getDashboard);
router.post('/upload', auth, uploadMedia);
router.get('/', auth, getMedia);
router.delete('/:id', auth, deleteMedia); // ✅ Route DELETE ajoutée

module.exports = router;