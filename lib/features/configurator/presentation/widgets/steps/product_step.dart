import 'package:flutter/material.dart';
import '../../../../../domain/configuration/config_enums.dart';
import '../../../../../domain/configuration/dimension_limits.dart';
import '../../../../../domain/configuration/product_configuration.dart';
import '../option_card.dart';
import '../step_scaffold.dart';

class ProductStep extends StatelessWidget {
  final ProductConfiguration config;
  final ValueChanged<ProductConfiguration> onChanged;

  const ProductStep({super.key, required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      title: 'Product type',
      helperText: 'Choose what you are configuring — the rest of the wizard adapts to this choice.',
      children: [
        FieldGroup(
          label: 'Category',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final category in ProductCategory.values)
                OptionCard(
                  icon: category.icon,
                  label: category.label,
                  selected: config.category == category,
                  onTap: () {
                    if (config.category == category) return;
                    onChanged(ProductConfiguration.newDraft(
                      name: config.name,
                      category: category,
                      projectId: config.projectId,
                      createdByUserId: config.createdByUserId,
                    ).copyWith(id: config.id, createdAt: config.createdAt));
                  },
                ),
            ],
          ),
        ),
        if (config.category == ProductCategory.door)
          FieldGroup(
            label: 'Door type',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final type in DoorType.values)
                  OptionCard(
                    icon: Icons.door_front_door_outlined,
                    label: type.label,
                    subtitle: type.description,
                    selected: config.doorType == type,
                    onTap: () {
                      final limits = ProductLimits.forDoor(type);
                      onChanged(config.copyWith(
                        doorType: type,
                        widthMm: limits.width.defaultMm,
                        heightMm: limits.height.defaultMm,
                        wallOpeningWidthMm: limits.width.defaultMm + 20,
                        wallOpeningHeightMm: limits.height.defaultMm + 20,
                      ));
                    },
                  ),
              ],
            ),
          )
        else
          FieldGroup(
            label: 'Window type',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final type in WindowType.values)
                  OptionCard(
                    icon: Icons.window_outlined,
                    label: type.label,
                    subtitle: type.description,
                    selected: config.windowType == type,
                    onTap: () {
                      final limits = ProductLimits.forWindow(type);
                      onChanged(config.copyWith(
                        windowType: type,
                        widthMm: limits.width.defaultMm,
                        heightMm: limits.height.defaultMm,
                        wallOpeningWidthMm: limits.width.defaultMm + 20,
                        wallOpeningHeightMm: limits.height.defaultMm + 20,
                      ));
                    },
                  ),
              ],
            ),
          ),
        FieldGroup(
          label: 'Reference name',
          child: TextFormField(
            initialValue: config.name,
            decoration: const InputDecoration(hintText: 'e.g. Living Room Sliding Window'),
            onChanged: (v) => onChanged(config.copyWith(name: v)),
          ),
        ),
        FieldGroup(
          label: 'Quantity',
          child: Row(
            children: [
              IconButton.outlined(
                onPressed: config.quantity > 1 ? () => onChanged(config.copyWith(quantity: config.quantity - 1)) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('${config.quantity}', style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton.outlined(
                onPressed: () => onChanged(config.copyWith(quantity: config.quantity + 1)),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
