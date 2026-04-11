const db = require('../config/db');

// ─── TASKS ────────────────────────────────────────────────────────────

exports.getTasks = async (req, res) => {
  try {
    const { status, assigned_to } = req.query;
    let where = `WHERE t.company_id = $1`;
    const params = [req.user.company_id];

    if (req.user.role_name === 'officer') {
      where += ` AND t.assigned_to = $${params.length + 1}`;
      params.push(req.user.id);
    } else if (assigned_to) {
      where += ` AND t.assigned_to = $${params.length + 1}`;
      params.push(assigned_to);
    }

    if (status) { where += ` AND t.status = $${params.length + 1}`; params.push(status); }

    const result = await db.query(
      `SELECT t.*, u.full_name AS assigned_to_name, a.full_name AS assigned_by_name
       FROM tasks t
       JOIN users u ON t.assigned_to = u.id
       JOIN users a ON t.assigned_by = a.id
       ${where}
       ORDER BY t.priority DESC, t.due_date ASC`,
      params
    );

    res.json({ success: true, tasks: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

exports.createTask = async (req, res) => {
  try {
    const { assigned_to, title, description, priority, due_date } = req.body;
    const result = await db.query(
      `INSERT INTO tasks (company_id, assigned_to, assigned_by, title, description, priority, due_date)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [req.user.company_id, assigned_to, req.user.id, title, description, priority || 'medium', due_date]
    );

    // Notify the assigned user
    await db.query(
      `INSERT INTO notifications (user_id, title, body, type, reference_id)
       VALUES ($1, $2, $3, 'task', $4)`,
      [assigned_to, `New Task: ${title}`, `You have been assigned a new task by ${req.user.full_name}`, result.rows[0].id]
    );

    res.status(201).json({ success: true, task: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

exports.updateTaskStatus = async (req, res) => {
  try {
    const { status, notes } = req.body;
    const completedAt = status === 'completed' ? 'NOW()' : 'NULL';

    const result = await db.query(
      `UPDATE tasks SET
         status = $1,
         notes = COALESCE($2, notes),
         completed_at = ${completedAt},
         updated_at = NOW()
       WHERE id = $3 AND company_id = $4 RETURNING *`,
      [status, notes, req.params.id, req.user.company_id]
    );

    res.json({ success: true, task: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ─── SALES TARGETS ────────────────────────────────────────────────────

exports.setTarget = async (req, res) => {
  try {
    const { user_id, month, year, sales_target, collection_target } = req.body;
    const result = await db.query(
      `INSERT INTO sales_targets (user_id, month, year, sales_target, collection_target)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (user_id, month, year) DO UPDATE SET
         sales_target = $4, collection_target = $5
       RETURNING *`,
      [user_id, month, year, sales_target, collection_target]
    );
    res.json({ success: true, target: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

exports.getTargetVsActual = async (req, res) => {
  try {
    const { month, year, user_id } = req.query;
    const m = month || new Date().getMonth() + 1;
    const y = year || new Date().getFullYear();

    let userFilter = `u.company_id = $1`;
    const params = [req.user.company_id, m, y];

    if (req.user.role_name === 'officer') {
      userFilter += ` AND u.id = $${params.length + 1}`;
      params.push(req.user.id);
    } else if (user_id) {
      userFilter += ` AND u.id = $${params.length + 1}`;
      params.push(user_id);
    }

    const result = await db.query(
      `SELECT
         u.id, u.full_name,
         COALESCE(st.sales_target, 0) AS sales_target,
         COALESCE(st.collection_target, 0) AS collection_target,
         COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'cancelled'), 0) AS actual_sales,
         COALESCE(SUM(c.amount), 0) AS actual_collection
       FROM users u
       JOIN roles r ON u.role_id = r.id
       LEFT JOIN sales_targets st ON u.id = st.user_id AND st.month = $2 AND st.year = $3
       LEFT JOIN orders o ON u.id = o.officer_id
         AND EXTRACT(MONTH FROM o.order_date) = $2
         AND EXTRACT(YEAR FROM o.order_date) = $3
       LEFT JOIN collections col ON u.id = col.officer_id
         AND EXTRACT(MONTH FROM col.collection_date) = $2
         AND EXTRACT(YEAR FROM col.collection_date) = $3,
       (SELECT SUM(amount) AS amount FROM collections WHERE officer_id = u.id) c
       WHERE ${userFilter} AND r.name = 'officer' AND u.is_active = true
       GROUP BY u.id, u.full_name, st.sales_target, st.collection_target`,
      params
    );

    res.json({ success: true, data: result.rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ─── COLLECTIONS ──────────────────────────────────────────────────────

exports.createCollection = async (req, res) => {
  try {
    const { customer_id, order_id, amount, payment_method, reference_number, notes } = req.body;

    const result = await db.query(
      `INSERT INTO collections (company_id, customer_id, officer_id, order_id, amount, payment_method, reference_number, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [req.user.company_id, customer_id, req.user.id, order_id || null, amount, payment_method, reference_number, notes]
    );

    // Update customer outstanding balance
    await db.query(
      `UPDATE customers SET outstanding_balance = outstanding_balance - $1 WHERE id = $2`,
      [amount, customer_id]
    );

    // Update order payment status if linked
    if (order_id) {
      await db.query(
        `UPDATE orders SET
           payment_status = CASE
             WHEN (SELECT SUM(amount) FROM collections WHERE order_id = $1) >= total_amount THEN 'paid'
             ELSE 'partial'
           END
         WHERE id = $1`,
        [order_id]
      );
    }

    res.status(201).json({ success: true, collection: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
