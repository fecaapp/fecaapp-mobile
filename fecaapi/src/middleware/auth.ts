import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
import prisma from '../prismaClient';

dotenv.config();

const JWT_SECRET = process.env.JWT_SECRET || 'dev_secret';

// Extension de l'interface Request pour inclure l'utilisateur
export interface AuthRequest extends Request {
  user?: any;
}

/**
 * Middleware d'authentification principal
 * Vérifie le token JWT et injecte l'utilisateur dans la requête
 */
export const authenticate = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const authHeader = req.headers.authorization;
    
    // 1. Vérification de la présence du header
    if (!authHeader) {
      return res.status(401).json({ error: 'Token non fourni (No token provided)' });
    }

    // 2. Formatage attendu : "Bearer <TOKEN>"
    const parts = authHeader.split(' ');
    if (parts.length !== 2) {
      return res.status(401).json({ error: 'Erreur de format du token' });
    }

    const token = parts[1];

    // 3. Vérification du secret et décodage
    const decoded: any = jwt.verify(token, JWT_SECRET);

    // 4. Récupération de l'utilisateur sur Supabase via Prisma
    // Note : On s'assure que l'ID est bien traité comme un UUID
    const user = await prisma.users.findUnique({ 
      where: { id: decoded.userId } 
    });

    if (!user) {
      return res.status(401).json({ error: 'Utilisateur introuvable dans la base' });
    }

    // 5. On stocke l'utilisateur complet dans la requête pour les routes suivantes
    req.user = user;
    
    return next();
  } catch (err) {
    console.error("❌ Erreur Auth Middleware:", err);
    return res.status(401).json({ error: 'Session expirée ou token invalide' });
  }
};

/**
 * Middleware optionnel pour restreindre l'accès selon le rôle (ex: ADMIN)
 */
export const requireRole = (roles: string[]) => {
  return (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Non authentifié' });
    }
    
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Accès refusé : privilèges insuffisants' });
    }
    
    next();
  };
};

export default authenticate;