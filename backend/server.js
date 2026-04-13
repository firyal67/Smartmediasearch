require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const authRoutes = require('./routes/auth');
const mediaRoutes = require('./routes/media');
const User = require('./models/User');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/media', mediaRoutes);

mongoose.connect(process.env.MONGO_URI)
  .then(async () => {
    console.log('MongoDB connected');

    // Création du compte de test s'il n'existe pas
    const existingDemo = await User.findOne({ email: 'demo@smartmedia.com' });
    if (!existingDemo) {
      const demoUser = new User({
        email: 'demo@smartmedia.com',
        password: 'demo123'
      });
      await demoUser.save();
      console.log('✅ Compte de test créé : demo@smartmedia.com / demo123');
    } else {
      console.log('ℹ️ Compte de test existe déjà');
    }

    app.listen(5000, '0.0.0.0', () => {
    console.log("Server running");
  });
  })
  .catch(err => console.log('MongoDB error:', err));