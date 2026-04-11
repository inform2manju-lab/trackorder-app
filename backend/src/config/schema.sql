-- =============================================
-- TrackOrder App - Full Database Schema
-- =============================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis"; -- optional for geo queries

-- =============================================
-- COMPANIES (White-label / Multi-tenant)
-- =============================================
CREATE TABLE companies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(200) NOT NULL,
  logo_url VARCHAR(500),
  app_name VARCHAR(100),
  theme_color VARCHAR(20) DEFAULT '#1976D2',
  address TEXT,
  phone VARCHAR(30),
  email VARCHAR(150),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- ROLES
-- =============================================
CREATE TABLE roles (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL,         -- admin, supervisor, officer
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  permissions JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- USERS
-- =============================================
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  role_id INT REFERENCES roles(id),
  supervisor_id UUID REFERENCES users(id),   -- hierarchy
  full_name VARCHAR(200) NOT NULL,
  email VARCHAR(150) UNIQUE NOT NULL,
  phone VARCHAR(30),
  password_hash VARCHAR(255) NOT NULL,
  employee_code VARCHAR(50),
  profile_photo_url VARCHAR(500),
  is_active BOOLEAN DEFAULT true,
  last_seen_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- ATTENDANCE
-- =============================================
CREATE TABLE attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id),
  date DATE NOT NULL,
  check_in_time TIMESTAMPTZ,
  check_in_photo_url VARCHAR(500),
  check_in_lat DECIMAL(10,8),
  check_in_lng DECIMAL(11,8),
  check_out_time TIMESTAMPTZ,
  check_out_photo_url VARCHAR(500),
  check_out_lat DECIMAL(10,8),
  check_out_lng DECIMAL(11,8),
  status VARCHAR(30) DEFAULT 'present', -- present, absent, half_day, leave
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, date)
);

-- =============================================
-- LOCATION TRACKING
-- =============================================
CREATE TABLE location_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id),
  latitude DECIMAL(10,8) NOT NULL,
  longitude DECIMAL(11,8) NOT NULL,
  accuracy DECIMAL(8,2),
  battery_level INT,
  recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_location_user_time ON location_logs(user_id, recorded_at DESC);

-- =============================================
-- TRAVEL EXPENSES
-- =============================================
CREATE TABLE travel_expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id),
  date DATE NOT NULL,
  from_location VARCHAR(200),
  to_location VARCHAR(200),
  distance_km DECIMAL(8,2),
  transport_mode VARCHAR(50),  -- bike, car, bus, train, auto
  amount DECIMAL(12,2) NOT NULL,
  receipt_url VARCHAR(500),
  status VARCHAR(30) DEFAULT 'pending',  -- pending, approved, rejected
  approved_by UUID REFERENCES users(id),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- TASKS
-- =============================================
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES companies(id),
  assigned_to UUID NOT NULL REFERENCES users(id),
  assigned_by UUID NOT NULL REFERENCES users(id),
  title VARCHAR(300) NOT NULL,
  description TEXT,
  priority VARCHAR(20) DEFAULT 'medium',   -- low, medium, high, urgent
  status VARCHAR(30) DEFAULT 'pending',    -- pending, in_progress, completed, cancelled
  due_date DATE,
  completed_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- CUSTOMERS
-- =============================================
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES companies(id),
  assigned_to UUID REFERENCES users(id),
  name VARCHAR(200) NOT NULL,
  phone VARCHAR(30),
  email VARCHAR(150),
  address TEXT,
  city VARCHAR(100),
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  customer_code VARCHAR(50),
  credit_limit DECIMAL(15,2) DEFAULT 0,
  outstanding_balance DECIMAL(15,2) DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- CUSTOMER VISITS
-- =============================================
CREATE TABLE customer_visits (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id),
  customer_id UUID NOT NULL REFERENCES customers(id),
  visit_time TIMESTAMPTZ DEFAULT NOW(),
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  notes TEXT,
  photo_url VARCHAR(500),
  outcome VARCHAR(100)   -- order_placed, follow_up, no_order, etc.
);

-- =============================================
-- PRODUCT CATEGORIES
-- =============================================
CREATE TABLE product_categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES companies(id),
  name VARCHAR(150) NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- PRODUCTS
