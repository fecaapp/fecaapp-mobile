-- AlterTable
ALTER TABLE "certifications" ADD COLUMN     "diploma_type" TEXT,
ADD COLUMN     "institution" TEXT;

-- CreateTable
CREATE TABLE "talents" (
    "id" UUID NOT NULL,
    "video_url" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "specialty" TEXT,
    "city" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "user_id" UUID NOT NULL,

    CONSTRAINT "talents_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "talents" ADD CONSTRAINT "talents_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
