import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _statusFilter;

  final List<String> _statuses = ['all', 'pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getOrders(status: _statusFilter == 'all' ? null : _statusFilter);
      setState(() { _orders = List<Map<String, dynamic>>.from(data['orders'] ?? []); _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilter),
        ],
      ),
      body: Column(
        children: [
          // Status filter chips
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _statuses.length,
              itemBuilder: (ctx, i) {
                final s = _statuses[i];
                final selected = (_statusFilter ?? 'all') == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s[0].toUpperCase() + s.substring(1)),
                    selected: selected,
                    onSelected: (_) { setState(() => _statusFilter = s == 'all' ? null : s); _load(); },
                    selectedColor: AppTheme.primary.withOpacity(0.2),
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? const Center(child: Text('No orders found'))
                    : ListView.builder(
                        itemCount: _orders.length,
                        itemBuilder: (ctx, i) {
                          final o = _orders[i];
                          return Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o['id']))),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(o['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const Spacer(),
                                        _statusBadge(o['status']),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(o['customer_name'] ?? '', style: const TextStyle(color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(o['officer_name'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        const Spacer(),
                                        Text('₹${o['total_amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOrderScreen())).then((_) => _load()),
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
      ),
    );
  }

  Widget _statusBadge(String? status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(status ?? '', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'delivered': return AppTheme.success;
      case 'pending': return AppTheme.warning;
      case 'cancelled': return AppTheme.error;
      case 'confirmed': return AppTheme.primary;
      default: return Colors.grey;
    }
  }

  void _showFilter() {}
}

// ─── ORDER DETAIL ────────────────────────────────────────────────────────────

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getOrder(widget.orderId);
      setState(() { _order = data['order']; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_order?['order_number'] ?? 'Order')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? const Center(child: Text('Order not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _section('Customer', [
                      _row('Name', _order!['customer_name']),
                      _row('Phone', _order!['customer_phone']),
                      _row('Address', _order!['customer_address']),
                    ]),
                    _section('Order Info', [
                      _row('Status', _order!['status']),
                      _row('Payment', _order!['payment_status']),
                      _row('Method', _order!['payment_method']),
                      _row('Officer', _order!['officer_name']),
                    ]),
                    _section('Items', [
                      ...List<Map<String, dynamic>>.from(_order!['items'] ?? []).map((item) =>
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text('${item['product_name']} x${item['quantity']} ${item['unit']}')),
                              Text('₹${item['line_total']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      _row('Subtotal', '₹${_order!['subtotal']}'),
                      _row('Tax', '₹${_order!['tax_amount']}'),
                      _row('Discount', '₹${_order!['discount_amount']}'),
                      _row('Total', '₹${_order!['total_amount']}', bold: true),
                    ]),
                  ],
                ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, dynamic value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(child: Text(value?.toString() ?? '-', style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }
}

// ─── CREATE ORDER ────────────────────────────────────────────────────────────

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic>? _selectedCustomer;
  List<Map<String, dynamic>> _cartItems = [];
  bool _loading = false;
  String _notes = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final [c, p] = await Future.wait([ApiService.getCustomers(), ApiService.getProducts()]);
    setState(() {
      _customers = List<Map<String, dynamic>>.from(c['customers'] ?? []);
      _products = List<Map<String, dynamic>>.from(p['products'] ?? []);
    });
  }

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      final idx = _cartItems.indexWhere((i) => i['product_id'] == product['id']);
      if (idx >= 0) {
        _cartItems[idx]['quantity']++;
      } else {
        _cartItems.add({'product_id': product['id'], 'name': product['name'], 'unit_price': product['price'], 'quantity': 1, 'unit': product['unit']});
      }
    });
  }

  double get _total => _cartItems.fold(0, (s, i) => s + i['unit_price'] * i['quantity']);

  Future<void> _placeOrder() async {
    if (_selectedCustomer == null || _cartItems.isEmpty) return;
    setState(() => _loading = true);
    try {
      await ApiService.createOrder({
        'customer_id': _selectedCustomer!['id'],
        'items': _cartItems,
        'notes': _notes,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully!'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Order')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Customer picker
                DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: const InputDecoration(labelText: 'Select Customer', prefixIcon: Icon(Icons.person_outline)),
                  value: _selectedCustomer,
                  items: _customers.map((c) => DropdownMenuItem(value: c, child: Text(c['name']))).toList(),
                  onChanged: (v) => setState(() => _selectedCustomer = v),
                ),
                const SizedBox(height: 16),

                // Products
                const Text('Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                ..._products.map((p) {
                  final inCart = _cartItems.firstWhere((i) => i['product_id'] == p['id'], orElse: () => {});
                  final qty = inCart['quantity'] ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(p['name']),
                      subtitle: Text('₹${p['price']} / ${p['unit']}'),
                      trailing: qty == 0
                          ? IconButton(icon: const Icon(Icons.add_circle, color: AppTheme.primary, size: 32), onPressed: () => _addToCart(p))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () {
                                  setState(() { if (qty == 1) _cartItems.removeWhere((i) => i['product_id'] == p['id']); else inCart['quantity']--; });
                                }),
                                Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () { setState(() => inCart['quantity']++); }),
                              ],
                            ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Bottom order summary
          if (_cartItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('${_cartItems.length} items', style: const TextStyle(color: Colors.grey)),
                      const Spacer(),
                      Text('Total: ₹${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _placeOrder,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Place Order'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
