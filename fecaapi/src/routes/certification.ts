import { Router, Request, Response } from 'express';
import prisma from '../prismaClient';
import authenticate from '../middleware/auth';
import { upload } from '../utils/fileStorage';

const router = Router();

/**
 * POST /api/certifications/upload
 * Permet à un utilisateur de soumettre ses documents pour certification
 */
router.post('/upload', authenticate, upload.single('file'), async (req: Request, res: Response) => {
  try {
    const authenticatedReq = req as any; 
    const user = authenticatedReq.user;
    const file = req.file;
    
    // 1. Vérification du fichier
    if (!file) {
      return res.status(400).json({ error: 'Fichier (preuve de diplôme) manquant' });
    }

    const { diploma_type, institution } = req.body;

    // 2. Création de la certification dans Supabase
    const newCertification = await prisma.certifications.create({
      data: {
        // L'ID est généré automatiquement par Supabase (gen_random_uuid())
        user_id: user.id,
        proof_document_url: file.filename, // On stocke le nom du fichier
        status: 'pending',
        diploma_type: diploma_type || null, 
        institution: institution || null,
        submitted_at: new Date()
      }
    });

    // 3. On s'assure que le statut de l'utilisateur est bien "non certifié" tant que c'est pending
    await prisma.users.update({
      where: { id: user.id },
      data: { is_certified: false }
    });

    return res.json({ 
      message: 'Soumis avec succès ! Ton dossier est en cours de révision. ✅',
      certificationId: newCertification.id 
    });
  } catch (err) {
    console.error("❌ Erreur certification:", err);
    return res.status(500).json({ error: 'Erreur lors de l\'enregistrement de la certification' });
  }
});

/**
 * GET /api/certifications/me
 * Récupère l'historique des demandes de l'utilisateur connecté
 */
router.get('/me', authenticate, async (req: Request, res: Response) => {
  try {
    const authenticatedReq = req as any;
    const user = authenticatedReq.user;

    const list = await prisma.certifications.findMany({ 
      where: { user_id: user.id }, 
      orderBy: { submitted_at: 'desc' }
    });

    return res.json(list);
  } catch (err) {
    console.error("❌ Erreur Fetch Me Certifications:", err);
    return res.status(500).json({ error: 'Erreur serveur lors de la récupération' });
  }
});

export default router;