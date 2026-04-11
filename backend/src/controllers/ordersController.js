const db = require('../config/db');

const generateOrderNumber = () => {
  const now = new Date();
  return `ORD-${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}-${Math.floor(Math.random() * 10000).toString().padStart(4, '0')}`;
};

// POST /orders
exports.createOrder = async (req, res) => {
  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    const { customer_id, items, delivery_date, payment_method, notes, latitude, longitude } = req.body;

    // Validate customer belongs to company
    const custCheck = await client.query(
      `SELECT id FROM customers WHERE id = $1 AND company_id = $2`,
      [customer_id, req.user.company_id]
    );
    if (!custCheck.rows.length) {
      return res.status(400).json({ success: false, message: 'Customer not found' });
    }

    // Calculate totals
    let subtotal = 0;
    let taxAmount = 0;
    const enrichedItems = [];

    for (const item of items) {
      const productRes = await client.query(
        `SELECT id, name, price, tax_percent FROM products WHERE id = $1 AND company_id = $2 AND is_active = true`,
        [item.product_id, req.user.company_id]
      );
      if (!productRes.rows.length) throw new Error(`Product ${item.product_id} not found`);

      const product = productRes.rows[0];
      const unitPrice = item.unit_price || product.price;
      const discountAmt = unitPrice * item.quantity * (item.discount_percent || 0) / 100;
      const lineTotal = unitPrice * item.quantity - discountAmt;
      const lineTax = lineTotal * (item.tax_percent || product.tax_percent) / 100;

      subtotal += lineTotal;
      taxAmount += lineTax;
      enrichedItems.push({ ...item, unit_price: unitPrice, line_total: lineTotal, tax_percent: item.tax_percent || product.tax_percent });
    }

    const discountAmount = req.body.discount_amount || 0;
    const totalAmount = subtotal + taxAmount - discountAmount;

    // Insert order
    const orderRes = await client.query(
      `INSERT INTO orders (order_number, company_id, customer_id, officer_id, delivery_date,
        payment_method, subtotal, tax_amount, discount_amount, total_amount, notes, latitude, longitude)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
       RETURNING *`,
      [generateOrderNumber(), req.user.company_id, customer_id, req.user.id,
       delivery_date, payment_method, subtotal, taxAmount, discountAmount, totalAmount, notes, latitude, longitude]
    );

    const order = orderRes.rows[0];

    // Insert items
    for (const item of enrichedItems) {
      await client.query(
        `INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount_percent, tax_percent, line_total)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [order.id, item.product_id, item.quantity, item.unit_price, item.discount_percent || 0, item.tax_percent || 0, item.line_total]
      );

      // Update stock
      await client.query(
        `UPDATE products SET stock_quantity = stock_quantity - $1 WHERE id = $2`,
        [item.quantity, item.product_id]
      );
    }

    await client.query('COMMIT');

    res.status(201).json({ success: true, order });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Create order error:', err);
    res.status(500).json({ success: false, message: err.message || 'Server error' });
  } finally {
    client.release();
  }
};

// GET /orders
exports.getOrders = async (req, res) => {
  try {
    const { status, customer_id, officer_id, from_date, to_date, page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;
    const params = [req.user.company_id];
    let where = `WHERE o.company_id = $1`;

    // Officers see only their own orders
    if (req.user.role_name === 'officer') {
      where += ` AND o.officer_id = $${params.length + 1}`;
      params.push(req.user.id);
    } else if (officer_id) {
      where += ` AND o.officer_id = $${params.length + 1}`;
      params.push(officer_id);
    }

    if (status) { where += ` AND o.status = $${params.length + 1}`; params.push(status); }
    if (customer_id) { where += ` AND o.customer_id = $${params.length + 1}`; params.push(customer_id); }
    if (from_date) { where += ` AND o.order_date >= $${params.length + 1}`; params.push(from_date); }
    if (to_date) { where += ` AND o.order_date <= $${params.length + 1}`; params.push(to_date); }

    const countRes = await db.query(`SELECT COUNT(*) FROM orders o ${where}`, params);

    params.push(limit, offset);
    const result = await db.query(
      `SELECT o.*, c.name AS customer_name, c.phone AS customer_phone,
              u.full_name AS officer_name
       FROM orders o
       JOIN customers c ON o.customer_id = c.id
       JOIN users u ON o.officer_id = u.id
       ${where}
       ORDER BY o.order_date DESC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params
    );

    res.json({
      success: true,
      orders: result.rows,
      pagination: { total: parseInt(countRes.rows[0].count), page: parseInt(page), limit: parseInt(limit) },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /orders/:id
exports.getOrder = async (req, res) => {
  try {
    const orderRes = await db.query(
      `SELECT o.*, c.name AS customer_name, c.phone AS customer_phone, c.address AS customer_address,
              u.full_name AS officer_name
       FROM orders o
       JOIN customers c ON o.customer_id = c.id
       JOIN users u ON o.officer_id = u.id
       WHERE o.id = $1 AND o.company_id = $2`,
      [req.params.id, req.user.company_id]
    );

    if (!orderRes.rows.length) return res.status(404).json({ success: false, message: 'Order not found' });

    const itemsRes = await db.query(
      `SELECT oi.*, p.name AS product_name, p.sku, p.unit, p.image_url
       FROM order_items oi
       JOIN products p ON oi.product_id = p.id
       WHERE oi.order_id = $1`,
      [req.params.id]
    );

    res.json({ success: true, order: { ...orderRes.rows[0], items: itemsRes.rows } });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// PATCH /orders/:id/status
exports.updateOrderStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const allowed = ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'];
    if (!allowed.includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status' });
    }

    const result = await db.query(
      `UPDATE orders SET status = $1, updated_at = NOW()
       WHERE id = $2 AND company_id = $3 RETURNING *`,
      [status, req.params.id, req.user.company_id]
    );

    res.json({ success: true, order: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
