const mongoose = require('mongoose');

const MediaSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  filename: { type: String, required: true },
  originalName: { type: String },
  type: { type: String, enum: ['image', 'video', 'audio', 'document'], required: true },
  size: { type: Number, required: true },
  filePath: { type: String },
  analyzed: { type: Boolean, default: false },
  tags: [String],
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Media', MediaSchema);