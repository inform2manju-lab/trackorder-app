const db = require('../config/db');

// ─── PRODUCTS ─────────────────────────────────────────────────────────

exports.getProducts = async (req, res) => {
  try {
    const { category_id, search, low_stock } = req.query;
    let where = `WHERE p.company_id = $1 AND p.is_active = true`;
    const params = [req.user.company_id];

    if (category_id) { where += ` AND p.category_id = $${params.length + 1}`; params.push(category_id); }
    if (search) { where += ` AND p.name ILIKE $${params.length + 1}`; params.push(`%${search}%`); }
    if (low_stock === 'true') { where += ` AND p.stock_quantity <= p.min_stock_level`; }

    const result = await db.query(
      `SELECT p.*, pc.name AS category_name
       FROM products p
       LEFT JOIN product_categories pc ON p.category_id = pc.id
       ${where}
       ORDER BY p.name`,
      params
    );

    res.json({ success: true, products: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

exports.createProduct = async (req, res) => {
  try {
    const { name, sku, category_id, description, unit, price, cost_price, tax_percent, stock_quantity, min_stock_level, image_url } = req.body;

    const result = await db.query(
      `INSERT INTO products (company_id, category_id, name, sku, description, unit, price, cost_price, tax_percent, stock_quantity, min_stock_level, image_url)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
      [req.user.company_id, category_id, name, sku, description, unit, price, cost_price, tax_percent || 0, stock_quantity || 0, min_stock_level || 0, image_url]
    );

    res.status(201).json({ success: true, product: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

exports.updateProduct = async (req, res) => {
  try {
    const { name, price, stock_quantity, is_active, ...rest } = req.body;
    const result = await db.query(
      `UPDATE products SET
         name = COALESCE($1, name),
         price = COALESCE($2, price),
         stock_quantity = COALESCE($3, stock_quantity),
         is_active = COALESCE($4, is_active),
         updated_at = NOW()
       WHERE id = $5 AND company_id = $6 RETURNING *`,
      [name, price, stock_quantity, is_active, req.params.id, req.user.company_id]
    );
    if (!result.rows.length) return res.status(404).json({ success: false, message: 'Product not found' });
    res.json({ success: true, product: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// Product categories
exports.getCategories = async (req, res) => {
  const result = await db.query(
    `SELECT * FROM product_categories WHERE company_id = $1 ORDER BY name`,
    [req.user.company_id]
  );
  res.json({ success: true, categories: result.rows });
};

exports.createCategory = async (req, res) => {
  const { name, description } = req.body;
  const result = await db.query(
    `INSERT INTO product_categories (company_id, name, description) VALUES ($1, $2, $3) RETURNING *`,
    [req.user.company_id, name, description]
  );
  res.status(201).json({ success: true, category: result.rows[0] });
};

// ─── CUSTOMERS ────────────────────────────────────────────────────────

exports.getCustomers = async (req, res) => {
  try {
    const { assigned_to, search } = req.query;
    let where = `WHERE c.company_id = $1 AND c.is_active = true`;
    const params = [req.user.company_id];

    if (req.user.role_name === 'officer') {
      where += ` AND c.assigned_to = $${params.length + 1}`;
      params.push(req.user.id);
    } else if (assigned_to) {
      where += ` AND c.assigned_to = $${params.length + 1}`;
      params.push(assigned_to);
    }

    if (search) {
      where += ` AND (c.name ILIKE $${params.length + 1} OR c.phone ILIKE $${params.length + 1})`;
      params.push(`%${search}%`);
    }

    const result = await db.query(
      `SELECT c.*, u.full_name AS assigned_to_name
       FROM customers c
       LEFT JOIN users u ON c.assigned_to = u.id
       ${where}
       ORDER BY c.name`,
      params
    );

    res.json({ success: true, customers: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

exports.createCustomer = async (req, res) => {
  try {
    const { name, phone, email, address, city, latitude, longitude, customer_code, credit_limit, assigned_to } = req.body;

    const result = await db.query(
      `INSERT INTO customers (company_id, assigned_to, name, phone, email, address, city, latitude, longitude, customer_code, credit_limit)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING *`,
      [req.user.company_id, assigned_to || req.user.id, name, phone, email, address, city, latitude, longitude, customer_code, credit_limit || 0]
    );

    res.status(201).json({ success: true, customer: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

exports.updateCustomer = async (req, res) => {
  try {
    const { name, phone, address, city, credit_limit, is_active, assigned_to } = req.body;
    const result = await db.query(
      `UPDATE customers SET
         name = COALESCE($1, name), phone = COALESCE($2, phone),
         address = COALESCE($3, address), city = COALESCE($4, city),
         credit_limit = COALESCE($5, credit_limit),
         is_active = COALESCE($6, is_active),
         assigned_to = COALESCE($7, assigned_to),
         updated_at = NOW()
       WHERE id = $8 AND company_id = $9 RETURNING *`,
      [name, phone, address, city, credit_limit, is_active, assigned_to, req.params.id, req.user.company_id]
    );
    if (!result.rows.length) return res.status(404).json({ success: false, message: 'Customer not found' });
    res.json({ success: true, customer: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

exports.getCustomerLedger = async (req, res) => {
  try {
    const ordersRes = await db.query(
      `SELECT id, order_number, order_date, total_amount, payment_status, status FROM orders
       WHERE customer_id = $1 AND company_id = $2
       ORDER BY order_date DESC`,
      [req.params.id, req.user.company_id]
    );

    const collectionsRes = await db.query(
      `SELECT id, collection_date, amount, payment_method, reference_number FROM collections
       WHERE customer_id = $1 AND company_id = $2
       ORDER BY collection_date DESC`,
      [req.params.id, req.user.company_id]
    );

    const totalOrders = ordersRes.rows.reduce((s, r) => s + parseFloat(r.total_amount), 0);
    const totalPaid = collectionsRes.rows.reduce((s, r) => s + parseFloat(r.amount), 0);

    res.json({
      success: true,
      orders: ordersRes.rows,
      collections: collectionsRes.rows,
      summary: { total_orders: totalOrders, total_paid: totalPaid, outstanding: totalOrders - totalPaid },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /customers/:id/visit
exports.logVisit = async (req, res) => {
  try {
    const { latitude, longitude, notes, photo_url, outcome } = req.body;
    const result = await db.query(
      `INSERT INTO customer_visits (user_id, customer_id, latitude, longitude, notes, photo_url, outcome)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [req.user.id, req.params.id, latitude, longitude, notes, photo_url, outcome]
    );
    res.status(201).json({ success: true, visit: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
