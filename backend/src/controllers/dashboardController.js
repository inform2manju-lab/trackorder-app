const db = require('../config/db');

// GET /dashboard/summary
exports.getDashboard = async (req, res) => {
  try {
    const companyId = req.user.company_id;
    const today = new Date().toISOString().split('T')[0];
    const month = new Date().getMonth() + 1;
    const year = new Date().getFullYear();

    const [officers, attendance, todayOrders, monthSales, monthCollection, pendingTasks, lowStock, recentOrders] = await Promise.all([
      // Total active officers
      db.query(`SELECT COUNT(*) FROM users u JOIN roles r ON u.role_id = r.id
                WHERE u.company_id = $1 AND r.name = 'officer' AND u.is_active = true`, [companyId]),

      // Today's attendance count
      db.query(`SELECT COUNT(*) FROM attendance WHERE date = $1 AND user_id IN
                (SELECT u.id FROM users u JOIN roles r ON u.role_id = r.id
                 WHERE u.company_id = $2 AND r.name = 'officer')`, [today, companyId]),

      // Today's order count & amount
      db.query(`SELECT COUNT(*) AS count, COALESCE(SUM(total_amount), 0) AS amount
                FROM orders WHERE company_id = $1 AND order_date::date = $2`, [companyId, today]),

      // This month's sales
      db.query(`SELECT COALESCE(SUM(total_amount), 0) AS amount
                FROM orders WHERE company_id = $1
                  AND EXTRACT(MONTH FROM order_date) = $2
                  AND EXTRACT(YEAR FROM order_date) = $3
                  AND status != 'cancelled'`, [companyId, month, year]),

      // This month's collection
      db.query(`SELECT COALESCE(SUM(amount), 0) AS amount
                FROM collections WHERE company_id = $1
                  AND EXTRACT(MONTH FROM collection_date) = $2
                  AND EXTRACT(YEAR FROM collection_date) = $3`, [companyId, month, year]),

      // Pending tasks
      db.query(`SELECT COUNT(*) FROM tasks WHERE company_id = $1 AND status = 'pending'`, [companyId]),

      // Low stock products
      db.query(`SELECT COUNT(*) FROM products
                WHERE company_id = $1 AND stock_quantity <= min_stock_level AND is_active = true`, [companyId]),

      // Recent 5 orders
      db.query(`SELECT o.id, o.order_number, o.total_amount, o.status, o.order_date,
                       c.name AS customer_name, u.full_name AS officer_name
                FROM orders o
                JOIN customers c ON o.customer_id = c.id
                JOIN users u ON o.officer_id = u.id
                WHERE o.company_id = $1
                ORDER BY o.order_date DESC LIMIT 5`, [companyId]),
    ]);

    res.json({
      success: true,
      dashboard: {
        stats: {
          total_officers: parseInt(officers.rows[0].count),
          present_today: parseInt(attendance.rows[0].count),
          today_orders: { count: parseInt(todayOrders.rows[0].count), amount: parseFloat(todayOrders.rows[0].amount) },
          month_sales: parseFloat(monthSales.rows[0].amount),
          month_collection: parseFloat(monthCollection.rows[0].amount),
          pending_tasks: parseInt(pendingTasks.rows[0].count),
          low_stock_products: parseInt(lowStock.rows[0].count),
        },
        recent_orders: recentOrders.rows,
      },
    });
  } catch (err) {
    console.error('Dashboard error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /reports/sales?from=&to=&group_by=day|week|month|officer
exports.getSalesReport = async (req, res) => {
  try {
    const { from_date, to_date, group_by = 'day', officer_id } = req.query;
    const from = from_date || new Date(new Date().setDate(1)).toISOString().split('T')[0];
    const to = to_date || new Date().toISOString().split('T')[0];

    let groupExpr, selectExpr;
    if (group_by === 'officer') {
      selectExpr = `u.full_name AS label`;
      groupExpr = `u.full_name`;
    } else if (group_by === 'month') {
      selectExpr = `TO_CHAR(o.order_date, 'YYYY-MM') AS label`;
      groupExpr = `TO_CHAR(o.order_date, 'YYYY-MM')`;
    } else {
      selectExpr = `o.order_date::date AS label`;
      groupExpr = `o.order_date::date`;
    }

    const params = [req.user.company_id, from, to];
    let officerFilter = '';
    if (officer_id) { officerFilter = ` AND o.officer_id = $${params.length + 1}`; params.push(officer_id); }

    const result = await db.query(
      `SELECT ${selectExpr},
              COUNT(*) AS order_count,
              COALESCE(SUM(o.total_amount), 0) AS total_sales,
              COALESCE(SUM(o.total_amount) FILTER (WHERE o.status = 'delivered'), 0) AS delivered_sales
       FROM orders o
       LEFT JOIN users u ON o.officer_id = u.id
       WHERE o.company_id = $1
         AND o.order_date::date BETWEEN $2 AND $3
         AND o.status != 'cancelled'
         ${officerFilter}
       GROUP BY ${groupExpr}
       ORDER BY label`,
      params
    );

    res.json({ success: true, report: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /reports/stock
exports.getStockReport = async (req, res) => {
  try {
    const result = await db.query(
      `SELECT p.name, p.sku, p.unit, p.stock_quantity, p.min_stock_level, p.price,
              pc.name AS category,
              (p.stock_quantity * p.cost_price) AS stock_value,
              CASE WHEN p.stock_quantity <= p.min_stock_level THEN true ELSE false END AS is_low_stock
       FROM products p
       LEFT JOIN product_categories pc ON p.category_id = pc.id
       WHERE p.company_id = $1 AND p.is_active = true
       ORDER BY p.name`,
      [req.user.company_id]
    );

    const totalValue = result.rows.reduce((s, r) => s + parseFloat(r.stock_value || 0), 0);
    res.json({ success: true, products: result.rows, total_value: totalValue });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /notifications
exports.getNotifications = async (req, res) => {
  try {
    const result = await db.query(
      `SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50`,
      [req.user.id]
    );
    await db.query(`UPDATE notifications SET is_read = true WHERE user_id = $1 AND is_read = false`, [req.user.id]);
    res.json({ success: true, notifications: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
