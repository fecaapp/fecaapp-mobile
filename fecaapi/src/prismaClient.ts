import { PrismaClient } from '@prisma/client';

// On utilise le "global object" pour stocker l'instance Prisma 
// et éviter de saturer les connexions à Supabase en développement.
const globalForPrisma = global as unknown as { prisma: PrismaClient };

export const prisma =
  globalForPrisma.prisma ||
  new PrismaClient({
    // 'query' : affiche le SQL généré (parfait pour débugger tes Matchs ou Social)
    // 'error', 'warn' : indispensables pour surveiller la santé de la DB
    log: ['error', 'warn'], 
  });

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;

export default prisma;