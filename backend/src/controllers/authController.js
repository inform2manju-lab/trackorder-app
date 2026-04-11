const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../config/db');

const generateToken = (userId) =>
  jwt.sign({ userId }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN || '7d' });

// POST /auth/login
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    const result = await db.query(
      `SELECT u.*, r.name AS role_name, r.permissions, c.name AS company_name, c.theme_color, c.logo_url
       FROM users u
       LEFT JOIN roles r ON u.role_id = r.id
       LEFT JOIN companies c ON u.company_id = c.id
       WHERE u.email = $1 AND u.is_active = true`,
      [email.toLowerCase()]
    );

    if (!result.rows.length) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    const user = result.rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    // Update last seen
    await db.query('UPDATE users SET last_seen_at = NOW() WHERE id = $1', [user.id]);

    const token = generateToken(user.id);

    res.json({
      success: true,
      token,
      user: {
        id: user.id,
        full_name: user.full_name,
        email: user.email,
        phone: user.phone,
        role: user.role_name,
        permissions: user.permissions,
        employee_code: user.employee_code,
        profile_photo_url: user.profile_photo_url,
        company: {
          id: user.company_id,
          name: user.company_name,
          theme_color: user.theme_color,
          logo_url: user.logo_url,
        },
      },
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /auth/register-company  (Creates company + first admin user)
exports.registerCompany = async (req, res) => {
  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    const { company_name, app_name, admin_name, email, password, phone } = req.body;

    // Create company
    const companyRes = await client.query(
      `INSERT INTO companies (name, app_name) VALUES ($1, $2) RETURNING *`,
      [company_name, app_name || company_name]
    );
    const company = companyRes.rows[0];

    // Create admin role for this company
    const roleRes = await client.query(
      `INSERT INTO roles (name, company_id, permissions) VALUES ('admin', $1, $2) RETURNING *`,
      [company.id, JSON.stringify({ all: true })]
    );

    // Also create supervisor & officer roles
    await client.query(
      `INSERT INTO roles (name, company_id, permissions) VALUES ('supervisor', $1, $2), ('officer', $1, $3)`,
      [company.id, JSON.stringify({ view_team: true }), JSON.stringify({ self_only: true })]
    );

    const passwordHash = await bcrypt.hash(password, 12);

    const userRes = await client.query(
      `INSERT INTO users (company_id, role_id, full_name, email, phone, password_hash)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, full_name, email`,
      [company.id, roleRes.rows[0].id, admin_name, email.toLowerCase(), phone, passwordHash]
    );

    await client.query('COMMIT');

    const token = generateToken(userRes.rows[0].id);

    res.status(201).json({
      success: true,
      message: 'Company registered successfully',
      token,
      user: userRes.rows[0],
      company,
    });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Register error:', err);
    if (err.code === '23505') {
      return res.status(409).json({ success: false, message: 'Email already registered' });
    }
    res.status(500).json({ success: false, message: 'Server error' });
  } finally {
    client.release();
  }
};

// GET /auth/me
exports.getMe = async (req, res) => {
  res.json({ success: true, user: req.user });
};

// POST /auth/change-password
exports.changePassword = async (req, res) => {
  try {
    const { current_password, new_password } = req.body;
    const valid = await bcrypt.compare(current_password, req.user.password_hash);
    if (!valid) {
      return res.status(400).json({ success: false, message: 'Current password is incorrect' });
    }
    const hash = await bcrypt.hash(new_password, 12);
    await db.query('UPDATE users SET password_hash = $1 WHERE id = $2', [hash, req.user.id]);
    res.json({ success: true, message: 'Password changed successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
