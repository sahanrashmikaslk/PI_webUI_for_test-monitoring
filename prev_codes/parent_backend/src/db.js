import Database from 'better-sqlite3';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const dataDir = path.join(__dirname, '../data');
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

const dbPath = path.join(dataDir, 'parent_portal.db');
const db = new Database(dbPath);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS babies (
    baby_id TEXT PRIMARY KEY,
    baby_name TEXT,
    metadata TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS parents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    baby_id TEXT NOT NULL,
    name TEXT NOT NULL,
    phone TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (baby_id) REFERENCES babies(baby_id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS invitations (
    code TEXT PRIMARY KEY,
    baby_id TEXT NOT NULL,
    baby_name TEXT,
    caregiver_role TEXT DEFAULT 'parent',
    expires_at DATETIME NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    claimed_at DATETIME,
    claimed_parent_id INTEGER,
    FOREIGN KEY (baby_id) REFERENCES babies(baby_id) ON DELETE CASCADE,
    FOREIGN KEY (claimed_parent_id) REFERENCES parents(id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    baby_id TEXT NOT NULL,
    sender_type TEXT NOT NULL,
    sender_name TEXT,
    sender_id INTEGER,
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (baby_id) REFERENCES babies(baby_id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_messages_baby_id_created
    ON messages (baby_id, created_at DESC);

  CREATE INDEX IF NOT EXISTS idx_invitations_status
    ON invitations (status);
`);

const statements = {
  upsertBaby: db.prepare(`
    INSERT INTO babies (baby_id, baby_name, metadata)
    VALUES (@baby_id, @baby_name, @metadata)
    ON CONFLICT(baby_id) DO UPDATE SET
      baby_name = excluded.baby_name,
      metadata = excluded.metadata
  `),
  getBaby: db.prepare('SELECT * FROM babies WHERE baby_id = ?'),
  createInvitation: db.prepare(`
    INSERT INTO invitations (code, baby_id, baby_name, caregiver_role, expires_at, status)
    VALUES (@code, @baby_id, @baby_name, @caregiver_role, @expires_at, 'pending')
  `),
  getInvitation: db.prepare('SELECT * FROM invitations WHERE code = ?'),
  markInvitationClaimed: db.prepare(`
    UPDATE invitations
    SET status = 'claimed', claimed_at = CURRENT_TIMESTAMP, claimed_parent_id = @parentId
    WHERE code = @code
  `),
  expireInvitation: db.prepare(`
    UPDATE invitations
    SET status = 'expired'
    WHERE code = ?
  `),
  createParent: db.prepare(`
    INSERT INTO parents (baby_id, name, phone, password_hash)
    VALUES (@baby_id, @name, @phone, @password_hash)
  `),
  getParentByPhone: db.prepare('SELECT * FROM parents WHERE phone = ?'),
  getParentById: db.prepare('SELECT * FROM parents WHERE id = ?'),
  listParentsForBaby: db.prepare(`
    SELECT id, name, phone, created_at
    FROM parents
    WHERE baby_id = ?
    ORDER BY created_at DESC
  `),
  createMessage: db.prepare(`
    INSERT INTO messages (baby_id, sender_type, sender_name, sender_id, content)
    VALUES (@baby_id, @sender_type, @sender_name, @sender_id, @content)
  `),
  listMessagesForBaby: db.prepare(`
    SELECT id, baby_id, sender_type, sender_name, sender_id, content, created_at
    FROM messages
    WHERE baby_id = ?
    ORDER BY created_at DESC
    LIMIT @limit OFFSET @offset
  `)
};

export const repository = {
  upsertBaby(babyId, babyName, metadata = null) {
    statements.upsertBaby.run({
      baby_id: babyId,
      baby_name: babyName,
      metadata: metadata ? JSON.stringify(metadata) : null
    });
  },

  getBaby(babyId) {
    return statements.getBaby.get(babyId);
  },

  createInvitation({ code, babyId, babyName, caregiverRole, expiresAt }) {
    statements.createInvitation.run({
      code,
      baby_id: babyId,
      baby_name: babyName || null,
      caregiver_role: caregiverRole || 'parent',
      expires_at: expiresAt
    });
  },

  getInvitation(code) {
    return statements.getInvitation.get(code);
  },

  markInvitationClaimed(code, parentId) {
    statements.markInvitationClaimed.run({ code, parentId });
  },

  expireInvitation(code) {
    statements.expireInvitation.run(code);
  },

  createParent({ babyId, name, phone, passwordHash }) {
    const result = statements.createParent.run({
      baby_id: babyId,
      name,
      phone,
      password_hash: passwordHash
    });
    return result.lastInsertRowid;
  },

  getParentByPhone(phone) {
    return statements.getParentByPhone.get(phone);
  },

  getParentById(id) {
    return statements.getParentById.get(id);
  },

  listParentsForBaby(babyId) {
    return statements.listParentsForBaby.all(babyId);
  },

  createMessage({ babyId, senderType, senderName, senderId, content }) {
    const result = statements.createMessage.run({
      baby_id: babyId,
      sender_type: senderType,
      sender_name: senderName || null,
      sender_id: senderId || null,
      content
    });
    return result.lastInsertRowid;
  },

  listMessagesForBaby({ babyId, limit = 50, offset = 0 }) {
    return statements.listMessagesForBaby.all({ babyId, limit, offset });
  }
};

export default db;

