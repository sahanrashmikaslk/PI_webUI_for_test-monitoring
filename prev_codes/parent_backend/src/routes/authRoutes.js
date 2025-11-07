import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { repository } from '../db.js';
import { CONFIG } from '../config.js';

const router = Router();

function isInvitationExpired(invitation) {
  if (!invitation || invitation.status !== 'pending') return true;
  const expiresAt = new Date(invitation.expires_at);
  return Number.isNaN(expiresAt.getTime()) || expiresAt.getTime() < Date.now();
}

router.get('/invitations/:code', (req, res) => {
  const { code } = req.params;
  const invitation = repository.getInvitation(code);

  if (!invitation) {
    return res.status(404).json({ error: 'Invitation not found' });
  }

  if (invitation.status === 'claimed') {
    return res.status(410).json({ error: 'Invitation already used' });
  }

  if (isInvitationExpired(invitation)) {
    repository.expireInvitation(code);
    return res.status(410).json({ error: 'Invitation expired' });
  }

  return res.json({
    code: invitation.code,
    babyId: invitation.baby_id,
    babyName: invitation.baby_name,
    caregiverRole: invitation.caregiver_role,
    expiresAt: invitation.expires_at
  });
});

router.post('/auth/parent/register', async (req, res) => {
  const { code, name, phone, password } = req.body;
  if (!code || !name || !phone || !password) {
    return res.status(400).json({ error: 'code, name, phone and password are required' });
  }

  const invitation = repository.getInvitation(code);
  if (!invitation) {
    return res.status(404).json({ error: 'Invitation not found' });
  }

  if (invitation.status === 'claimed') {
    return res.status(410).json({ error: 'Invitation already used' });
  }

  if (isInvitationExpired(invitation)) {
    repository.expireInvitation(code);
    return res.status(410).json({ error: 'Invitation expired' });
  }

  const existingParent = repository.getParentByPhone(phone);
  if (existingParent) {
    return res.status(409).json({ error: 'An account already exists for this phone number' });
  }

  repository.upsertBaby(invitation.baby_id, invitation.baby_name, null);

  const passwordHash = await bcrypt.hash(password, 10);
  const parentId = repository.createParent({
    babyId: invitation.baby_id,
    name,
    phone,
    passwordHash
  });

  repository.markInvitationClaimed(code, parentId);

  const token = jwt.sign(
    {
      parentId,
      babyId: invitation.baby_id,
      name,
      phone
    },
    CONFIG.jwtSecret,
    { expiresIn: '12h' }
  );

  return res.status(201).json({
    token,
    parent: {
      id: parentId,
      name,
      phone,
      babyId: invitation.baby_id
    }
  });
});

router.post('/auth/parent/login', async (req, res) => {
  const { phone, password } = req.body;
  if (!phone || !password) {
    return res.status(400).json({ error: 'Phone and password are required' });
  }

  const parent = repository.getParentByPhone(phone);
  if (!parent) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }

  const passwordValid = await bcrypt.compare(password, parent.password_hash);
  if (!passwordValid) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }

  const token = jwt.sign(
    {
      parentId: parent.id,
      babyId: parent.baby_id,
      name: parent.name,
      phone: parent.phone
    },
    CONFIG.jwtSecret,
    { expiresIn: '12h' }
  );

  return res.json({
    token,
    parent: {
      id: parent.id,
      name: parent.name,
      phone: parent.phone,
      babyId: parent.baby_id
    }
  });
});

export default router;
