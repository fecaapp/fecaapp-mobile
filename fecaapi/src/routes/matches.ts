import { Router, Request, Response } from 'express';
import prisma from '../prismaClient'; 

const router = Router();

// --- INTERFACE DE SYNCHRONISATION ---
interface MatchUpdateInput {
    matchId: string;
    score1: number;
    score2: number;
    time: string;
    status: string;
    extraTime?: string;
    isTimerActive?: boolean; 
    journee?: string;      
    stadium?: string;     
    stats: any;           
    formation1?: string;
    formation2?: string;
    positions?: any;      
    lineup1?: any;        
    lineup2?: any;        
    events?: any[];       
    subs1?: string;       
    subs2?: string;       
    hurt1?: string;       
    hurt2?: string;       
    coach1?: string;      
    coach2?: string;      
    officialsMain?: string; 
    officialsAssistants?: string;
    pen1?: any;           
    pen2?: any;           
    isLocked?: boolean;
}

// ==========================================
// 1. RÉCUPÉRER TOUTES LES LEAGUES
// ==========================================
router.get('/leagues', async (req: Request, res: Response) => {
    try {
        const leagues = await prisma.league.findMany({
            orderBy: { name: 'asc' }
        });
        res.json(leagues);
    } catch (e) {
        res.status(500).json({ error: "Erreur lors de la récupération des leagues" });
    }
});

// ==========================================
// 2. RÉCUPÉRER LES NOMS DES LEAGUES (STANDINGS)
// ==========================================
router.get('/standings/all_leagues', async (req: Request, res: Response) => {
    try {
        const leagues = await prisma.league.findMany({
            select: { name: true }
        });
        res.json(leagues.map(l => l.name));
    } catch (e) {
        res.status(500).json({ error: "Erreur leagues standings" });
    }
});

// ==========================================
// 3. RÉCUPÉRER LE CLASSEMENT D'UNE LIGUE
// ==========================================
router.get('/standings/:leagueName', async (req: Request, res: Response) => {
    try {
        const { leagueName } = req.params;
        const league = await prisma.league.findUnique({ where: { name: leagueName } });
        if (!league) return res.json([]);

        const standings = await prisma.standing.findMany({
            where: { leagueId: league.id },
            orderBy: [
                { points: 'desc' },
                { goalDiff: 'desc' },
                { goalsFor: 'desc' }
            ]
        });
        res.json(standings);
    } catch (e) {
        res.status(500).json({ error: "Erreur récupération classement" });
    }
});

// ==========================================
// 4. CRÉATION D'UN MATCH
// ==========================================
router.post('/add', async (req: Request, res: Response) => {
    const { leagueName, leagueLogo, team1, team2, startTime, journee, gender, stadium } = req.body;
    try {
        const league = await prisma.league.upsert({
            where: { name: leagueName },
            update: { 
                gender: gender || "Masculin",
                logo: leagueLogo || "" 
            },
            create: { 
                name: leagueName, 
                gender: gender || "Masculin",
                logo: leagueLogo || ""
            }
        });

        const newMatch = await prisma.match.create({
            data: {
                team1Name: team1.name, team1Logo: team1.logo || "",
                team2Name: team2.name, team2Logo: team2.logo || "",
                startTime: new Date(startTime),
                status: "À VENIR",
                journee: journee || "CHAMPIONNAT",
                stadium: stadium || "Stade non défini",
                leagueId: league.id,
                score1: 0, score2: 0, time: "00:00", extraTime: "0",
                isTimerActive: false,
                formation1: "4-4-2", formation2: "4-4-2",
                stats: { 
                    possession: [50, 50], tirscadres: [0, 0], tirsnoncadres: [0, 0], 
                    fautes: [0, 0], horsjeu: [0, 0], corners: [0, 0], jaunes: [0, 0], rouges: [0, 0]
                },
                isLocked: false
            }
        });

        const io = req.app.get('io');
        if (io) io.emit('refreshMatches');

        res.status(201).json(newMatch);
    } catch (e) {
        console.error("❌ Erreur Création Match:", e);
        res.status(500).send("Erreur lors de la création du match");
    }
});

// ==========================================
// 5. RÉCUPÉRATION DES MATCHS (GROUPÉS PAR LIGUE)
// ==========================================
router.get('/all', async (req: Request, res: Response) => {
    try {
        const matches = await prisma.match.findMany({
            include: { league: true, events: true },
            orderBy: { startTime: 'desc' }
        });

        const groupedByLeague = matches.reduce((acc: any, match) => {
            const leagueName = match.league?.name || "Autres";
            if (!acc[leagueName]) {
                acc[leagueName] = {
                    leagueId: match.league?.id || "",
                    leagueName: leagueName,
                    leagueLogo: match.league?.logo || "",
                    gender: match.league?.gender || "Masculin",
                    matches: []
                };
            }
            acc[leagueName].matches.push(match);
            return acc;
        }, {});

        res.json(Object.values(groupedByLeague));
    } catch (e) {
        res.status(500).json({ error: "Erreur lors de la récupération des matchs" });
    }
});

// ==========================================
// 6. INITIALISATION DES ÉQUIPES POUR LE CLASSEMENT
// ==========================================
router.post('/teams/init', async (req: Request, res: Response) => {
    const { leagueName, teamName, teamLogo } = req.body;
    try {
        const league = await prisma.league.upsert({
            where: { name: leagueName },
            update: {},
            create: { name: leagueName }
        });

        const teamStanding = await prisma.standing.upsert({
            where: { 
                teamName_leagueId: { teamName: teamName, leagueId: league.id } 
            },
            update: { teamLogo: teamLogo || "" },
            create: {
                teamName,
                teamLogo: teamLogo || "",
                leagueId: league.id,
                played: 0, won: 0, drawn: 0, lost: 0,
                goalsFor: 0, goalsAgainst: 0, goalDiff: 0, points: 0
            }
        });

        const io = req.app.get('io');
        if (io) io.emit('refreshMatches');

        res.json(teamStanding);
    } catch (e) {
        res.status(500).json({ error: "Erreur initialisation équipe" });
    }
});

