import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../../widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getDashboard();
      if (mounted) setState(() { _data = data['dashboard']; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final stats = _data?['stats'] ?? {};
    final recentOrders = List<Map<String, dynamic>>.from(_data?['recent_orders'] ?? []);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${user?['full_name']?.split(' ').first ?? 'User'} 👋',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user?['company']?['name'] ?? '',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),

            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else ...[
              // Stats Grid
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  delegate: SliverChildListDelegate([
                    StatCard(
                      title: 'Officers',
                      value: '${stats['total_officers'] ?? 0}',
                      subtitle: 'Present: ${stats['present_today'] ?? 0}',
                      icon: Icons.people,
                      color: AppTheme.primary,
                    ),
                    StatCard(
                      title: "Today's Orders",
                      value: '${stats['today_orders']?['count'] ?? 0}',
                      subtitle: '₹${_fmt(stats['today_orders']?['amount'])}',
                      icon: Icons.shopping_cart,
                      color: AppTheme.success,
                    ),
                    StatCard(
                      title: 'Month Sales',
                      value: '₹${_fmt(stats['month_sales'])}',
                      subtitle: '',
                      icon: Icons.trending_up,
                      color: Colors.orange,
                    ),
                    StatCard(
                      title: 'Collection',
                      value: '₹${_fmt(stats['month_collection'])}',
                      subtitle: '',
                      icon: Icons.payments_outlined,
                      color: Colors.teal,
                    ),
                    StatCard(
                      title: 'Pending Tasks',
                      value: '${stats['pending_tasks'] ?? 0}',
                      subtitle: '',
                      icon: Icons.task_alt,
                      color: AppTheme.warning,
                    ),
                    StatCard(
                      title: 'Low Stock',
                      value: '${stats['low_stock_products'] ?? 0}',
                      subtitle: 'products',
                      icon: Icons.inventory_2_outlined,
                      color: AppTheme.error,
                    ),
                  ]),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                ),
              ),

              // Recent Orders
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text('Recent Orders', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),

              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final o = recentOrders[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(o['status']).withOpacity(0.15),
                          child: Icon(Icons.receipt_long, color: _statusColor(o['status'])),
                        ),
                        title: Text(o['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${o['customer_name']} • ${o['officer_name']}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${_fmt(o['total_amount'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _statusColor(o['status']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                o['status'] ?? '',
                                style: TextStyle(fontSize: 11, color: _statusColor(o['status'])),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: recentOrders.length,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic val) {
    if (val == null) return '0';
    final n = double.tryParse(val.toString()) ?? 0;
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'delivered': return AppTheme.success;
      case 'pending': return AppTheme.warning;
      case 'cancelled': return AppTheme.error;
      case 'confirmed': return AppTheme.primary;
      default: return Colors.grey;
    }
  }
}
