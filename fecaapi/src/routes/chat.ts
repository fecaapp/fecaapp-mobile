import { Router, Request, Response } from 'express';
import prisma from '../prismaClient';

const router = Router();

// --- LOGIQUE DE VÉRIFICATION DU DÉLAI (15 MIN) ---
const canModify = (createdAt: Date): boolean => {
    const now = new Date();
    const diffInMinutes = (now.getTime() - new Date(createdAt).getTime()) / 60000;
    return diffInMinutes <= 15;
};

// ==========================================
// 1. RÉCUPÉRER LES CONVERSATIONS
// ==========================================
router.get('/conversations/:userId', async (req: Request, res: Response) => {
    const { userId } = req.params;

    try {
        const chats = await prisma.message.findMany({
            where: { 
                OR: [
                    { senderId: userId }, 
                    { receiverId: userId }
                ] 
            },
            orderBy: { createdAt: 'desc' },
            distinct: ['senderId', 'receiverId'],
            include: {
                sender: {
                    select: {
                        id: true,
                        full_name: true,
                        img_url: true,
                        is_online: true,
                    }
                },
                receiver: {
                    select: {
                        id: true,
                        full_name: true,
                        img_url: true,
                        is_online: true,
                    }
                }
            }
        });

        res.json({ success: true, chats });
    } catch (e) {
        console.error("❌ Erreur Fetch Conversations:", e);
        res.status(500).json({ error: "Impossible de charger tes rugissements." });
    }
});

// ==========================================
// 2. ENVOYER UN MESSAGE (Texte, Média, Vocal)
// ==========================================
router.post('/send', async (req: Request, res: Response) => {
    const data = req.body;

    try {
        // Récupération du badge actuel du Lion
        const userProgress = await prisma.userQuizProgress.findUnique({
            where: { userId: data.senderId }
        });
        
        const currentBadge = userProgress?.badgeType || "LIONCEAU";

        // Création du message dans Supabase
        const newMessage = await prisma.message.create({
            data: {
                content: data.content,
                mediaUrl: data.mediaUrl,
                type: data.type || 'TEXT', // 'TEXT', 'IMAGE', 'VIDEO', 'VOICE'
                duration: data.duration,
                senderId: data.senderId,
                receiverId: data.receiverId,
                groupId: data.groupId,
                senderBadge: currentBadge,
                status: 'SENT'
            },
            include: { 
                sender: { 
                    select: { full_name: true, img_url: true } 
                } 
            }
        });

        const io = req.app.get('io');
        if (io) {
            const targetRoom = data.groupId ? `group_${data.groupId}` : `user_${data.receiverId}`;
            
            // Vérification de la présence du destinataire pour mettre à jour le statut
            const clients = io.sockets.adapter.rooms.get(targetRoom);
            if (clients && clients.size > 0) {
                await prisma.message.update({
                    where: { id: newMessage.id },
                    data: { status: 'DELIVERED' }
                });
                newMessage.status = 'DELIVERED';
            }

            io.to(targetRoom).emit('newMessage', newMessage);
        }

        res.status(201).json(newMessage);
    } catch (e) {
        console.error("❌ Erreur Envoi Message:", e);
        res.status(500).json({ error: "Le rugissement s'est perdu dans la savane." });
    }
});

// ==========================================
// 3. MODIFIER UN MESSAGE (Max 15 min)
// ==========================================
router.patch('/edit/:messageId', async (req: Request, res: Response) => {
    const { messageId } = req.params;
    const { content, userId } = req.body;

    try {
        const message = await prisma.message.findUnique({ where: { id: messageId } });

        if (!message || message.senderId !== userId) {
            return res.status(403).json({ error: "Action interdite. Ce n'est pas ton message." });
        }
        
        if (!canModify(message.createdAt)) {
            return res.status(400).json({ error: "Délai de 15 min dépassé. Ce rugissement appartient à l'histoire." });
        }

        const updatedMessage = await prisma.message.update({
            where: { id: messageId },
            data: { content, isEdited: true }
        });

        const targetRoom = message.groupId ? `group_${message.groupId}` : `user_${message.receiverId}`;
        req.app.get('io').to(targetRoom).emit('messageUpdate', updatedMessage);
        
        res.json(updatedMessage);
    } catch (e) {
        res.status(500).json({ error: "Erreur lors de la modification." });
    }
});

// ==========================================
// 4. SUPPRIMER UN MESSAGE (Max 15 min)
// ==========================================
router.delete('/delete/:messageId', async (req: Request, res: Response) => {
    const { messageId } = req.params;
    const { userId } = req.body;

    try {
        const message = await prisma.message.findUnique({ where: { id: messageId } });

        if (!message || message.senderId !== userId) {
            return res.status(403).json({ error: "Interdit." });
        }

        if (!canModify(message.createdAt)) {
            return res.status(400).json({ error: "Impossible de supprimer après 15 min." });
        }

        await prisma.message.delete({ where: { id: messageId } });
        
        const targetRoom = message.groupId ? `group_${message.groupId}` : `user_${message.receiverId}`;
        req.app.get('io').to(targetRoom).emit('messageDeleted', { messageId });

        res.json({ success: true });
    } catch (e) {
        res.status(500).json({ error: "Erreur lors de la suppression." });
    }
});

// ==========================================
// 5. SIGNALISATION APPEL VIDÉO / AUDIO (WebRTC)
// ==========================================
router.post('/call/initiate', async (req: Request, res: Response) => {
    const { callerId, targetId, type, isGroup } = req.body; // type: 'VIDEO' | 'AUDIO'

    const io = req.app.get('io');
    const callData = {
        callerId,
        type,
        isGroup,
        channelName: `call_${callerId}_${Date.now()}`,
    };

    const targetRoom = isGroup ? `group_${targetId}` : `user_${targetId}`;
    io.to(targetRoom).emit('incomingCall', callData);

    res.json({ success: true, channelName: callData.channelName });
});

export default router;