import 'package:flutter/foundation.dart';

class CurrencyController extends ValueNotifier<String> {
  CurrencyController() : super(_defaultCurrency());

  static String _defaultCurrency() {
    final country = PlatformDispatcher.instance.locale.countryCode;
    return country == 'CA' ? 'CAD' : 'USD';
  }

  String get symbol => value == 'CAD' ? r'$' : r'$';

  String format(double? amount, {String fallback = '—'}) {
    if (amount == null) return fallback;
    return '$symbol${amount.toStringAsFixed(2)} $value';
  }

  void setCurrency(String currency) {
    if (currency != 'CAD' && currency != 'USD') return;
    value = currency;
  }
}
