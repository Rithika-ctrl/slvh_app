import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slvh_app/features/inventory/services/stock_service.dart';
import 'package:slvh_app/features/orders/models/order_model.dart';

/// Stock service provider
final stockServiceProvider = Provider((ref) => StockService());

/// Reserve stock for order creation
final reserveStockProvider = FutureProvider.family<Map<String, int>, List<OrderItem>>(
  (ref, items) async {
    final stockService = ref.read(stockServiceProvider);
    return stockService.reserveStock(items);
  },
);

/// Validate stock without reserving (for UI feedback)
final validateStockProvider = FutureProvider.family<StockReservationException?, List<OrderItem>>(
  (ref, items) async {
    final stockService = ref.read(stockServiceProvider);
    return stockService.validateStock(items);
  },
);

/// Get current stock level for a product
final productStockProvider = FutureProvider.family<int, String>(
  (ref, productId) async {
    final stockService = ref.read(stockServiceProvider);
    return stockService.getProductStock(productId);
  },
);

/// Release stock (for order cancellation)
final releaseStockProvider = FutureProvider.family<int, (String, int)>(
  (ref, params) async {
    final stockService = ref.read(stockServiceProvider);
    return stockService.releaseStock(params.$1, params.$2);
  },
);