-- =============================================
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES companies(id),
  category_id UUID REFERENCES product_categories(id),
  name VARCHAR(300) NOT NULL,
  sku VARCHAR(100),
  description TEXT,
  unit VARCHAR(50),          -- pcs, kg, litre, box, etc.
  price DECIMAL(12,2) NOT NULL,
  cost_price DECIMAL(12,2),
  tax_percent DECIMAL(5,2) DEFAULT 0,
  stock_quantity INT DEFAULT 0,
  min_stock_level INT DEFAULT 0,
  image_url VARCHAR(500),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- SALES ORDERS
-- =============================================
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_number VARCHAR(50) UNIQUE NOT NULL,
  company_id UUID NOT NULL REFERENCES companies(id),
  customer_id UUID NOT NULL REFERENCES customers(id),
  officer_id UUID NOT NULL REFERENCES users(id),
  status VARCHAR(30) DEFAULT 'pending',   -- pending, confirmed, processing, shipped, delivered, cancelled
  order_date TIMESTAMPTZ DEFAULT NOW(),
  delivery_date DATE,
  subtotal DECIMAL(15,2) DEFAULT 0,
  tax_amount DECIMAL(15,2) DEFAULT 0,
  discount_amount DECIMAL(15,2) DEFAULT 0,
  total_amount DECIMAL(15,2) DEFAULT 0,
  payment_status VARCHAR(30) DEFAULT 'unpaid',  -- unpaid, partial, paid
  payment_method VARCHAR(50),
  notes TEXT,
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- ORDER ITEMS
-- =============================================
CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  quantity DECIMAL(12,2) NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL,
  discount_percent DECIMAL(5,2) DEFAULT 0,
  tax_percent DECIMAL(5,2) DEFAULT 0,
  line_total DECIMAL(15,2) NOT NULL
);

-- =============================================
-- COLLECTIONS / PAYMENTS
-- =============================================
CREATE TABLE collections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES companies(id),
  customer_id UUID NOT NULL REFERENCES customers(id),
  officer_id UUID NOT NULL REFERENCES users(id),
  order_id UUID REFERENCES orders(id),
  amount DECIMAL(15,2) NOT NULL,
  payment_method VARCHAR(50),   -- cash, cheque, bank_transfer, upi
  reference_number VARCHAR(100),
  collection_date TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- SALES TARGETS
-- =============================================
CREATE TABLE sales_targets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id),
  month INT NOT NULL,
  year INT NOT NULL,
  sales_target DECIMAL(15,2) DEFAULT 0,
  collection_target DECIMAL(15,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, month, year)
);

-- =============================================
-- SUPPLIERS
-- =============================================
CREATE TABLE suppliers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES companies(id),
  name VARCHAR(200) NOT NULL,
  phone VARCHAR(30),
  email VARCHAR(150),
  address TEXT,
  outstanding_balance DECIMAL(15,2) DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- PURCHASES
-- =============================================
CREATE TABLE purchases (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  purchase_number VARCHAR(50) UNIQUE NOT NULL,
  company_id UUID NOT NULL REFERENCES companies(id),
  supplier_id UUID NOT NULL REFERENCES suppliers(id),
  status VARCHAR(30) DEFAULT 'pending',
  purchase_date TIMESTAMPTZ DEFAULT NOW(),
  total_amount DECIMAL(15,2) DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE purchase_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  purchase_id UUID NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  quantity DECIMAL(12,2) NOT NULL,
  unit_cost DECIMAL(12,2) NOT NULL,
  line_total DECIMAL(15,2) NOT NULL
);

-- =============================================
-- NOTIFICATIONS
-- =============================================
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id),
  title VARCHAR(300) NOT NULL,
  body TEXT,
  type VARCHAR(50),   -- task, order, attendance, system
  reference_id UUID,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- INDEXES
-- =============================================
CREATE INDEX idx_users_company ON users(company_id);
CREATE INDEX idx_orders_officer ON orders(officer_id);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_attendance_user_date ON attendance(user_id, date);
CREATE INDEX idx_customers_company ON customers(company_id);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);
