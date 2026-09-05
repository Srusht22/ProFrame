import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../domain/configuration/configuration_options.dart';
import '../../../../domain/products/product_registry.dart';
import '../../wizard/presentation/quick_wizard_screen.dart';
import 'widgets/create_product_type_dialog.dart';

class ProductSelectScreen extends StatefulWidget {
  const ProductSelectScreen({super.key});

  @override
  State<ProductSelectScreen> createState() => _ProductSelectScreenState();
}

class _ProductSelectScreenState extends State<ProductSelectScreen> {
  void _openCreateTypeDialog() async {
    final result = await showDialog<ProductType>(
      context: context,
      builder: (_) => const CreateProductTypeDialog(),
    );

    if (result != null && mounted) {
      setState(() {});
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuickWizardScreen(productType: result),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ProductRegistry.getAll();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Product Catalog'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                backgroundColor: AppTheme.primary.withOpacity(0.12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _openCreateTypeDialog,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('New Type', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What are you making?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Select a product or add a custom type to start designing.',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _openCreateTypeDialog,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add Type', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              ...products.map((prod) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QuickWizardScreen(productType: prod.type),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTheme.surfaceBorder,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: prod.type.isCustom
                                  ? Center(
                                      child: Text(
                                        prod.type.icon,
                                        style: const TextStyle(fontSize: 28),
                                      ),
                                    )
                                  : Icon(
                                      prod.icon,
                                      size: 30,
                                      color: AppTheme.primary,
                                    ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        prod.title,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      if (prod.type.isCustom) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Custom',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    prod.description,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: AppTheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
