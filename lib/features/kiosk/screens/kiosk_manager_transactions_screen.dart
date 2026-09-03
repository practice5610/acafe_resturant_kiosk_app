import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_search_field.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

/// Every order for the device's WHOLE branch today (every channel, not just
/// this device) -- reconciles against the branch-wide Sales Overview / Z
/// Report, matching how that report scopes at the branch level.
class KioskManagerTransactionsScreen extends StatefulWidget {
  const KioskManagerTransactionsScreen({super.key});

  @override
  State<KioskManagerTransactionsScreen> createState() =>
      _KioskManagerTransactionsScreenState();
}

class _KioskManagerTransactionsScreenState
    extends State<KioskManagerTransactionsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  /// Each keystroke would otherwise be a branch-wide query. Long enough that
  /// typing a receipt number fires once, short enough to feel immediate.
  static const Duration _debounce = Duration(milliseconds: 350);
  Timer? _debounceTimer;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The provider is a lazy singleton, so an earlier visit's query can
      // outlive the screen -- entering always starts from an empty search to
      // match the empty field.
      context.read<KioskManagerProvider>().loadTransactions(search: '');
    });
    _searchController.addListener(_onQueryChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final next = _searchController.text.trim();
    if (next == _query) return;
    setState(() => _query = next);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (!mounted) return;
      context.read<KioskManagerProvider>().searchTransactions(next);
      // A new result set starts at the top, so an old scroll offset would
      // otherwise immediately trigger the next-page fetch.
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocus.requestFocus();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      final provider = context.read<KioskManagerProvider>();
      if (!provider.transactionsLoading && provider.hasMoreTransactions) {
        provider.loadTransactions(reset: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double s = KioskLayout.scaleOf(context, constraints);
            return KioskCenteredContent(
              child: Column(
                children: [
                  Consumer<KioskManagerProvider>(
                    builder: (context, provider, _) {
                      return KioskHeaderBar(
                        s: s,
                        title: 'TRANSACTIONS',
                        fallback: RouterHelper.getKioskManagerDashboardRoute,
                        trailing: _CountChip(
                          s: s,
                          value: '${provider.transactionsTotal}',
                          label: _query.isEmpty ? 'orders' : 'matches',
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(132 * s, 0, 132 * s, 40 * s),
                    child: KioskSearchField(
                      s: s,
                      height: 92 * s,
                      controller: _searchController,
                      focusNode: _searchFocus,
                      hasQuery: _query.isNotEmpty,
                      onClear: _clearSearch,
                      hintText: 'Search order # or payment method',
                    ),
                  ),
                  Expanded(
                    child: Consumer<KioskManagerProvider>(
                      builder: (context, provider, _) {
                        if (provider.transactionsLoading &&
                            provider.transactions.isEmpty) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (provider.transactions.isEmpty) {
                          return Center(
                            child: Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 132 * s),
                              child: Text(
                                _query.isEmpty
                                    ? 'No orders yet today'
                                    : 'No order today matches \u201C$_query\u201D',
                                textAlign: TextAlign.center,
                                style: loewMedium.copyWith(fontSize: 44 * s),
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          controller: _scrollController,
                          padding:
                              EdgeInsets.fromLTRB(132 * s, 0, 132 * s, 60 * s),
                          itemCount: provider.transactions.length +
                              (provider.hasMoreTransactions ? 1 : 0),
                          separatorBuilder: (_, __) => SizedBox(height: 16 * s),
                          itemBuilder: (context, index) {
                            if (index >= provider.transactions.length) {
                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 40 * s),
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              );
                            }
                            return _TransactionRow(
                                s: s, order: provider.transactions[index]);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Result count beside the title -- with search on, it is the only signal
/// that the list has been narrowed and by how much.
class _CountChip extends StatelessWidget {
  final double s;
  final String value;
  final String label;

  const _CountChip({required this.s, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 12 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30 * s),
        border:
            Border.all(color: kKioskHairline, width: kioskStroke(1.5, s)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style:
                  loewExtraBold.copyWith(fontSize: 28 * s, color: KioskUI.dark)),
          SizedBox(width: 8 * s),
          Text(label,
              style: loewMedium.copyWith(
                  fontSize: 24 * s, color: kKioskMutedFg)),
        ],
      ),
    );
  }
}

const Map<String, String> _kChannelLabels = {
  'counter_pos': 'Counter/POS',
  'kiosk': 'Kiosk',
  'web_app': 'Web/App',
};

const Map<String, Color> _kChannelColors = {
  'counter_pos': Color(0xFFB8860B),
  'kiosk': Color(0xFF2E6DA4),
  'web_app': Color(0xFF2E7D32),
};

class _TransactionRow extends StatelessWidget {
  final double s;
  final Map<String, dynamic> order;
  const _TransactionRow({required this.s, required this.order});

  @override
  Widget build(BuildContext context) {
    final String channelKey = order['channel_key']?.toString() ?? 'web_app';
    final String channelLabel = _kChannelLabels[channelKey] ?? channelKey;
    final Color channelColor = _kChannelColors[channelKey] ?? Colors.black54;

    String time = '';
    final createdAt = order['created_at'];
    if (createdAt != null) {
      final parsed = DateTime.tryParse(createdAt.toString());
      if (parsed != null) time = DateFormat('hh:mm a').format(parsed.toLocal());
    }

    return Container(
      padding: EdgeInsets.all(28 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        border: Border.all(color: Colors.black12, width: 1.5 * s),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 220 * s,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${order['id']}',
                    style: loewBold.copyWith(
                        fontSize: 32 * s, color: Colors.black)),
                SizedBox(height: 4 * s),
                Text(time,
                    style: loewRegular.copyWith(
                        fontSize: 26 * s, color: Colors.black54)),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 8 * s),
            decoration: BoxDecoration(
              color: channelColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30 * s),
            ),
            child: Text(channelLabel,
                style:
                    loewBold.copyWith(fontSize: 24 * s, color: channelColor)),
          ),
          SizedBox(width: 20 * s),
          Expanded(
            child: Text(
              '${order['item_count'] ?? 0} items · ${order['payment_method'] ?? '-'}',
              style:
                  loewRegular.copyWith(fontSize: 28 * s, color: Colors.black87),
            ),
          ),
          Text(
            PriceConverterHelper.convertPrice(
                (order['order_amount'] as num?)?.toDouble()),
            style:
                loewExtraBold.copyWith(fontSize: 32 * s, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
