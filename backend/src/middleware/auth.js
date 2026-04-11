const jwt = require('jsonwebtoken');
const db = require('../config/db');

const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ success: false, message: 'No token provided' });
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    const result = await db.query(
      `SELECT u.*, r.name AS role_name, r.permissions
       FROM users u
       LEFT JOIN roles r ON u.role_id = r.id
       WHERE u.id = $1 AND u.is_active = true`,
      [decoded.userId]
    );

    if (!result.rows.length) {
      return res.status(401).json({ success: false, message: 'User not found or inactive' });
    }

    req.user = result.rows[0];
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Invalid or expired token' });
  }
};

const authorize = (...roles) => (req, res, next) => {
  if (!roles.includes(req.user.role_name)) {
    return res.status(403).json({ success: false, message: 'Access denied' });
  }
  next();
};

module.exports = { authenticate, authorize };
