const db = require('../config/db');

// ─── LOCATION ──────────────────────────────────────────────────────────

// POST /tracking/location
exports.logLocation = async (req, res) => {
  try {
    const { latitude, longitude, accuracy, battery_level } = req.body;
    await db.query(
      `INSERT INTO location_logs (user_id, latitude, longitude, accuracy, battery_level)
       VALUES ($1, $2, $3, $4, $5)`,
      [req.user.id, latitude, longitude, accuracy, battery_level]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /tracking/location/batch  - multiple points from offline queue
exports.logLocationBatch = async (req, res) => {
  try {
    const { locations } = req.body; // array of {latitude, longitude, accuracy, battery_level, recorded_at}
    if (!Array.isArray(locations) || !locations.length) {
      return res.status(400).json({ success: false, message: 'locations array required' });
    }

    const values = locations.map((l, i) => {
      const base = i * 5;
      return `($${base + 1}, $${base + 2}, $${base + 3}, $${base + 4}, $${base + 5})`;
    }).join(', ');

    const params = locations.flatMap(l => [
      req.user.id, l.latitude, l.longitude, l.accuracy || null, l.battery_level || null,
    ]);

    await db.query(
      `INSERT INTO location_logs (user_id, latitude, longitude, accuracy, battery_level)
       VALUES ${values}`,
      params
    );

    res.json({ success: true, count: locations.length });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /tracking/location/history?user_id=&date=
exports.getLocationHistory = async (req, res) => {
  try {
    const { user_id, date } = req.query;
    const targetUser = user_id || req.user.id;
    const targetDate = date || new Date().toISOString().split('T')[0];

    const result = await db.query(
      `SELECT latitude, longitude, accuracy, battery_level, recorded_at
       FROM location_logs
       WHERE user_id = $1 AND recorded_at::date = $2
       ORDER BY recorded_at ASC`,
      [targetUser, targetDate]
    );

    res.json({ success: true, path: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ─── ATTENDANCE ────────────────────────────────────────────────────────

// POST /tracking/attendance/checkin
exports.checkIn = async (req, res) => {
  try {
    const { latitude, longitude, photo_url } = req.body;
    const today = new Date().toISOString().split('T')[0];

    // Check if already checked in
    const existing = await db.query(
      `SELECT id, check_in_time FROM attendance WHERE user_id = $1 AND date = $2`,
      [req.user.id, today]
    );

    if (existing.rows.length && existing.rows[0].check_in_time) {
      return res.status(409).json({ success: false, message: 'Already checked in today' });
    }

    const result = await db.query(
      `INSERT INTO attendance (user_id, date, check_in_time, check_in_lat, check_in_lng, check_in_photo_url, status)
       VALUES ($1, $2, NOW(), $3, $4, $5, 'present')
       ON CONFLICT (user_id, date) DO UPDATE SET
         check_in_time = NOW(), check_in_lat = $3, check_in_lng = $4, check_in_photo_url = $5
       RETURNING *`,
      [req.user.id, today, latitude, longitude, photo_url]
    );

    res.json({ success: true, attendance: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /tracking/attendance/checkout
exports.checkOut = async (req, res) => {
  try {
    const { latitude, longitude, photo_url } = req.body;
    const today = new Date().toISOString().split('T')[0];

    const result = await db.query(
      `UPDATE attendance SET
         check_out_time = NOW(), check_out_lat = $1, check_out_lng = $2, check_out_photo_url = $3
       WHERE user_id = $4 AND date = $5 AND check_in_time IS NOT NULL
       RETURNING *`,
      [latitude, longitude, photo_url, req.user.id, today]
    );

    if (!result.rows.length) {
      return res.status(400).json({ success: false, message: 'No check-in found for today' });
    }

    res.json({ success: true, attendance: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /tracking/attendance?user_id=&month=&year=
exports.getAttendance = async (req, res) => {
  try {
    const { user_id, month, year } = req.query;
    const targetUser = user_id || req.user.id;
    const m = month || new Date().getMonth() + 1;
    const y = year || new Date().getFullYear();

    const result = await db.query(
      `SELECT a.*, u.full_name
       FROM attendance a
       JOIN users u ON a.user_id = u.id
       WHERE a.user_id = $1
         AND EXTRACT(MONTH FROM a.date) = $2
         AND EXTRACT(YEAR FROM a.date) = $3
       ORDER BY a.date DESC`,
      [targetUser, m, y]
    );

    res.json({ success: true, records: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /tracking/attendance/team  - supervisor/admin sees team attendance today
exports.getTeamAttendance = async (req, res) => {
  try {
    const date = req.query.date || new Date().toISOString().split('T')[0];

    const result = await db.query(
      `SELECT u.id, u.full_name, u.profile_photo_url,
              a.check_in_time, a.check_out_time, a.status
       FROM users u
       LEFT JOIN attendance a ON u.id = a.user_id AND a.date = $1
       JOIN roles r ON u.role_id = r.id
       WHERE u.company_id = $2 AND r.name = 'officer' AND u.is_active = true
       ORDER BY u.full_name`,
      [date, req.user.company_id]
    );

    res.json({ success: true, team: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ─── TRAVEL EXPENSES ───────────────────────────────────────────────────

// POST /tracking/travel
exports.logTravel = async (req, res) => {
  try {
    const { date, from_location, to_location, distance_km, transport_mode, amount, notes } = req.body;
    const result = await db.query(
      `INSERT INTO travel_expenses (user_id, date, from_location, to_location, distance_km, transport_mode, amount, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
      [req.user.id, date, from_location, to_location, distance_km, transport_mode, amount, notes]
    );
    res.status(201).json({ success: true, expense: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /tracking/travel?month=&year=
exports.getTravelExpenses = async (req, res) => {
  try {
    const { user_id, month, year } = req.query;
    const targetUser = user_id || req.user.id;
    const m = month || new Date().getMonth() + 1;
    const y = year || new Date().getFullYear();

    const result = await db.query(
      `SELECT t.*, u.full_name, approver.full_name AS approved_by_name
       FROM travel_expenses t
       JOIN users u ON t.user_id = u.id
       LEFT JOIN users approver ON t.approved_by = approver.id
       WHERE t.user_id = $1
         AND EXTRACT(MONTH FROM t.date) = $2
         AND EXTRACT(YEAR FROM t.date) = $3
       ORDER BY t.date DESC`,
      [targetUser, m, y]
    );

    const total = result.rows.reduce((sum, r) => sum + parseFloat(r.amount), 0);
    res.json({ success: true, expenses: result.rows, total });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// PATCH /tracking/travel/:id/approve
exports.approveTravel = async (req, res) => {
  try {
    const { status } = req.body; // approved or rejected
    const result = await db.query(
      `UPDATE travel_expenses SET status = $1, approved_by = $2
       WHERE id = $3 RETURNING *`,
      [status, req.user.id, req.params.id]
    );
    res.json({ success: true, expense: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
