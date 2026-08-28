import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal_repo.dart';

class KioskDealProvider extends ChangeNotifier {
  KioskDealProvider({required this.dealRepo});

  final KioskDealRepo dealRepo;

  List<KioskDeal> _deals = [];
  bool _loading = false;

  List<KioskDeal> get deals => _deals;
  bool get loading => _loading;
  bool get hasDeals => _deals.isNotEmpty;

  KioskDeal? dealById(int id) {
    for (final deal in _deals) {
      if (deal.id == id) return deal;
    }
    return null;
  }

  Future<void> loadCached() async {
    final raw = dealRepo.readCache();
    if (raw == null || raw.isEmpty) return;
    try {
      _deals = _parseList(jsonDecode(raw));
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> fetchDeals() async {
    _loading = true;
    notifyListeners();
    final ApiResponseModel response = await dealRepo.getDeals();
    _loading = false;
    if (!response.isSuccess || response.response?.data == null) {
      notifyListeners();
      return false;
    }
    try {
      final data = response.response!.data;
      _deals = _parseList(data is Map ? data['deals'] : data);
      await dealRepo.writeCache(jsonEncode(_deals.map((d) => d.toJson()).toList()));
      notifyListeners();
      return true;
    } catch (_) {
      notifyListeners();
      return false;
    }
  }

  Future<KioskDeal?> fetchDeal(int id) async {
    final ApiResponseModel response = await dealRepo.getDeal(id);
    if (!response.isSuccess || response.response?.data == null) {
      return dealById(id);
    }
    try {
      final data = response.response!.data;
      if (data is! Map) return dealById(id);
      final deal = KioskDeal.fromJson(Map<String, dynamic>.from(data));
      final int index = _deals.indexWhere((d) => d.id == deal.id);
      if (index >= 0) {
        _deals[index] = deal;
      } else {
        _deals.add(deal);
      }
      notifyListeners();
      return deal;
    } catch (_) {
      return dealById(id);
    }
  }

  void applyRealtimeRemove(int dealId) {
    final remaining = _deals.where((d) => d.id != dealId).toList();
    if (remaining.length == _deals.length) {
      return;
    }
    _deals = remaining;
    dealRepo.writeCache(jsonEncode(_deals.map((d) => d.toJson()).toList()));
    notifyListeners();
  }

  List<KioskDeal> _parseList(dynamic raw) {
    if (raw is! List) return [];
    final List<KioskDeal> out = [];
    for (final item in raw) {
      try {
        final KioskDeal deal;
        if (item is Map<String, dynamic>) {
          deal = KioskDeal.fromJson(item);
        } else if (item is Map) {
          deal = KioskDeal.fromJson(Map<String, dynamic>.from(item));
        } else {
          continue;
        }
        // A deal with zero parseable items cannot be ordered — skip it so the
        // banner never opens a broken detail screen.
        if (deal.items.isEmpty) {
          debugPrint('KioskDealProvider: skipping deal ${deal.id} (no items)');
          continue;
        }
        out.add(deal);
      } catch (e) {
        debugPrint('KioskDealProvider: skipping corrupt deal ($e)');
      }
    }
    return out;
  }
}
