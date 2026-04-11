# TrackOrder — Sales Team Tracking + Ordering App

A full-stack clone of the "Team Tracking Plus Ordering" app from Google Play Store.

---

## 🏗️ Project Structure

```
trackorder-app/
├── backend/                  # Node.js + Express REST API
│   ├── server.js             # Entry point
│   ├── .env.example          # Environment variables template
│   └── src/
│       ├── config/
│       │   ├── db.js         # PostgreSQL connection pool
│       │   └── schema.sql    # Full database schema (run this first)
│       ├── middleware/
│       │   └── auth.js       # JWT authentication + role-based auth
│       ├── controllers/
│       │   ├── authController.js       # Login, register, change password
│       │   ├── usersController.js      # User CRUD + live locations
│       │   ├── trackingController.js   # GPS, attendance, travel expenses
│       │   ├── ordersController.js     # Sales orders
│       │   ├── catalogController.js    # Products, categories, customers
│       │   ├── tasksController.js      # Tasks, targets, collections
│       │   └── dashboardController.js  # Dashboard stats, reports
│       └── routes/
│           └── index.js      # All API routes
│
└── flutter_app/              # Flutter cross-platform mobile app
    ├── pubspec.yaml           # Dependencies
    └── lib/
        ├── main.dart          # App entry + navigation shell
        ├── config/
        │   └── theme.dart     # App theme, colors
        ├── providers/
        │   └── auth_provider.dart     # Auth state management
        ├── services/
        │   ├── api_service.dart       # All API calls (Dio)
        │   └── location_service.dart  # GPS tracking + offline queue
        ├── screens/
        │   ├── auth/login_screen.dart
        │   ├── dashboard/dashboard_screen.dart
        │   ├── tracking/tracking_screen.dart   # Live map
        │   ├── tracking/attendance_screen.dart
        │   ├── orders/orders_screen.dart        # List + Create
        │   └── tasks/tasks_screen.dart
        └── widgets/
            └── stat_card.dart
```

---

## 🚀 Backend Setup

### 1. Prerequisites
- Node.js 18+
- PostgreSQL 14+

### 2. Install & Configure
```bash
cd backend
npm install
cp .env.example .env
# Edit .env with your DB credentials and JWT secret
```

### 3. Setup Database
```bash
psql -U postgres -c "CREATE DATABASE trackorder_db;"
psql -U postgres -d trackorder_db -f src/config/schema.sql
```

### 4. Run the Server
```bash
node server.js
# API running at http://localhost:5000
```

---

## 📱 Flutter App Setup

### 1. Prerequisites
- Flutter 3.x+
- Android Studio / Xcode
- Google Maps API Key

### 2. Install Dependencies
```bash
cd flutter_app
flutter pub get
```

### 3. Configure API URL
In `lib/services/api_service.dart`, update:
```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:5000/api/v1';
```

### 4. Add Google Maps Key

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data android:name="com.google.android.geo.API_KEY"
           android:value="YOUR_GOOGLE_MAPS_KEY"/>
```

**iOS** — `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_KEY")
```

### 5. Run App
```bash
flutter run
```

---

## 🔑 API Overview

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/login` | Login |
| POST | `/auth/register-company` | Register company + admin |
| GET | `/dashboard` | Stats & recent orders |
| POST | `/tracking/location` | Log GPS point |
| POST | `/tracking/location/batch` | Sync offline GPS queue |
| GET | `/users/locations/live` | All officers live locations |
| POST | `/tracking/attendance/checkin` | Check in |
| POST | `/tracking/attendance/checkout` | Check out |
| GET | `/tracking/attendance/team` | Team attendance today |
| POST | `/tracking/travel` | Log travel expense |
| GET | `/orders` | List orders |
| POST | `/orders` | Create order |
| PATCH | `/orders/:id/status` | Update order status |
| GET | `/customers` | List customers |
| GET | `/customers/:id/ledger` | Customer outstanding |
| POST | `/customers/:id/visit` | Log customer visit |
| GET | `/products` | Product catalog |
| GET | `/tasks` | List tasks |
| POST | `/tasks` | Create task |
| POST | `/targets` | Set sales targets |
| GET | `/targets/vs-actual` | Target vs actual |
| POST | `/collections` | Log payment collection |
| GET | `/reports/sales` | Sales report |
| GET | `/reports/stock` | Stock report |

---

## 👥 User Roles

| Role | Access |
|------|--------|
| **admin** | Full access — all officers, all data, reports, settings |
| **supervisor** | View team, assign tasks, approve expenses |
| **officer** | Self only — attendance, own orders, assigned customers/tasks |

---

## 📋 What's Included

- ✅ JWT authentication with role-based access control
- ✅ Multi-company / white-label support
- ✅ Real-time GPS tracking with offline queue sync
- ✅ Attendance with check-in/out + photo support
- ✅ Travel expense management with approval flow
- ✅ Full sales ordering system (cart → order → delivery)
- ✅ Customer management with ledger & visit logging
- ✅ Product catalog with stock management
- ✅ Task assignment with hierarchy
- ✅ Sales targets vs actual tracking
- ✅ Collections / payment tracking
- ✅ Dashboard with KPIs
- ✅ Sales & stock reports
- ✅ Push notification system

---

## 🔜 Next Steps

1. **Web Admin Panel** — React.js dashboard with maps, reports, and charts
2. **File Upload** — Multer + S3/Cloudinary for photos
3. **Push Notifications** — Firebase FCM integration
4. **PDF/Excel Export** — Reports with jsPDF / ExcelJS
5. **Supervisor App** — Dedicated views for team management
