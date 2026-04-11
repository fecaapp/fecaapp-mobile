import { Router, Request, Response } from 'express';
import prisma from '../prismaClient';
import { upload } from '../utils/fileStorage';

const router = Router();

/**
 * Helper robuste pour formater les URLs des images.
 * Utilise l'hôte actuel de la requête pour garantir que Flutter accède au média.
 */
const formatImageUrl = (req: Request, path: string | null | undefined) => {
  if (!path || path === "" || path === "null" || path === "undefined") {
    return "https://via.placeholder.com/500"; 
  }
  if (path.startsWith('http')) return path;
  
  const host = req.get('host');
  const protocol = req.protocol;
  const cleanPath = path.startsWith('/') ? path.substring(1) : path;
  
  return `${protocol}://${host}/uploads/${cleanPath}`;
};

// ==========================================
// 1. CRÉATION DE CONTENU (POSTS)
// ==========================================
router.post('/posts', upload.single('media'), async (req: Request, res: Response) => {
  try {
    const { userId, content, type } = req.body;
    const file = req.file;

    if (!userId || userId === 'undefined') {
      return res.status(400).json({ error: "L'ID utilisateur est requis." });
    }

    const post = await prisma.post.create({
      data: {
        content: content || "",
        mediaUrl: file ? file.filename : null,
        type: type || 'IMAGE',
        authorId: userId.trim(), 
      },
      include: {
        author: {
          select: { id: true, full_name: true, img_url: true, is_certified: true }
        },
        _count: { select: { likes: true, comments: true } }
      }
    });

    const formattedPost = {
      ...post,
      mediaUrl: formatImageUrl(req, post.mediaUrl),
      author: {
        ...post.author,
        img_url: formatImageUrl(req, post.author.img_url)
      }
    };

    // Signal temps réel pour le Home Screen
    const io = req.app.get('io');
    if (io) io.emit('new_post', formattedPost);

    return res.status(201).json(formattedPost);
  } catch (err) {
    console.error("❌ Erreur Create Post:", err);
    return res.status(500).json({ error: 'Erreur serveur lors de la publication.' });
  }
});

// ==========================================
// 2. FLUX DE PUBLICATIONS (HOME FEED & PROFILE)
// ==========================================
router.get('/posts', async (req: Request, res: Response) => {
  try {
    const { userId, authorId, page = "1", limit = "10" } = req.query;

    const p = parseInt(page as string) || 1;
    const l = parseInt(limit as string) || 10;
    const skip = (p - 1) * l;

    const posts = await prisma.post.findMany({
      where: authorId ? { authorId: String(authorId).trim() } : {},
      orderBy: { createdAt: 'desc' },
      skip: skip,
      take: l,
      include: {
        author: {
          select: { id: true, full_name: true, img_url: true, is_certified: true }
        },
        _count: { select: { likes: true, comments: true } },
        likes: {
          where: { userId: userId ? String(userId).trim() : undefined }, 
          select: { id: true }
        }
      }
    });

    const formattedPosts = posts.map(post => ({
      ...post,
      mediaUrl: formatImageUrl(req, post.mediaUrl),
      isLiked: post.likes.length > 0,
      likesCount: post._count.likes,
      commentsCount: post._count.comments,
      author: {
        ...post.author,
        img_url: formatImageUrl(req, post.author.img_url)
      },
      likes: undefined 
    }));

    return res.json(formattedPosts);
  } catch (err) {
    console.error("❌ Erreur Fetch Posts:", err);
    return res.status(500).json({ error: 'Erreur de chargement du flux.' });
  }
});

