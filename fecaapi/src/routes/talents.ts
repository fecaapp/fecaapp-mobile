import { Router, Request, Response } from 'express';
import prisma from '../prismaClient';

const router = Router();

// ==========================================
// 1. PUBLIER UN TALENT (VIDÉO)
// ==========================================
router.post('/upload', async (req: Request, res: Response) => {
  const { video_url, category, user_id, specialty, city } = req.body;

  // Validation des champs obligatoires
  if (!video_url || !category || !user_id) {
    return res.status(400).json({ error: "Le rugissement nécessite une vidéo, une catégorie et un auteur." });
  }

  try {
    const cleanUserId = String(user_id).trim();

    const newTalent = await prisma.talents.create({
      data: {
        // L'ID est généré automatiquement par Supabase (gen_random_uuid())
        video_url,
        category,
        user_id: cleanUserId,
        specialty: specialty || null,
        city: city || null,
        is_active: true
      },
      include: {
        user: { 
          select: { 
            full_name: true,
            img_url: true 
          } 
        }
      }
    });
    
    // Notification Socket.io si nécessaire pour le live feed des talents
    const io = req.app.get('io');
    if (io) io.emit('new_talent', newTalent);

    return res.status(201).json(newTalent);
  } catch (error) {
    console.error("❌ Erreur Enregistrement Talent:", error);
    return res.status(500).json({ error: "Erreur lors de l'enregistrement de ton talent." });
  }
});

// ==========================================
// 2. RÉCUPÉRER LES TALENTS PAR CATÉGORIE
// ==========================================
router.get('/:category', async (req: Request, res: Response) => {
  const { category } = req.params;

  try {
    const list = await prisma.talents.findMany({
      where: { 
        category: category, 
        is_active: true 
      },
      include: { 
        user: { 
          select: { 
            full_name: true, 
            img_url: true,
            is_certified: true 
          } 
        } 
      },
      orderBy: { 
        created_at: 'desc' 
      }
    });

    return res.json(list);
  } catch (error) {
    console.error("❌ Erreur Fetch Talents:", error);
    return res.status(500).json({ error: "Impossible de récupérer les talents de cette catégorie." });
  }
});

// ==========================================
// 3. SUPPRIMER UN TALENT
// ==========================================
router.delete('/:talentId', async (req: Request, res: Response) => {
  const { talentId } = req.params;
  const { userId } = req.body;

  try {
    const talent = await prisma.talents.findUnique({ where: { id: talentId } });

    if (!talent || talent.user_id !== userId) {
      return res.status(403).json({ error: "Action interdite." });
    }

    await prisma.talents.delete({ where: { id: talentId } });

    return res.json({ success: true, message: "Talent retiré avec succès." });
  } catch (error) {
    return res.status(500).json({ error: "Erreur lors de la suppression." });
  }
});

export default router;