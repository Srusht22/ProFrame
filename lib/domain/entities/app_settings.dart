import '../pricing/currency.dart';
import '../pricing/pricing_rules.dart';

class CompanyProfile {
  final String name;
  final String? logoBase64;
  final String address;
  final String phone;
  final String email;
  final String website;
  final String taxRegistrationNumber;
  final String quotationFooter;
  final String defaultTermsAndConditions;

  const CompanyProfile({
    this.name = 'ProFrame Manufacturing',
    this.logoBase64,
    this.address = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.taxRegistrationNumber = '',
    this.quotationFooter = 'Thank you for your business.',
    this.defaultTermsAndConditions =
        '1. Prices are valid until the expiry date shown above.\n'
        '2. A 50% deposit is required to confirm production.\n'
        '3. Lead time begins after deposit and final measurement confirmation.\n'
        '4. Colors/finishes may vary slightly from screen previews.',
  });

  CompanyProfile copyWith({
    String? name,
    String? logoBase64,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? taxRegistrationNumber,
    String? quotationFooter,
    String? defaultTermsAndConditions,
  }) {
    return CompanyProfile(
      name: name ?? this.name,
      logoBase64: logoBase64 ?? this.logoBase64,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      taxRegistrationNumber: taxRegistrationNumber ?? this.taxRegistrationNumber,
      quotationFooter: quotationFooter ?? this.quotationFooter,
      defaultTermsAndConditions: defaultTermsAndConditions ?? this.defaultTermsAndConditions,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'logoBase64': logoBase64,
        'address': address,
        'phone': phone,
        'email': email,
        'website': website,
        'taxRegistrationNumber': taxRegistrationNumber,
        'quotationFooter': quotationFooter,
        'defaultTermsAndConditions': defaultTermsAndConditions,
      };

  factory CompanyProfile.fromJson(Map<String, dynamic> json) => CompanyProfile(
        name: json['name'] as String? ?? 'ProFrame Manufacturing',
        logoBase64: json['logoBase64'] as String?,
        address: json['address'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        website: json['website'] as String? ?? '',
        taxRegistrationNumber: json['taxRegistrationNumber'] as String? ?? '',
        quotationFooter: json['quotationFooter'] as String? ?? '',
        defaultTermsAndConditions: json['defaultTermsAndConditions'] as String? ?? '',
      );
}

enum AppThemeMode { light, dark, system }

enum AppLocale {
  en('en', 'English'),
  ar('ar', 'العربية'),
  ckb('ckb', 'کوردی');

  final String code;
  final String label;
  const AppLocale(this.code, this.label);

  bool get isRtl => this == ar || this == ckb;
}

/// The whole configurable side of the app in one aggregate: company
/// identity (feeds every quotation/PDF), locale/theme, numbering schemes
/// and — via [pricingRules] — the admin-editable pricing table.
class AppSettings {
  final CompanyProfile company;
  final PricingRules pricingRules;
  final AppCurrency currency;
  final AppThemeMode themeMode;
  final AppLocale locale;
  final String quoteNumberPrefix;
  final String orderNumberPrefix;
  final String projectNumberPrefix;
  final int quoteValidityDays;

  const AppSettings({
    this.company = const CompanyProfile(),
    this.pricingRules = const PricingRules(),
    this.currency = AppCurrency.usd,
    this.themeMode = AppThemeMode.light,
    this.locale = AppLocale.en,
    this.quoteNumberPrefix = 'Q',
    this.orderNumberPrefix = 'ORD',
    this.projectNumberPrefix = 'PRJ',
    this.quoteValidityDays = 30,
  });

  AppSettings copyWith({
    CompanyProfile? company,
    PricingRules? pricingRules,
    AppCurrency? currency,
    AppThemeMode? themeMode,
    AppLocale? locale,
    String? quoteNumberPrefix,
    String? orderNumberPrefix,
    String? projectNumberPrefix,
    int? quoteValidityDays,
  }) {
    return AppSettings(
      company: company ?? this.company,
      pricingRules: pricingRules ?? this.pricingRules,
      currency: currency ?? this.currency,
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      quoteNumberPrefix: quoteNumberPrefix ?? this.quoteNumberPrefix,
      orderNumberPrefix: orderNumberPrefix ?? this.orderNumberPrefix,
      projectNumberPrefix: projectNumberPrefix ?? this.projectNumberPrefix,
      quoteValidityDays: quoteValidityDays ?? this.quoteValidityDays,
    );
  }

  Map<String, dynamic> toJson() => {
        'company': company.toJson(),
        'pricingRules': pricingRules.toJson(),
        'currency': currency.toJson(),
        'themeMode': themeMode.name,
        'locale': locale.name,
        'quoteNumberPrefix': quoteNumberPrefix,
        'orderNumberPrefix': orderNumberPrefix,
        'projectNumberPrefix': projectNumberPrefix,
        'quoteValidityDays': quoteValidityDays,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        company: json['company'] != null
            ? CompanyProfile.fromJson(Map<String, dynamic>.from(json['company'] as Map))
            : const CompanyProfile(),
        pricingRules: json['pricingRules'] != null
            ? PricingRules.fromJson(Map<String, dynamic>.from(json['pricingRules'] as Map))
            : const PricingRules(),
        currency: json['currency'] != null
            ? AppCurrency.fromJson(Map<String, dynamic>.from(json['currency'] as Map))
            : AppCurrency.usd,
        themeMode: AppThemeMode.values.firstWhere(
          (e) => e.name == json['themeMode'],
          orElse: () => AppThemeMode.light,
        ),
        locale: AppLocale.values.firstWhere(
          (e) => e.name == json['locale'],
          orElse: () => AppLocale.en,
        ),
        quoteNumberPrefix: json['quoteNumberPrefix'] as String? ?? 'Q',
        orderNumberPrefix: json['orderNumberPrefix'] as String? ?? 'ORD',
        projectNumberPrefix: json['projectNumberPrefix'] as String? ?? 'PRJ',
        quoteValidityDays: (json['quoteValidityDays'] as num?)?.toInt() ?? 30,
      );
}
