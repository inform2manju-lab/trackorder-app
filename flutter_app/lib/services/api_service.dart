import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'https://trackorder-app-production.up.railway.app/api/v1';
  static final _storage = FlutterSecureStorage();
  static late Dio _dio;

  static void init() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));

    // Auth interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Handle token expiry - navigate to login
        }
        return handler.next(error);
      },
    ));
  }

  // ─── AUTH ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    final data = response.data;
    if (data['success']) {
      await _storage.write(key: 'auth_token', value: data['token']);
    }
    return data;
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }

  static Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/auth/me');
    return response.data;
  }

  // ─── LOCATION ────────────────────────────────────────────────────
  static Future<void> logLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    int? batteryLevel,
  }) async {
    await _dio.post('/tracking/location', data: {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'battery_level': batteryLevel,
    });
  }

  static Future<void> logLocationBatch(List<Map<String, dynamic>> locations) async {
    await _dio.post('/tracking/location/batch', data: {'locations': locations});
  }

  static Future<Map<String, dynamic>> getLiveLocations() async {
    final response = await _dio.get('/users/locations/live');
    return response.data;
  }

  // ─── ATTENDANCE ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> checkIn({
    required double latitude,
    required double longitude,
    String? photoUrl,
  }) async {
    final response = await _dio.post('/tracking/attendance/checkin', data: {
      'latitude': latitude,
      'longitude': longitude,
      'photo_url': photoUrl,
    });
    return response.data;
  }

  static Future<Map<String, dynamic>> checkOut({
    required double latitude,
    required double longitude,
    String? photoUrl,
  }) async {
    final response = await _dio.post('/tracking/attendance/checkout', data: {
      'latitude': latitude,
      'longitude': longitude,
      'photo_url': photoUrl,
    });
    return response.data;
  }

  static Future<Map<String, dynamic>> getAttendance({String? userId, int? month, int? year}) async {
    final response = await _dio.get('/tracking/attendance', queryParameters: {
      if (userId != null) 'user_id': userId,
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
    return response.data;
  }

  // ─── ORDERS ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    final response = await _dio.post('/orders', data: orderData);
    return response.data;
  }

  static Future<Map<String, dynamic>> getOrders({
    String? status,
    String? customerId,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get('/orders', queryParameters: {
      if (status != null) 'status': status,
      if (customerId != null) 'customer_id': customerId,
      'page': page,
      'limit': limit,
    });
    return response.data;
  }

  static Future<Map<String, dynamic>> getOrder(String id) async {
    final response = await _dio.get('/orders/$id');
    return response.data;
  }

  // ─── CUSTOMERS ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getCustomers({String? search}) async {
    final response = await _dio.get('/customers', queryParameters: {
      if (search != null) 'search': search,
    });
    return response.data;
  }

  static Future<Map<String, dynamic>> getCustomerLedger(String customerId) async {
    final response = await _dio.get('/customers/$customerId/ledger');
    return response.data;
  }

  // ─── PRODUCTS ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getProducts({String? search, String? categoryId}) async {
    final response = await _dio.get('/products', queryParameters: {
      if (search != null) 'search': search,
      if (categoryId != null) 'category_id': categoryId,
    });
    return response.data;
  }

  // ─── TASKS ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getTasks({String? status}) async {
    final response = await _dio.get('/tasks', queryParameters: {
      if (status != null) 'status': status,
    });
    return response.data;
  }

  static Future<Map<String, dynamic>> updateTaskStatus(String id, String status) async {
    final response = await _dio.patch('/tasks/$id/status', data: {'status': status});
    return response.data;
  }

  // ─── DASHBOARD ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDashboard() async {
    final response = await _dio.get('/dashboard');
    return response.data;
  }

  static Future<Map<String, dynamic>> getNotifications() async {
    final response = await _dio.get('/notifications');
    return response.data;
  }
}
