const bcrypt = require('bcryptjs');
const db = require('../config/db');

// GET /users
exports.getUsers = async (req, res) => {
  try {
    const { role, supervisor_id, is_active = true } = req.query;
    let query = `
      SELECT u.id, u.full_name, u.email, u.phone, u.employee_code,
             u.profile_photo_url, u.is_active, u.last_seen_at, u.created_at,
             r.name AS role, s.full_name AS supervisor_name
      FROM users u
      LEFT JOIN roles r ON u.role_id = r.id
      LEFT JOIN users s ON u.supervisor_id = s.id
      WHERE u.company_id = $1 AND u.is_active = $2
    `;
    const params = [req.user.company_id, is_active];

    if (role) { query += ` AND r.name = $${params.length + 1}`; params.push(role); }
    if (supervisor_id) { query += ` AND u.supervisor_id = $${params.length + 1}`; params.push(supervisor_id); }
    query += ' ORDER BY u.full_name';

    const result = await db.query(query, params);
    res.json({ success: true, users: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /users
exports.createUser = async (req, res) => {
  try {
    const { full_name, email, phone, password, role_name, supervisor_id, employee_code } = req.body;

    const roleRes = await db.query(
      `SELECT id FROM roles WHERE name = $1 AND company_id = $2`,
      [role_name, req.user.company_id]
    );
    if (!roleRes.rows.length) {
      return res.status(400).json({ success: false, message: 'Invalid role' });
    }

    const hash = await bcrypt.hash(password, 12);
    const result = await db.query(
      `INSERT INTO users (company_id, role_id, supervisor_id, full_name, email, phone, password_hash, employee_code)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, full_name, email, phone, employee_code`,
      [req.user.company_id, roleRes.rows[0].id, supervisor_id || null, full_name, email.toLowerCase(), phone, hash, employee_code]
    );

    res.status(201).json({ success: true, user: result.rows[0] });
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ success: false, message: 'Email already exists' });
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// PUT /users/:id
exports.updateUser = async (req, res) => {
  try {
    const { full_name, phone, employee_code, supervisor_id, is_active, role_name } = req.body;

    let roleId = null;
    if (role_name) {
      const roleRes = await db.query(
        `SELECT id FROM roles WHERE name = $1 AND company_id = $2`,
        [role_name, req.user.company_id]
      );
      if (roleRes.rows.length) roleId = roleRes.rows[0].id;
    }

    const result = await db.query(
      `UPDATE users SET
         full_name = COALESCE($1, full_name),
         phone = COALESCE($2, phone),
         employee_code = COALESCE($3, employee_code),
         supervisor_id = COALESCE($4, supervisor_id),
         is_active = COALESCE($5, is_active),
         role_id = COALESCE($6, role_id),
         updated_at = NOW()
       WHERE id = $7 AND company_id = $8
       RETURNING id, full_name, email, phone, is_active`,
      [full_name, phone, employee_code, supervisor_id, is_active, roleId, req.params.id, req.user.company_id]
    );

    if (!result.rows.length) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, user: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /users/:id/location  - latest location
exports.getUserLocation = async (req, res) => {
  try {
    const result = await db.query(
      `SELECT l.*, u.full_name FROM location_logs l
       JOIN users u ON l.user_id = u.id
       WHERE l.user_id = $1 AND u.company_id = $2
       ORDER BY l.recorded_at DESC LIMIT 1`,
      [req.params.id, req.user.company_id]
    );
    res.json({ success: true, location: result.rows[0] || null });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /users/locations/live  - all officers latest location
exports.getLiveLocations = async (req, res) => {
  try {
    const result = await db.query(
      `SELECT DISTINCT ON (l.user_id)
         l.user_id, l.latitude, l.longitude, l.recorded_at,
         u.full_name, u.profile_photo_url, u.phone
       FROM location_logs l
       JOIN users u ON l.user_id = u.id
       JOIN roles r ON u.role_id = r.id
       WHERE u.company_id = $1 AND r.name = 'officer'
         AND l.recorded_at > NOW() - INTERVAL '2 hours'
       ORDER BY l.user_id, l.recorded_at DESC`,
      [req.user.company_id]
    );
    res.json({ success: true, locations: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
