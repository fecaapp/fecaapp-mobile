import express from 'express';
import http from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import path from 'path';
import dotenv from 'dotenv';
import fs from 'fs'; 

// Import de tes routes existantes
import authRoutes from './routes/auth';
import adminRoutes from './routes/admin';
import matchesRoutes from './routes/matches';
import certificationRoutes from './routes/certification';
import talentRoutes from './routes/talents';
import museumRoutes from './routes/museum';
import chatRoutes from './routes/chat';
import socialRoutes from './routes/social'; 

// AJOUT DE LA ROUTE PROFILE (Pour les Lions)
import profileRoutes from './routes/profile'; 

dotenv.config();

const app = express();
const server = http.createServer(app);

// Configuration Socket.io (Le moteur du rugissement en temps réel)
const io = new Server(server, {
  cors: { origin: "*", methods: ["GET", "POST"] }
});

// On rend io accessible dans toutes les routes via req.app.get('io')
app.set('io', io);

// Middlewares
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ==========================================
// CONFIGURATION ET ACCÈS AUX UPLOADS
// ==========================================
// On s'assure que les dossiers existent pour éviter les erreurs 500
const folders = ['uploads', 'uploads/avatars', 'uploads/posts', 'uploads/statuses'];
folders.forEach(folder => {
  if (!fs.existsSync(folder)) {
    fs.mkdirSync(folder, { recursive: true });
    console.log(`📂 Dossier créé : ${folder}`);
  }
});

// Rend le dossier 'uploads' public pour que Flutter puisse lire les images
// Utilisation de la méthode la plus stable pour ton environnement
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// Branchement des API
app.use('/api/auth', authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/matches', matchesRoutes);
app.use('/api/certifications', certificationRoutes);
app.use('/api/talents', talentRoutes);
app.use('/api/museum', museumRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/social', socialRoutes); // Gère les Posts et Status
app.use('/api/profile', profileRoutes);

// ==========================================
// GESTION SOCKET.IO (LOGIQUE DE SALONS)
// ==========================================
io.on('connection', (socket) => {
  console.log(`🟢 Lion connecté : ${socket.id}`);

  // Rejoindre un salon personnel pour les notifications privées
  socket.on('join_private', (userId: string) => {
    socket.join(`user_${userId}`);
    console.log(`👤 User ${userId} a rejoint son salon privé.`);
  });

  // Rejoindre un salon de groupe (Match, Club, etc.)
  socket.on('join_group', (groupId: string) => {
    socket.join(`group_${groupId}`);
    console.log(`👨‍👩‍👧‍👦 Groupe ${groupId} rejoint par socket ${socket.id}`);
  });

  socket.on('disconnect', () => {
    console.log(`🔴 Lion déconnecté : ${socket.id}`);
  });
});

// Lancement du serveur
// On utilise '0.0.0.0' pour que le serveur accepte les connexions de ton modem/téléphone
const PORT = Number(process.env.PORT) || 4000;

server.listen(PORT, '0.0.0.0', () => {
  console.log("-------------------------------------------------------");
  console.log(`🚀 SERVEUR FECA-API DÉMARRÉ SUR LE PORT : ${PORT}`);
  console.log(`🔗 BASE BDD          : SUPABASE (Cloud)`);
  console.log(`⚽ MATCHES           : /api/matches/all`);
  console.log(`🛡️  ADMIN PENDING     : /api/admin/certifications/pending`);
  console.log(`🏛️  MUSEUM & LEGENDS  : /api/museum/all`);
  console.log(`📱 SOCIAL API       : /api/social/posts`);
  console.log(`📂 UPLOADS PUBLIC    : /uploads/`);
  console.log("-------------------------------------------------------");
  console.log(`💡 Note: Le Lion est prêt à rugir sur le réseau Supabase.`);
});