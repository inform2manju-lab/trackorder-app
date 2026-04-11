const express = require('express');
const router = express.Router();
const auth = require('../controllers/authController');
const users = require('../controllers/usersController');
const tracking = require('../controllers/trackingController');
const orders = require('../controllers/ordersController');
const catalog = require('../controllers/catalogController');
const tasks = require('../controllers/tasksController');
const dashboard = require('../controllers/dashboardController');
const { authenticate, authorize } = require('../middleware/auth');

// ─── AUTH ─────────────────────────────────────────────────────────────
router.post('/auth/login', auth.login);
router.post('/auth/register-company', auth.registerCompany);
router.get('/auth/me', authenticate, auth.getMe);
router.post('/auth/change-password', authenticate, auth.changePassword);

// ─── USERS ────────────────────────────────────────────────────────────
router.get('/users', authenticate, authorize('admin', 'supervisor'), users.getUsers);
router.post('/users', authenticate, authorize('admin'), users.createUser);
router.put('/users/:id', authenticate, authorize('admin'), users.updateUser);
router.get('/users/locations/live', authenticate, authorize('admin', 'supervisor'), users.getLiveLocations);
router.get('/users/:id/location', authenticate, authorize('admin', 'supervisor'), users.getUserLocation);

// ─── TRACKING ────────────────────────────────────────────────────────
router.post('/tracking/location', authenticate, tracking.logLocation);
router.post('/tracking/location/batch', authenticate, tracking.logLocationBatch);
router.get('/tracking/location/history', authenticate, tracking.getLocationHistory);

router.post('/tracking/attendance/checkin', authenticate, tracking.checkIn);
router.post('/tracking/attendance/checkout', authenticate, tracking.checkOut);
router.get('/tracking/attendance', authenticate, tracking.getAttendance);
router.get('/tracking/attendance/team', authenticate, authorize('admin', 'supervisor'), tracking.getTeamAttendance);

router.post('/tracking/travel', authenticate, tracking.logTravel);
router.get('/tracking/travel', authenticate, tracking.getTravelExpenses);
router.patch('/tracking/travel/:id/approve', authenticate, authorize('admin', 'supervisor'), tracking.approveTravel);

// ─── PRODUCTS & CATEGORIES ──────────────────────────────────────────
router.get('/products', authenticate, catalog.getProducts);
router.post('/products', authenticate, authorize('admin'), catalog.createProduct);
router.put('/products/:id', authenticate, authorize('admin'), catalog.updateProduct);
router.get('/products/categories', authenticate, catalog.getCategories);
router.post('/products/categories', authenticate, authorize('admin'), catalog.createCategory);

// ─── CUSTOMERS ───────────────────────────────────────────────────────
router.get('/customers', authenticate, catalog.getCustomers);
router.post('/customers', authenticate, catalog.createCustomer);
router.put('/customers/:id', authenticate, catalog.updateCustomer);
router.get('/customers/:id/ledger', authenticate, catalog.getCustomerLedger);
router.post('/customers/:id/visit', authenticate, catalog.logVisit);

// ─── ORDERS ──────────────────────────────────────────────────────────
router.post('/orders', authenticate, orders.createOrder);
router.get('/orders', authenticate, orders.getOrders);
router.get('/orders/:id', authenticate, orders.getOrder);
router.patch('/orders/:id/status', authenticate, orders.updateOrderStatus);

// ─── TASKS ───────────────────────────────────────────────────────────
router.get('/tasks', authenticate, tasks.getTasks);
router.post('/tasks', authenticate, authorize('admin', 'supervisor'), tasks.createTask);
router.patch('/tasks/:id/status', authenticate, tasks.updateTaskStatus);

// ─── TARGETS & COLLECTIONS ──────────────────────────────────────────
router.post('/targets', authenticate, authorize('admin'), tasks.setTarget);
router.get('/targets/vs-actual', authenticate, tasks.getTargetVsActual);
router.post('/collections', authenticate, tasks.createCollection);

// ─── DASHBOARD & REPORTS ─────────────────────────────────────────────
router.get('/dashboard', authenticate, dashboard.getDashboard);
router.get('/reports/sales', authenticate, authorize('admin', 'supervisor'), dashboard.getSalesReport);
router.get('/reports/stock', authenticate, authorize('admin'), dashboard.getStockReport);
router.get('/notifications', authenticate, dashboard.getNotifications);

module.exports = router;
