import { Router } from 'express';
import { repository } from '../db.js';

const router = Router();

router.get('/me', (req, res) => {
  const parentRecord = repository.getParentById(req.parent.parentId);
  if (!parentRecord) {
    return res.status(404).json({ error: 'Parent not found' });
  }

  return res.json({
    id: parentRecord.id,
    name: parentRecord.name,
    phone: parentRecord.phone,
    babyId: parentRecord.baby_id
  });
});

router.get('/messages', (req, res) => {
  const babyId = req.parent.babyId;
  const { limit = 50, offset = 0 } = req.query;

  const messages = repository
    .listMessagesForBaby({
      babyId,
      limit: Math.min(Number(limit) || 50, 100),
      offset: Number(offset) || 0
    })
    .reverse(); // return oldest to newest for UI

  return res.json({ messages });
});

router.post('/messages', (req, res) => {
  const babyId = req.parent.babyId;
  const { content } = req.body;

  if (!content || !content.trim()) {
    return res.status(400).json({ error: 'Message content is required' });
  }

  const messageId = repository.createMessage({
    babyId,
    senderType: 'parent',
    senderName: req.parent.name,
    senderId: req.parent.parentId,
    content: content.trim()
  });

  return res.status(201).json({
    id: messageId,
    baby_id: babyId,
    sender_type: 'parent',
    sender_name: req.parent.name,
    sender_id: req.parent.parentId,
    content: content.trim(),
    created_at: new Date().toISOString()
  });
});

export default router;