// ==========================================
// 3. SYSTÈME DE LIKES (TOGGLE)
// ==========================================
router.post('/posts/:postId/like', async (req: Request, res: Response) => {
  try {
    const { userId } = req.body;
    const { postId } = req.params;

    if (!userId || !postId) return res.status(400).json({ error: "Données manquantes." });

    const existing = await prisma.like.findUnique({
      where: { 
        userId_postId: { 
          userId: String(userId).trim(), 
          postId: String(postId).trim() 
        } 
      }
    });

    if (existing) {
      await prisma.like.delete({ where: { id: existing.id } });
      return res.json({ liked: false });
    }

    await prisma.like.create({
      data: { userId: String(userId).trim(), postId: String(postId).trim() }
    });

    return res.json({ liked: true });
  } catch (err) {
    console.error("❌ Erreur Like Toggle:", err);
    return res.status(500).json({ error: 'Erreur sur le like.' });
  }
});

// ==========================================
// 4. COMMENTAIRES
// ==========================================
router.post('/posts/:postId/comment', async (req: Request, res: Response) => {
  try {
    const { userId, content, parentId } = req.body;
    const { postId } = req.params;

    const comment = await prisma.comment.create({
      data: {
        content,
        authorId: String(userId).trim(),
        postId: String(postId).trim(),
        parentId: parentId ? String(parentId).trim() : null
      },
      include: { 
        author: { select: { full_name: true, img_url: true, is_certified: true } } 
      }
    });

    const formattedComment = {
      ...comment,
      author: {
        ...comment.author,
        img_url: formatImageUrl(req, comment.author.img_url)
      }
    };

    return res.status(201).json(formattedComment);
  } catch (err) {
    console.error("❌ Erreur Commentaire:", err);
    return res.status(500).json({ error: 'Erreur sur le commentaire.' });
  }
});

// ==========================================
// 5. STATUTS (STORIES)
// ==========================================
router.post('/statuses', upload.single('media'), async (req: Request, res: Response) => {
  try {
    const { userId, type } = req.body;
    const file = req.file;

    if (!file && type !== 'TEXT') {
      return res.status(400).json({ error: "Un fichier média est requis." });
    }

    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + 24);

    const status = await prisma.status.create({
      data: {
        authorId: String(userId).trim(),
        mediaUrl: file ? file.filename : "",
        type: type || 'IMAGE', 
        expiresAt
      }
    });

    return res.status(201).json({
      ...status,
      mediaUrl: formatImageUrl(req, status.mediaUrl)
    });
  } catch (err) {
    console.error("❌ Erreur Création Statut:", err);
    return res.status(500).json({ error: 'Erreur création statut.' });
  }
});

router.get('/statuses', async (req: Request, res: Response) => {
  try {
    const { userId } = req.query;
    const now = new Date();

    const statuses = await prisma.status.findMany({
      where: { expiresAt: { gt: now } },
      include: {
        author: { select: { id: true, full_name: true, img_url: true } },
        viewers: { where: { userId: userId ? String(userId).trim() : undefined } }
      },
      orderBy: { createdAt: 'desc' }
    });

    return res.json(statuses.map(s => ({
      ...s,
      mediaUrl: formatImageUrl(req, s.mediaUrl),
      isViewed: s.viewers.length > 0,
      author: {
        ...s.author,
        img_url: formatImageUrl(req, s.author.img_url)
      },
      viewers: undefined
    })));
  } catch (err) {
    console.error("❌ Erreur Fetch Statuts:", err);
    return res.status(500).json({ error: 'Erreur statuts.' });
  }
});

// ==========================================
// 6. SYSTÈME DE VUES (STORIES)
// ==========================================
router.post('/statuses/:statusId/view', async (req: Request, res: Response) => {
  try {
    const { userId } = req.body;
    const { statusId } = req.params;

    await prisma.statusView.upsert({
      where: { 
        userId_statusId: { 
          userId: String(userId).trim(), 
          statusId: String(statusId).trim() 
        } 
      },
      update: { viewedAt: new Date() },
      create: { 
        userId: String(userId).trim(), 
        statusId: String(statusId).trim() 
      }
    });

    return res.json({ success: true });
  } catch (err) {
    console.error("❌ Erreur Vue Statut:", err);
    return res.status(500).json({ error: 'Erreur vue.' });
  }
});

export default router;