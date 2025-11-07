import jwt from 'jsonwebtoken';
import { CONFIG } from '../config.js';

export function parentAuth(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: 'Missing parent token' });
  }

  try {
    const payload = jwt.verify(token, CONFIG.jwtSecret);
    req.parent = payload;
    return next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid or expired parent token' });
  }
}

export function clinicianAuth(req, res, next) {
  const apiKey = req.headers['x-api-key'];
  if (!apiKey || apiKey !== CONFIG.clinicianApiKey) {
    return res.status(401).json({ error: 'Clinician API key is invalid' });
  }
  return next();
}

