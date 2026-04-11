import { Router, Request, Response } from 'express';
import prisma from '../prismaClient'; 
import { upload } from '../utils/fileStorage'; 

const router = Router();

// Configuration dynamique pour les URLs (Évite les problèmes si l'IP change)
const getBaseUrl = (req: Request) => `${req.protocol}://${req.get('host')}`;

// Helper pour formater les URLs des images
const formatImageUrl = (req: Request, path: string | null) => {
    if (!path) return null;
    if (path.startsWith('http')) return path;
    return `${getBaseUrl(req)}/uploads/${path}`;
};

// ============================================================
// 1. MISE À JOUR MÉDIA (AVATAR / COVER) + AUTO-POST
// ============================================================
router.put('/update-media', upload.single('file'), async (req: Request, res: Response) => {
    try {
        const { userId, type } = req.body; // type: 'avatar' ou 'cover'
        const file = req.file;

        if (!file || !userId || userId === 'undefined') {
            return res.status(400).json({ error: "Données ou fichier manquants" });
        }

        const fileName = file.filename;
        const cleanUserId = String(userId).trim();

        // 1. Mise à jour de l'utilisateur dans la base Supabase
        const updatedUser = await prisma.users.update({
            where: { id: cleanUserId },
            data: type === 'avatar' ? { img_url: fileName } : { cover_url: fileName }
        });

        // 2. CRÉATION AUTOMATIQUE DU POST (Le rugissement du Lion)
        const autoPost = await prisma.post.create({
            data: {
                authorId: cleanUserId,
                content: type === 'avatar' 
                    ? "A mis à jour sa photo de profil ! 🦁" 
                    : "A changé sa photo de couverture ! 📸",
                mediaUrl: fileName,
                type: 'IMAGE'
            },
            include: {
                author: {
                    select: { id: true, full_name: true, img_url: true, is_certified: true }
                }
            }
        });

        // Formater les URLs pour le retour API et Socket
        const formattedPost = {
            ...autoPost,
            mediaUrl: formatImageUrl(req, autoPost.mediaUrl),
            author: {
                ...autoPost.author,
                img_url: formatImageUrl(req, autoPost.author.img_url)
            }
        };

        // 3. Notification temps réel via Socket.io pour rafraîchir le Home
        const io = req.app.get('io');
        if (io) io.emit('new_post', formattedPost);

        res.json({ 
            success: true, 
            user: {
                ...updatedUser,
                img_url: formatImageUrl(req, updatedUser.img_url),
                cover_url: formatImageUrl(req, updatedUser.cover_url)
            },
            post: formattedPost 
        });

    } catch (e) {
        console.error("❌ Erreur Update Media Profil:", e);
        res.status(500).json({ error: "Erreur lors de la mise à jour du média" });
    }
});

// ==========================================
// 2. RÉCUPÉRER LES DONNÉES DU PROFIL
// ==========================================
router.get('/:userId', async (req: Request, res: Response) => {
    const { userId } = req.params;
    const currentVisitorId = req.query.visitorId as string; 

    try {
        const cleanUserId = String(userId).trim();
        const userProfile = await prisma.users.findUnique({
            where: { id: cleanUserId },
            include: {
                _count: {
                    select: {
                        followers: true,  
                        following: true,  
                        posts: true,      
                    }
                },
                // Vérifier si le visiteur suit déjà ce profil
                followers: currentVisitorId ? {
                    where: { followerId: String(currentVisitorId).trim() }
                } : false
            }
        });

        if (!userProfile) {
            return res.status(404).json({ error: "Lion non trouvé dans la tanière" });
        }

        res.json({
            success: true,
            user: {
                ...userProfile,
                img_url: formatImageUrl(req, userProfile.img_url),
                cover_url: formatImageUrl(req, userProfile.cover_url),
                isFollowing: userProfile.followers ? userProfile.followers.length > 0 : false
            }
        });
    } catch (e) {
        console.error("❌ Erreur Get Profil:", e);
        res.status(500).json({ error: "Erreur lors de la récupération du profil" });
    }
});

// ==========================================
// 3. MISE À JOUR DU PROFIL (NOM & BIO)
// ==========================================
router.put('/update', async (req: Request, res: Response) => {
    const { userId, fullName, bio } = req.body;

    try {
        const cleanUserId = String(userId).trim();
        const updatedUser = await prisma.users.update({
            where: { id: cleanUserId },
            data: {
                full_name: fullName,
                bio: bio,
            }
        });

        res.json({ 
            success: true, 
            message: "Profil mis à jour avec succès",
            user: {
                ...updatedUser,
                img_url: formatImageUrl(req, updatedUser.img_url),
                cover_url: formatImageUrl(req, updatedUser.cover_url)
            }
        });
    } catch (e) {
        res.status(500).json({ error: "Impossible de mettre à jour les informations" });
    }
});

// ==========================================
// 4. SYSTÈME DE FOLLOW / UNFOLLOW
// ==========================================
router.post('/follow', async (req: Request, res: Response) => {
    const { followerId, followingId } = req.body;

    if (!followerId || !followingId) return res.status(400).json({ error: "IDs manquants" });
    if (followerId === followingId) {
        return res.status(400).json({ error: "Un lion ne peut pas se suivre lui-même" });
    }

    try {
        const fId = String(followerId).trim();
        const targetId = String(followingId).trim();

        const existingFollow = await prisma.follow.findUnique({
            where: {
                followerId_followingId: { followerId: fId, followingId: targetId }
            }
        });

        if (existingFollow) {
            // Unfollow
            await prisma.follow.delete({
                where: {
                    followerId_followingId: { followerId: fId, followingId: targetId }
                }
            });
            return res.json({ success: true, isFollowing: false });
        } else {
            // Follow
            await prisma.follow.create({
                data: { followerId: fId, followingId: targetId }
            });
            return res.json({ success: true, isFollowing: true });
        }
    } catch (e) {
        res.status(500).json({ error: "Erreur lors de l'opération de suivi" });
    }
});

// ==========================================
// 5. RÉCUPÉRER LES PUBLICATIONS D'UN LION
// ==========================================
router.get('/:userId/posts', async (req: Request, res: Response) => {
    const { userId } = req.params;

    try {
        const cleanUserId = String(userId).trim();
        const userPosts = await prisma.post.findMany({
            where: { authorId: cleanUserId },
            orderBy: { createdAt: 'desc' },
            include: {
                _count: {
                    select: { likes: true, comments: true }
                },
                author: {
                    select: { id: true, full_name: true, img_url: true, is_certified: true }
                }
            }
        });

        const formattedPosts = userPosts.map(post => ({
            ...post,
            mediaUrl: formatImageUrl(req, post.mediaUrl),
            author: {
                ...post.author,
                img_url: formatImageUrl(req, post.author.img_url)
            }
        }));

        res.json({ success: true, posts: formattedPosts });
    } catch (e) {
        res.status(500).json({ error: "Erreur lors de la récupération des posts" });
    }
});

export default router;