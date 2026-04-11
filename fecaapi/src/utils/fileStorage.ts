import multer from 'multer';
import path from 'path';
import fs from 'fs';

// ==========================================
// 1. GESTION DU RÉPERTOIRE DE STOCKAGE
// ==========================================
// On utilise process.cwd() pour cibler la racine du projet Node.js
const uploadDir = path.join(process.cwd(), 'uploads'); 

// Création récursive du dossier s'il n'existe pas au lancement du serveur
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
  console.log("📁 Dossier 'uploads' créé avec succès à la racine.");
}

// ==========================================
// 2. CONFIGURATION DU DISQUE (STORAGE)
// ==========================================
const storage = multer.diskStorage({
  destination: function (_req, _file, cb) {
    // Tous les médias (Images, Vidéos, PDF) arrivent ici
    cb(null, uploadDir);
  },
  filename: function (_req, file, cb) {
    /**
     * Sécurisation du nom de fichier :
     * 1. Un suffixe unique (Timestamp + Aléatoire) pour éviter les doublons.
     * 2. Nettoyage du nom original (retrait des espaces et caractères spéciaux).
     * 3. Extension forcée en minuscules.
     */
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    const ext = path.extname(file.originalname).toLowerCase();
    
    // On garde une trace du nom original mais on le nettoie radicalement (Regex)
    const cleanName = path.basename(file.originalname, ext)
      .replace(/\s+/g, '_')           // Espaces -> Underscores
      .replace(/[^\w.-]/g, '');       // Supprime tout ce qui n'est pas alphanumérique

    cb(null, `${uniqueSuffix}-${cleanName}${ext}`);
  }
});

// ==========================================
// 3. FILTRE DE SÉCURITÉ (VALIDATION MIME)
// ==========================================
const fileFilter = (_req: any, file: Express.Multer.File, cb: any) => {
  // Types autorisés pour l'écosystème (Posts, Profils, Talents, Certifications)
  const allowedMimeTypes = [
    'image/jpeg', 
    'image/png', 
    'image/webp', 
    'video/mp4', 
    'video/quicktime', // .mov (iPhone)
    'application/pdf'  // Pour les diplômes
  ];
  
  // Vérification par extension (sécurité supplémentaire)
  const extension = path.extname(file.originalname).toLowerCase();
  const allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.mp4', '.mov', '.pdf'];

  if (allowedMimeTypes.includes(file.mimetype) || allowedExtensions.includes(extension)) {
    cb(null, true);
  } else {
    console.error(`❌ Fichier bloqué - Type: ${file.mimetype}, Ext: ${extension}`);
    cb(new Error('Format non supporté. Utilise JPG, PNG, WEBP, MP4 ou PDF.'), false);
  }
};

// ==========================================
// 4. INSTANCE MULTÉ ET LIMITES
// ==========================================
export const upload = multer({ 
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    // Limite à 50 Mo pour permettre les vidéos de Talents en bonne qualité
    fileSize: 50 * 1024 * 1024 
  }
});

// Exportation du chemin absolu pour utilisation dans server.ts (express.static)
export const uploadsDir = uploadDir;