import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({
  path: process.env.PARENT_BACKEND_ENV
    ? path.resolve(process.env.PARENT_BACKEND_ENV)
    : path.resolve(__dirname, '../.env')
});

export const CONFIG = {
  port: process.env.PARENT_BACKEND_PORT || 5055,
  jwtSecret: process.env.PARENT_JWT_SECRET || 'change-me-parent-secret',
  invitationExpiryHours: parseInt(process.env.PARENT_INVITE_EXPIRY_HOURS || '48', 10),
  clinicianApiKey: process.env.PARENT_CLINICIAN_KEY || 'change-me-clinician-key'
};

