import { Router } from 'express';
import { nanoid } from 'nanoid';
import { repository } from '../db.js';
import { CONFIG } from '../config.js';

const router = Router();
const INVITATION_LENGTH = 10;

router.post('/invitations', (req, res) => {
  const { babyId, babyName, caregiverRole, expiresInHours } = req.body;
  if (!babyId) {
    return res.status(400).json({ error: 'babyId is required' });
  }

  repository.upsertBaby(babyId, babyName || null, null);

  const code = nanoid(INVITATION_LENGTH);
  const expiresAt = new Date();
  const hours = Number.isFinite(expiresInHours) ? expiresInHours : CONFIG.invitationExpiryHours;
  expiresAt.setHours(expiresAt.getHours() + hours);

  repository.createInvitation({
    code,
    babyId,
    babyName,
    caregiverRole,
    expiresAt: expiresAt.toISOString()
  });

  return res.status(201).json({
    code,
    babyId,
    babyName,
    caregiverRole: caregiverRole || 'parent',
    expiresAt: expiresAt.toISOString()
  });
});

router.get('/babies/:babyId/parents', (req, res) => {
  const { babyId } = req.params;
  if (!babyId) {
    return res.status(400).json({ error: 'babyId is required' });
  }

  const parents = repository.listParentsForBaby(babyId);
  return res.json({ parents });
});

router.get('/babies/:babyId/messages', (req, res) => {
  const { babyId } = req.params;
  if (!babyId) {
    return res.status(400).json({ error: 'babyId is required' });
  }

  const messages = repository
    .listMessagesForBaby({ babyId, limit: 200, offset: 0 })
    .reverse();

  return res.json({ messages });
});

router.post('/messages', (req, res) => {
  const { babyId, senderName, content } = req.body;
  if (!babyId || !senderName || !content) {
    return res.status(400).json({ error: 'babyId, senderName and content are required' });
  }

  repository.upsertBaby(babyId, null, null);
  const messageId = repository.createMessage({
    babyId,
    senderType: 'clinician',
    senderName,
    senderId: null,
    content: content.trim()
  });

  return res.status(201).json({
    id: messageId,
    baby_id: babyId,
    sender_type: 'clinician',
    sender_name: senderName,
    sender_id: null,
    content: content.trim(),
    created_at: new Date().toISOString()
  });
});

export default router;
