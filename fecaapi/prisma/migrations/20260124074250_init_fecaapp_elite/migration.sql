-- AlterTable
ALTER TABLE "certifications" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

-- AlterTable
ALTER TABLE "talents" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

-- AlterTable
ALTER TABLE "users" ALTER COLUMN "id" SET DEFAULT gen_random_uuid(),
ALTER COLUMN "role" SET DEFAULT 'USER';

-- CreateTable
CREATE TABLE "League" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "logo" TEXT,
    "gender" TEXT NOT NULL DEFAULT 'Masculin',

    CONSTRAINT "League_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Match" (
    "id" TEXT NOT NULL,
    "team1Name" TEXT NOT NULL,
    "team1Logo" TEXT,
    "team2Name" TEXT NOT NULL,
    "team2Logo" TEXT,
    "score1" INTEGER NOT NULL DEFAULT 0,
    "score2" INTEGER NOT NULL DEFAULT 0,
    "time" TEXT NOT NULL DEFAULT '0',
    "extraTime" TEXT NOT NULL DEFAULT '0',
    "isTimerActive" BOOLEAN NOT NULL DEFAULT false,
    "status" TEXT NOT NULL DEFAULT 'À VENIR',
    "journee" TEXT DEFAULT 'JOURNÉE 1',
    "stadium" TEXT DEFAULT 'Stade non défini',
    "varActive" BOOLEAN NOT NULL DEFAULT false,
    "isLocked" BOOLEAN NOT NULL DEFAULT false,
    "officials" TEXT,
    "stats" JSONB,
    "pen1" JSONB,
    "pen2" JSONB,
    "lineup1" JSONB,
    "lineup2" JSONB,
    "positions" JSONB,
    "coach1" TEXT,
    "coach2" TEXT,
    "formation1" TEXT DEFAULT '4-4-2',
    "formation2" TEXT DEFAULT '4-4-2',
    "subs1" TEXT,
    "subs2" TEXT,
    "hurt1" TEXT,
    "hurt2" TEXT,
    "startTime" TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP,
    "leagueId" TEXT NOT NULL,

    CONSTRAINT "Match_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Event" (
    "id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "message" TEXT,
    "time" TEXT,
    "team" TEXT,
    "player" TEXT,
    "assist" TEXT,
    "matchId" TEXT NOT NULL,

    CONSTRAINT "Event_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Standing" (
    "id" TEXT NOT NULL,
    "teamName" TEXT NOT NULL,
    "teamLogo" TEXT,
    "played" INTEGER NOT NULL DEFAULT 0,
    "won" INTEGER NOT NULL DEFAULT 0,
    "drawn" INTEGER NOT NULL DEFAULT 0,
    "lost" INTEGER NOT NULL DEFAULT 0,
    "goalsFor" INTEGER NOT NULL DEFAULT 0,
    "goalsAgainst" INTEGER NOT NULL DEFAULT 0,
    "goalDiff" INTEGER NOT NULL DEFAULT 0,
    "points" INTEGER NOT NULL DEFAULT 0,
    "history" JSONB,
    "leagueId" TEXT NOT NULL,

    CONSTRAINT "Standing_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "League_name_key" ON "League"("name");

-- CreateIndex
CREATE UNIQUE INDEX "Standing_teamName_leagueId_key" ON "Standing"("teamName", "leagueId");

-- AddForeignKey
ALTER TABLE "Match" ADD CONSTRAINT "Match_leagueId_fkey" FOREIGN KEY ("leagueId") REFERENCES "League"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Event" ADD CONSTRAINT "Event_matchId_fkey" FOREIGN KEY ("matchId") REFERENCES "Match"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Standing" ADD CONSTRAINT "Standing_leagueId_fkey" FOREIGN KEY ("leagueId") REFERENCES "League"("id") ON DELETE CASCADE ON UPDATE CASCADE;
