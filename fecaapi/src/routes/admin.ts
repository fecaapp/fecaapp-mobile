import express from 'express';
import prisma from '../prismaClient';
import authenticate from '../middleware/auth';

const router = express.Router();

/**
 * Middleware de sécurité Admin
 * Vérifie le secret X-Admin-Secret dans les headers pour autoriser l'accès
 */
const requireAdminHeader = (req: any, res: any, next: any) => {
  const adminSecret = process.env.ADMIN_SECRET;
  const header = req.headers['x-admin-secret'];
  
  if (!adminSecret || header !== adminSecret) {
    return res.status(403).json({ error: 'Admin secret requis ou invalide' });
  }
  next();
};

/**
 * GET /admin/certifications/pending 
 * Récupère les certifications avec le statut 'pending'
 */
router.get('/certifications/pending', authenticate, requireAdminHeader, async (_req, res) => {
  try {
    const pending = await prisma.certifications.findMany({ 
      where: { status: 'pending' }, 
      include: { 
        user: {
          select: {
            id: true,
            full_name: true,
            email: true,
            img_url: true,
            is_certified: true
          }
        } 
      },
      orderBy: { submitted_at: 'asc' }, 
    });
    res.json(pending);
  } catch (err) {
    console.error("❌ Erreur Fetch Pending Admin:", err);
    res.status(500).json({ error: 'Erreur lors de la récupération des données' });
  }
});

/**
 * PUT /admin/certifications/:id
 * Mise à jour générique du statut (approved ou rejected)
 */
router.put('/certifications/:id', authenticate, requireAdminHeader, async (req: any, res) => {
  try {
    const { id } = req.params; 
    const { status } = req.body; 

    const cert = await prisma.certifications.update({
      where: { id: id },
      data: {
        status: status,
        reviewed_at: new Date()
      }
    });

    // Si le statut est 'approved', on valide automatiquement le badge sur le profil user
    if (status === 'approved' && cert.user_id) {
      await prisma.users.update({
        where: { id: cert.user_id },
        data: { is_certified: true }
      });
    }

    res.json({ message: `Statut mis à jour avec succès : ${status}`, cert });
  } catch (err) {
    console.error("❌ Erreur Update Admin:", err);
    res.status(500).json({ error: 'Erreur lors de la mise à jour' });
  }
});

/**
 * POST /admin/certifications/:id/approve
 * Route directe pour approuver une certification
 */
router.post('/certifications/:id/approve', authenticate, requireAdminHeader, async (req: any, res) => {
  try {
    const { id } = req.params; 
    
    const cert = await prisma.certifications.update({
      where: { id: id },
      data: {
        status: 'approved',
        reviewed_at: new Date()
      }
    });

    if (cert.user_id) {
      await prisma.users.update({
        where: { id: cert.user_id },
        data: { is_certified: true }
      });
    }
    res.json({ message: 'Certification approuvée et profil mis à jour', cert });
  } catch (err) {
    console.error("❌ Erreur Approve Admin:", err);
    res.status(500).json({ error: 'Erreur lors de l\'approbation' });
  }
});

/**
 * POST /admin/certifications/:id/reject
 * Route directe pour rejeter une certification
 */
router.post('/certifications/:id/reject', authenticate, requireAdminHeader, async (req: any, res) => {
  try {
    const { id } = req.params;
    
    const cert = await prisma.certifications.update({
      where: { id: id },
      data: {
        status: 'rejected',
        reviewed_at: new Date()
      }
    });
    
    res.json({ message: 'Certification rejetée', cert });
  } catch (err) {
    console.error("❌ Erreur Reject Admin:", err);
    res.status(500).json({ error: 'Erreur lors du rejet' });
  }
});

export default router;