// ==========================================
// 7. MISE À JOUR LIVE ET CALCUL CLASSEMENT
// ==========================================
router.post('/update-live', async (req: Request, res: Response) => {
    const data = req.body as MatchUpdateInput;

    try {
        const currentMatch = await prisma.match.findUnique({ where: { id: data.matchId } });

        if (data.events && Array.isArray(data.events)) {
            await prisma.event.deleteMany({ where: { matchId: data.matchId } });
            if (data.events.length > 0) {
                await prisma.event.createMany({
                    data: data.events.map(ev => ({
                        matchId: data.matchId,
                        type: String(ev.type || 'goal'),
                        team: String(ev.team || '1'),
                        player: String(ev.player || ''),
                        time: String(ev.time || '0'),
                        assist: String(ev.assist || ''),
                        message: String(ev.message || '')
                    }))
                });
            }
        }

        const updated = await prisma.match.update({
            where: { id: data.matchId },
            data: {
                score1: data.score1 !== undefined ? Number(data.score1) : undefined,
                score2: data.score2 !== undefined ? Number(data.score2) : undefined,
                time: data.time !== undefined ? String(data.time) : undefined, 
                extraTime: data.extraTime !== undefined ? String(data.extraTime) : undefined,
                isTimerActive: data.isTimerActive ?? undefined,
                status: data.status || undefined,
                journee: data.journee || undefined,
                stadium: data.stadium || undefined,
                stats: data.stats || undefined, 
                formation1: data.formation1 || undefined,
                formation2: data.formation2 || undefined,
                lineup1: data.lineup1 || undefined, 
                lineup2: data.lineup2 || undefined,
                positions: data.positions || undefined,
                pen1: data.pen1 || undefined, 
                pen2: data.pen2 || undefined,
                subs1: data.subs1 ?? undefined, 
                subs2: data.subs2 ?? undefined,
                hurt1: data.hurt1 ?? undefined, 
                hurt2: data.hurt2 ?? undefined,
                coach1: data.coach1 ?? undefined, 
                coach2: data.coach2 ?? undefined,
                officialsMain: data.officialsMain ?? undefined, 
                officialsAssistants: data.officialsAssistants ?? undefined,
                isLocked: data.isLocked ?? undefined
            },
            include: { league: true, events: true }
        });

        // LOGIQUE RECALCUL CLASSEMENT
        const scoreChanged = currentMatch && (currentMatch.score1 !== updated.score1 || currentMatch.score2 !== updated.score2);
        const statusChanged = currentMatch && (currentMatch.status !== updated.status || currentMatch.isLocked !== updated.isLocked);

        if (updated.leagueId && (scoreChanged || statusChanged)) {
            const leagueMatches = await prisma.match.findMany({
                where: { 
                    leagueId: updated.leagueId, 
                    status: { in: ["EN DIRECT", "TERMINÉ", "MI-TEMPS", "PROLONGATION", "TIRS AU BUT"] } 
                }
            });

            await prisma.standing.updateMany({
                where: { leagueId: updated.leagueId },
                data: { played: 0, won: 0, drawn: 0, lost: 0, goalsFor: 0, goalsAgainst: 0, goalDiff: 0, points: 0 }
            });

            for (const m of leagueMatches) {
                const teams = [
                    { name: m.team1Name, score: m.score1, opp: m.score2 },
                    { name: m.team2Name, score: m.score2, opp: m.score1 }
                ];
                for (const t of teams) {
                    const win = t.score > t.opp ? 1 : 0;
                    const draw = t.score === t.opp ? 1 : 0;
                    const loss = t.score < t.opp ? 1 : 0;
                    try {
                        await prisma.standing.update({
                            where: { teamName_leagueId: { teamName: t.name, leagueId: updated.leagueId } },
                            data: {
                                played: { increment: 1 },
                                won: { increment: win },
                                drawn: { increment: draw },
                                lost: { increment: loss },
                                goalsFor: { increment: t.score },
                                goalsAgainst: { increment: t.opp },
                                goalDiff: { increment: t.score - t.opp },
                                points: { increment: (win * 3) + (draw * 1) }
                            }
                        });
                    } catch (err) {}
                }
            }
        }

        const io = req.app.get('io');
        if (io) {
            io.emit('updateMatchLive', updated); 
            io.emit('refreshStandings', { leagueId: updated.leagueId });
        }

        res.json(updated);
    } catch (e) {
        console.error("❌ Erreur Update Live:", e);
        res.status(500).json({ error: "Échec de synchronisation" });
    }
});

// ==========================================
// 8. ROUTE SPÉCIFIQUE STATISTIQUES
// ==========================================
router.post('/update-stats', async (req: Request, res: Response) => {
    const { matchId, stats } = req.body;
    try {
        const updated = await prisma.match.update({
            where: { id: matchId },
            data: { stats: stats },
            select: { id: true, stats: true }
        });

        const io = req.app.get('io');
        if (io) {
            io.emit('updateMatchLive', updated);
            io.emit('stats_update', { matchId: updated.id, stats: updated.stats });
        }
        res.json({ success: true, data: updated });
    } catch (e) {
        res.status(500).json({ error: "Erreur mise à jour stats" });
    }
});

export default router;