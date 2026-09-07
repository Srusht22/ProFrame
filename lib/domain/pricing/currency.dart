/// A configurable currency — never hard-code a currency assumption in the
/// UI. [Settings] holds the active default; [exchangeRateToBase] lets
/// admins price everything in a base currency and display converted totals.
class AppCurrency {
  final String code; // ISO-ish code, e.g. USD, EUR, IQD
  final String symbol;
  final String label;
  final int decimalPrecision;
  final double exchangeRateToBase;

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.label,
    this.decimalPrecision = 2,
    this.exchangeRateToBase = 1.0,
  });

  static const usd = AppCurrency(code: 'USD', symbol: '\$', label: 'US Dollar');
  static const eur = AppCurrency(code: 'EUR', symbol: '€', label: 'Euro', exchangeRateToBase: 0.92);
  static const iqd = AppCurrency(
    code: 'IQD',
    symbol: 'د.ع',
    label: 'Iraqi Dinar',
    decimalPrecision: 0,
    exchangeRateToBase: 1310.0,
  );

  static const List<AppCurrency> builtIns = [usd, eur, iqd];

  String format(double amount) {
    final converted = amount * exchangeRateToBase;
    return '$symbol${converted.toStringAsFixed(decimalPrecision)}';
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'symbol': symbol,
        'label': label,
        'decimalPrecision': decimalPrecision,
        'exchangeRateToBase': exchangeRateToBase,
      };

  factory AppCurrency.fromJson(Map<String, dynamic> json) => AppCurrency(
        code: json['code'] as String? ?? 'USD',
        symbol: json['symbol'] as String? ?? '\$',
        label: json['label'] as String? ?? 'US Dollar',
        decimalPrecision: (json['decimalPrecision'] as num?)?.toInt() ?? 2,
        exchangeRateToBase: (json['exchangeRateToBase'] as num?)?.toDouble() ?? 1.0,
      );
}
