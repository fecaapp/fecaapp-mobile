import { Router, Request, Response } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
import prisma from '../prismaClient';
import multer from 'multer';
import path from 'path';
import fs from 'fs';

dotenv.config();
const JWT_SECRET = process.env.JWT_SECRET || 'dev_secret';

const router = Router();

// ==========================================
// CONFIGURATION MULTER POUR L'AVATAR
// ==========================================
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadPath = 'uploads/avatars/';
    if (!fs.existsSync(uploadPath)) {
      fs.mkdirSync(uploadPath, { recursive: true });
    }
    cb(null, uploadPath);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'avatar-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // Limite de 5MB
  fileFilter: (req, file, cb) => {
    const filetypes = /jpeg|jpg|png|webp/;
    const extname = filetypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = filetypes.test(file.mimetype);
    if (mimetype && extname) return cb(null, true);
    cb(new Error("Seules les images sont autorisées !"));
  }
});

// ==========================================
// 1. INSCRIPTION (REGISTER)
// ==========================================
router.post('/register', async (req: Request, res: Response) => {
  try {
    const { full_name, email, password, role } = req.body;

    if (!full_name || !email || !password || !role) {
      return res.status(400).json({ error: 'Tous les champs sont obligatoires' });
    }

    const existingUser = await prisma.users.findUnique({ where: { email } });
    if (existingUser) {
      return res.status(400).json({ error: 'Cet email est déjà utilisé par un autre Lion' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await prisma.users.create({
      data: { 
        full_name, 
        email, 
        role,
        password: hashedPassword,
        is_online: true,
        last_seen: new Date(),
        following_count: 0,
        followers_count: 0,
        is_certified: false
      }
    });

    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '7d' });

    return res.status(201).json({ 
      token, 
      user: { 
        id: user.id, 
        full_name: user.full_name, 
        email: user.email, 
        role: user.role, 
        img_url: user.img_url, 
        is_certified: user.is_certified 
      } 
    });
  } catch (err) {
    console.error("❌ Erreur Register:", err);
    return res.status(500).json({ error: 'Erreur lors de la création du compte' });
  }
});

// ==========================================
// 2. CONNEXION (LOGIN)
// ==========================================
router.post('/login', async (req: Request, res: Response) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email et mot de passe requis' });
    }

    const user = await prisma.users.findUnique({ where: { email } });
    if (!user) {
      return res.status(400).json({ error: 'Ce rugissement est inconnu' });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res.status(400).json({ error: 'Mot de passe incorrect' });
    }

    const updatedUser = await prisma.users.update({
      where: { id: user.id },
      data: { 
        is_online: true,
        last_seen: new Date()
      }
    });

    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '7d' });

    return res.json({ 
      token, 
      user: { 
        id: updatedUser.id, 
        full_name: updatedUser.full_name, 
        email: updatedUser.email, 
        role: updatedUser.role, 
        img_url: updatedUser.img_url, 
        is_certified: updatedUser.is_certified 
      } 
    });
  } catch (err) {
    console.error("❌ Erreur Login:", err);
    return res.status(500).json({ error: 'Erreur serveur lors de la connexion' });
  }
});

// ==========================================
// 3. MISE À JOUR DE LA PHOTO DE PROFIL
// ==========================================
router.post('/upload-avatar', upload.single('avatar'), async (req: Request, res: Response) => {
  try {
    const { userId } = req.body;

    if (!req.file) {
      return res.status(400).json({ error: "Aucune image reçue" });
    }

    if (!userId) {
      return res.status(400).json({ error: "ID utilisateur manquant" });
    }

    // On stocke le nom du fichier. Le formattage avec l'IP se fera dynamiquement
    // au moment du GET pour éviter les problèmes si l'IP change.
    const filename = req.file.filename;

    const updatedUser = await prisma.users.update({
      where: { id: userId.trim() },
      data: { img_url: filename }
    });

    return res.json({ 
      message: "Photo mise à jour !",
      img_url: updatedUser.img_url 
    });
  } catch (err) {
    console.error("❌ Erreur Upload Avatar:", err);
    return res.status(500).json({ error: "Erreur lors de l'enregistrement de l'image" });
  }
});

// ==========================================
// 4. DÉCONNEXION (LOGOUT)
// ==========================================
router.post('/logout', async (req: Request, res: Response) => {
  try {
    const { userId } = req.body;
    if (userId) {
      await prisma.users.update({
        where: { id: userId.trim() },
        data: { is_online: false, last_seen: new Date() }
      });
    }
    return res.json({ message: 'Déconnecté avec succès' });
  } catch (err) {
    return res.status(500).json({ error: 'Erreur lors de la déconnexion' });
  }
});

export default router;