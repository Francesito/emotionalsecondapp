import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import mysql from 'mysql2/promise';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const port = process.env.PORT || 4000;
const rawDbUrl = process.env.DATABASE_URL;

if (!rawDbUrl) {
  console.error('Falta DATABASE_URL en variables de entorno');
  process.exit(1);
}

// Render/Aiven suelen añadir ssl-mode=REQUIRED que mysql2 no reconoce; lo limpiamos.
const dbUrl = (() => {
  try {
    const u = new URL(rawDbUrl);
    u.searchParams.delete('ssl-mode');
    return u.toString();
  } catch (_) {
    return rawDbUrl;
  }
})();

const pool = mysql.createPool({
  uri: dbUrl,
  ssl: {
    rejectUnauthorized: false, // Ajusta a true y agrega CA si tienes el certificado
    minVersion: 'TLSv1.2',
  },
  connectionLimit: 5,
});

app.get('/health', async (_req, res) => {
  try {
    const [rows] = await pool.query('SELECT 1 AS ok');
    res.json({ ok: rows[0].ok === 1 });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

// Registro
app.post('/auth/register', async (req, res) => {
  const { role, name, email, password } = req.body;
  if (!role || !name || !email || !password) {
    return res.status(400).json({ error: 'Campos obligatorios: role, name, email, password' });
  }
  try {
    const [exists] = await pool.query('SELECT id FROM users WHERE email = ?', [email]);
    if (exists.length) return res.status(409).json({ error: 'Correo ya registrado' });
    const [result] = await pool.query(
      'INSERT INTO users (role, name, email, password_hash) VALUES (?, ?, ?, ?)',
      [role, name, email, password]
    );
    res.json({ id: result.insertId, role, name, email });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Login sencillo (ejemplo; usar hashing real en prod)
app.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'Falta email o password' });
  try {
    const [rows] = await pool.query(
      'SELECT id, role, name, email FROM users WHERE email = ? AND password_hash = ?',
      [email, password]
    );
    if (!rows.length) return res.status(401).json({ error: 'Credenciales inválidas' });
    res.json(rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Crear grupo (tutor)
app.post('/groups', async (req, res) => {
  const { tutorId, name, code, term = '2024' } = req.body;
  if (!tutorId || !name || !code) return res.status(400).json({ error: 'Falta tutorId, name o code' });
  try {
    const [exists] = await pool.query('SELECT id FROM `groups` WHERE code = ?', [code]);
    if (exists.length) return res.status(409).json({ error: 'Código ya existe' });
    const [result] = await pool.query(
      'INSERT INTO `groups` (code, name, tutor_id, term) VALUES (?, ?, ?, ?)',
      [code, name, tutorId, term]
    );
    res.json({ id: result.insertId, code, name });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Unirse a grupo (alumno)
app.post('/groups/join', async (req, res) => {
  const { studentId, groupCode, term = '2024' } = req.body;
  if (!studentId || !groupCode) return res.status(400).json({ error: 'Falta studentId o groupCode' });
  try {
    const [[group]] = await pool.query('SELECT id FROM `groups` WHERE code = ?', [groupCode]);
    if (!group) return res.status(404).json({ error: 'Grupo no encontrado' });
    await pool.query(
      'INSERT INTO group_members (group_id, student_id, term) VALUES (?, ?, ?)',
      [group.id, studentId, term]
    );
    res.json({ ok: true, groupId: group.id });
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'Ya inscrito en este grupo/termino' });
    res.status(500).json({ error: e.message });
  }
});

// Listar grupos de un tutor con conteo y nombres de alumnos
app.get('/groups', async (req, res) => {
  const { tutorId } = req.query;
  if (!tutorId) return res.status(400).json({ error: 'Falta tutorId' });
  try {
    const [groups] = await pool.query('SELECT id, code, name FROM `groups` WHERE tutor_id = ?', [tutorId]);
    const ids = groups.map((g) => g.id);
    let members = [];
    if (ids.length) {
      const [rows] = await pool.query(
        `SELECT gm.group_id, u.id as studentId, u.name FROM group_members gm
         JOIN users u ON u.id = gm.student_id
         WHERE gm.group_id IN (${ids.map(() => '?').join(',')})`,
        ids
      );
      members = rows;
    }
    const withCounts = groups.map((g) => ({
      ...g,
      students: members
        .filter((m) => m.group_id === g.id)
        .map((m) => ({ id: m.studentId, name: m.name })),
    }));
    res.json(withCounts);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Grupo(s) de un alumno
app.get('/groups/by-student', async (req, res) => {
  const { studentId } = req.query;
  if (!studentId) return res.status(400).json({ error: 'Falta studentId' });
  try {
    const [rows] = await pool.query(
      `SELECT g.id, g.code, g.name, g.tutor_id AS tutorId, u.name AS tutorName
       FROM \`groups\` g
       JOIN group_members gm ON gm.group_id = g.id
       JOIN users u ON u.id = g.tutor_id
       WHERE gm.student_id = ?`,
      [studentId]
    );
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Registrar estado de ánimo diario
app.post('/mood', async (req, res) => {
  const { studentId, mood, note, loggedDate } = req.body;
  if (!studentId || !mood) return res.status(400).json({ error: 'Falta studentId o mood' });
  const dateVal = loggedDate ? new Date(loggedDate) : new Date();
  const sqlDate = dateVal.toISOString().slice(0, 10);
  try {
    await pool.query(
      'INSERT INTO mood_logs (student_id, logged_date, mood, note) VALUES (?, ?, ?, ?)',
      [studentId, sqlDate, mood, note || null]
    );
    // Generar alerta simple si el ánimo es bajo
    if (['mal', 'muyMal'].includes(mood)) {
      await pool.query(
        'INSERT INTO alerts (student_id, type, severity, message) VALUES (?, ?, ?, ?)',
        [studentId, 'mood', mood === 'muyMal' ? 'high' : 'medium', 'Ánimo bajo reportado']
      );
    }
    res.json({ ok: true });
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'Ya capturaste hoy' });
    res.status(500).json({ error: e.message });
  }
});

// Historial de ánimo
app.get('/mood', async (req, res) => {
  const { studentId } = req.query;
  if (!studentId) return res.status(400).json({ error: 'Falta studentId' });
  try {
    const [rows] = await pool.query(
      'SELECT id, mood, note, logged_date AS loggedDate FROM mood_logs WHERE student_id = ? ORDER BY logged_date DESC',
      [studentId]
    );
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Percepción semanal
app.post('/perception', async (req, res) => {
  const { studentId, subject, emotion, weekStart, notes } = req.body;
  if (!studentId || !subject || !emotion) {
    return res.status(400).json({ error: 'Falta studentId, subject o emotion' });
  }
  const week = weekStart ? new Date(weekStart) : new Date();
  const start = new Date(week);
  start.setDate(start.getDate() - (start.getDay() === 0 ? 6 : start.getDay() - 1));
  const sqlDate = start.toISOString().slice(0, 10);
  try {
    await pool.query(
      'INSERT INTO weekly_perceptions (student_id, subject, week_start, emotion, notes) VALUES (?, ?, ?, ?, ?)',
      [studentId, subject, sqlDate, emotion, notes || null]
    );
    res.json({ ok: true });
  } catch (e) {
    if (e.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'Ya capturaste esta materia en la semana' });
    }
    res.status(500).json({ error: e.message });
  }
});

app.get('/perception', async (req, res) => {
  const { studentId } = req.query;
  if (!studentId) return res.status(400).json({ error: 'Falta studentId' });
  try {
    const [rows] = await pool.query(
      'SELECT id, subject, week_start AS weekStart, emotion, notes FROM weekly_perceptions WHERE student_id = ? ORDER BY week_start DESC',
      [studentId]
    );
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Justificantes
app.post('/justifications', async (req, res) => {
  const { studentId, type, evidenceUrl, groupId } = req.body;
  if (!studentId || !type || !groupId) {
    return res.status(400).json({ error: 'Falta studentId, type o groupId' });
  }
  try {
    const [[membership]] = await pool.query(
      'SELECT gm.id FROM group_members gm WHERE gm.student_id = ? AND gm.group_id = ? LIMIT 1',
      [studentId, groupId]
    );
    if (!membership) return res.status(400).json({ error: 'El alumno debe pertenecer a este grupo' });
    await pool.query(
      'INSERT INTO justifications (student_id, group_id, type, evidence_url) VALUES (?, ?, ?, ?)',
      [studentId, groupId, type, evidenceUrl || null]
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/justifications', async (req, res) => {
  const { studentId, tutorId } = req.query;
  try {
    if (studentId) {
      const [rows] = await pool.query(
        'SELECT id, group_id AS groupId, type, evidence_url AS evidenceUrl, status, created_at AS createdAt FROM justifications WHERE student_id = ? ORDER BY created_at DESC',
        [studentId]
      );
      return res.json(rows);
    }
    if (tutorId) {
      const [groups] = await pool.query('SELECT id FROM `groups` WHERE tutor_id = ?', [tutorId]);
      const ids = groups.map((g) => g.id);
      if (!ids.length) return res.json([]);
      const [rows] = await pool.query(
        `SELECT j.id, j.group_id AS groupId, j.type, j.evidence_url AS evidenceUrl, j.status, j.created_at AS createdAt, u.name AS student, u.id AS studentId
         FROM justifications j
         JOIN users u ON u.id = j.student_id
         JOIN group_members gm ON gm.student_id = j.student_id
         WHERE gm.group_id IN (${ids.map(() => '?').join(',')})
         ORDER BY j.created_at DESC`,
        ids
      );
      return res.json(rows);
    }
    res.status(400).json({ error: 'Proporciona studentId o tutorId' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.patch('/justifications/:id', async (req, res) => {
  const { id } = req.params;
  const { status, reviewerId } = req.body;
  if (!['approved', 'rejected', 'pending'].includes(status)) {
    return res.status(400).json({ error: 'Estado inválido' });
  }
  try {
    await pool.query(
      'UPDATE justifications SET status = ?, reviewer_id = ?, resolved_at = NOW() WHERE id = ?',
      [status, reviewerId || null, id]
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Alertas
app.get('/alerts', async (req, res) => {
  const { studentId, tutorId } = req.query;
  try {
    if (studentId) {
      const [rows] = await pool.query(
        'SELECT id, type, severity, message, created_at AS createdAt FROM alerts WHERE student_id = ? ORDER BY created_at DESC',
        [studentId]
      );
      return res.json(rows);
    }
    if (tutorId) {
      const [groups] = await pool.query('SELECT id FROM `groups` WHERE tutor_id = ?', [tutorId]);
      const ids = groups.map((g) => g.id);
      if (!ids.length) return res.json([]);
      const [rows] = await pool.query(
        `SELECT a.id, a.type, a.severity, a.message, a.created_at AS createdAt, u.name AS student
         FROM alerts a
         JOIN users u ON u.id = a.student_id
         JOIN group_members gm ON gm.student_id = a.student_id
         WHERE gm.group_id IN (${ids.map(() => '?').join(',')})
         ORDER BY a.created_at DESC`,
        ids
      );
      return res.json(rows);
    }
    res.status(400).json({ error: 'Proporciona studentId o tutorId' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Mensajes
app.post('/messages', async (req, res) => {
  const { fromUserId, toUserId, groupId, body } = req.body;
  if (!fromUserId || !body) return res.status(400).json({ error: 'Falta fromUserId o body' });
  if (!toUserId && !groupId) return res.status(400).json({ error: 'Requiere toUserId o groupId' });
  try {
    const [result] = await pool.query(
      'INSERT INTO messages (from_user_id, to_user_id, group_id, body) VALUES (?, ?, ?, ?)',
      [fromUserId, toUserId || null, groupId || null, body]
    );
    res.json({ id: result.insertId });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/messages', async (req, res) => {
  const { groupId, fromUserId, toUserId } = req.query;
  try {
    if (groupId) {
      const [rows] = await pool.query(
        'SELECT id, from_user_id AS fromUserId, group_id AS groupId, body, created_at AS createdAt FROM messages WHERE group_id = ? ORDER BY created_at DESC',
        [groupId]
      );
      return res.json(rows);
    }
    if (fromUserId && toUserId) {
      const [rows] = await pool.query(
        `SELECT id, from_user_id AS fromUserId, to_user_id AS toUserId, body, created_at AS createdAt
         FROM messages
         WHERE (from_user_id = ? AND to_user_id = ?)
            OR (from_user_id = ? AND to_user_id = ?)
         ORDER BY created_at DESC`,
        [fromUserId, toUserId, toUserId, fromUserId]
      );
      return res.json(rows);
    }
    res.status(400).json({ error: 'Proporciona groupId o par fromUserId/toUserId' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.listen(port, () => {
  console.log(`API lista en puerto ${port}`);
});
