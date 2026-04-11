import { Router, Request, Response } from 'express';
import prisma from '../prismaClient'; 

const router = Router();

// --- INTERFACES DE SYNCHRONISATION ---
interface LegendInput {
    name: string;
    number: string;
    title: string;
    imgUrl: string;
    biography: string;
    citation?: string;
    goals: number;
    matches: number;
    canTitles: number;
    awardsCount: number;
    palmares: any; // Type JSON pour Prisma
}

interface VideoInput {
    title: string;
    url: string;
    thumbnail: string;
    duration: string;
}

interface QuizInput {
    sessionNumber: number;
    question: string;
    options: any; // Type JSON pour Prisma
    correctIndex: number;
}

// ==========================================
// 1. RÉCUPÉRER TOUT LE PATRIMOINE + PROGRÈS QUIZ
// ==========================================
router.get('/all', async (req: Request, res: Response) => {
    // On récupère l'ID utilisateur via les query params pour synchroniser le badge
    const userId = req.query.userId as string;

    try {
        const [legends, videos, userProgress] = await Promise.all([
            prisma.legend.findMany({
                orderBy: { createdAt: 'desc' }
            }),
            prisma.museumVideo.findMany({
                orderBy: { createdAt: 'desc' }
            }),
            // Si un userId est fourni, on vérifie son avancement dans le défi
            userId ? prisma.userQuizProgress.findUnique({ where: { userId } }) : null
        ]);

        res.json({
            success: true,
            legends,
            videos,
            userProgress 
        });
    } catch (e) {
        console.error("❌ Erreur Fetch Museum:", e);
        res.status(500).json({ error: "Erreur lors de la récupération du patrimoine" });
    }
});

// ==========================================
// 2. GESTION DES LÉGENDES (Dashboard)
// ==========================================
router.post('/legends/add', async (req: Request, res: Response) => {
    const data = req.body as LegendInput;
    try {
        const newLegend = await prisma.legend.create({
            data: {
                name: data.name,
                number: String(data.number) || "10",
                title: data.title,
                imgUrl: data.imgUrl,
                biography: data.biography,
                citation: data.citation || "L'impossible n'est pas camerounais.",
                goals: Number(data.goals) || 0,
                matches: Number(data.matches) || 0,
                canTitles: Number(data.canTitles) || 0,
                awardsCount: Number(data.awardsCount) || 0,
                palmares: data.palmares || [] // Stocké en JSON
            }
        });

        const io = req.app.get('io');
        if (io) io.emit('refreshMuseum');

        res.status(201).json(newLegend);
    } catch (e) {
        console.error("❌ Erreur Add Legend:", e);
        res.status(500).json({ error: "Erreur lors de l'ajout de la légende" });
    }
});

// ==========================================
// 3. GESTION DES VIDÉOS (Dashboard)
// ==========================================
router.post('/videos/add', async (req: Request, res: Response) => {
    const data = req.body as VideoInput;
    try {
        const newVideo = await prisma.museumVideo.create({
            data: {
                title: data.title,
                url: data.url,
                thumbnail: data.thumbnail,
                duration: data.duration || "00:00"
            }
        });

        const io = req.app.get('io');
        if (io) io.emit('refreshMuseum');

        res.status(201).json(newVideo);
    } catch (e) {
        res.status(500).json({ error: "Erreur lors de l'ajout de la vidéo" });
    }
});

// ==========================================
// 4. SYSTÈME DE QUIZ : DÉFI DES LIONS
// ==========================================

// Ajouter une question au quiz
router.post('/quiz/questions/add', async (req: Request, res: Response) => {
    const data = req.body as QuizInput;
    try {
        const newQuestion = await prisma.quizQuestion.create({
            data: {
                sessionNumber: Number(data.sessionNumber),
                question: data.question,
                options: data.options, // Prisma gère le tableau/objet en JSON
                correctIndex: Number(data.correctIndex)
            }
        });
        res.status(201).json(newQuestion);
    } catch (e) {
        res.status(500).json({ error: "Erreur lors de l'ajout de la question" });
    }
});

// Récupérer les questions d'une séance spécifique
router.get('/quiz/questions/:session', async (req: Request, res: Response) => {
    const { session } = req.params;
    try {
        const questions = await prisma.quizQuestion.findMany({
            where: { sessionNumber: Number(session) }
        });
        res.json(questions);
    } catch (e) {
        res.status(500).json({ error: "Erreur lors de la récupération des questions" });
    }
});

// Valider une séance et mettre à jour le Badge du Lion
router.post('/quiz/validate-session', async (req: Request, res: Response) => {
    const { userId, sessionCompleted, badgeName } = req.body;
    try {
        const nextSession = Number(sessionCompleted) + 1;
        const expiryDate = new Date();
        expiryDate.setDate(expiryDate.getDate() + 7); // Le badge reste débloqué 7 jours

        const progress = await prisma.userQuizProgress.upsert({
            where: { userId: userId },
            update: {
                currentSession: nextSession,
                lastSuccessDate: new Date(),
                unlockedUntil: expiryDate,
                badgeType: badgeName,
                isFinalLevel: nextSession > 10
            },
            create: {
                userId: userId,
                currentSession: nextSession,
                lastSuccessDate: new Date(),
                unlockedUntil: expiryDate,
                badgeType: badgeName
            }
        });

        res.json({ success: true, progress });
    } catch (e) {
        console.error("❌ Erreur Validation Quiz:", e);
        res.status(500).json({ error: "Erreur lors de la validation du quiz" });
    }
});

// ==========================================
// 5. SUPPRESSION UNIVERSELLE (Dashboard)
// ==========================================
router.delete('/delete/:type/:id', async (req: Request, res: Response) => {
    const { type, id } = req.params;
    try {
        if (type === 'legend') {
            await prisma.legend.delete({ where: { id } });
        } else if (type === 'video') {
            await prisma.museumVideo.delete({ where: { id } });
        } else if (type === 'quiz') {
            await prisma.quizQuestion.delete({ where: { id } });
        }
        
        const io = req.app.get('io');
        if (io) io.emit('refreshMuseum');

        res.json({ success: true });
    } catch (e) {
        res.status(500).json({ error: "Erreur lors de la suppression" });
    }
});

export default router;