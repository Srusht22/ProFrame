import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/accounts/accounts.dart';
import '../../../domain/model/design.dart';
import '../../../domain/text/names.dart';
import '../../l10n/l10n.dart';
import '../../state/cloud.dart';
import '../../state/workspace.dart';
import '../../theme/app_theme.dart';
import '../designs_screen.dart';
import '../workspace_screen.dart';
import 'account_ui.dart';
import 'approvals_screen.dart';
import 'cloud_header.dart';

/// A worker's home: the designs assigned to them and what they have asked
/// for. Nothing else of the factory's is here — no customer list, no
/// prices, no other worker — because the backend gives a worker nothing
/// else.
class LabourHomeScreen extends ConsumerWidget {
  const LabourHomeScreen({super.key});

  static const newDesignKey = ValueKey('labour-new-design');
  static const newCustomerKey = ValueKey('labour-new-customer');
  static const noDesignsKey = ValueKey('labour-no-designs');
  static ValueKey<String> openKey(String id) => ValueKey('labour-open-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final account = ref.watch(sessionProvider).value;
    final designs = ref.watch(myDesignsProvider);
    final requests = ref.watch(requestsProvider);
    final palette = context.palette;
    return AccountScaffold(
      title: account?.factoryName ?? l.appTitle,
      actions: [
        IconButton(
          tooltip: l.clRefresh,
          onPressed: () => ref.read(cloudRevisionProvider.notifier).changed(),
          icon: Icon(Icons.refresh, color: palette.onBand),
        ),
        NotificationsButton(colour: palette.onBand),
        CloudAccountButton(colour: palette.onBand),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.clHello(account?.name ?? ''),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(l.clLabourLead, style: TextStyle(color: palette.muted)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: newDesignKey,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NewDesignRequestScreen(),
                  ),
                ),
                icon: const Icon(Icons.note_add_outlined),
                label: Text(l.clAskNewDesign),
              ),
              OutlinedButton.icon(
                key: newCustomerKey,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NewCustomerRequestScreen(),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt),
                label: Text(l.clAskNewCustomer),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l.clMyDesigns, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          designs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FormProblem(problemOf(context, e)),
            data: (all) => all.isEmpty
                ? Text(l.clNoAssignedDesigns, key: noDesignsKey)
                : Column(
                    children: [for (final d in all) _AssignedCard(design: d)],
                  ),
          ),
          const SizedBox(height: 24),
          Text(l.clMyRequests, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          requests.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FormProblem(problemOf(context, e)),
            data: (all) => all.isEmpty
                ? Text(l.clNoRequests)
                : Column(
                    children: [for (final r in all) RequestTile(request: r)],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AssignedCard extends ConsumerWidget {
  final AssignedDesign design;
  const _AssignedCard({required this.design});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = design;
    return Card(
      child: ListTile(
        leading: Icon(kindIcon(d.kind)),
        title: Text(d.name),
        subtitle: Text('${d.customerName} · ${d.kind.labelIn(context.words)}'),
        trailing: FilledButton.tonal(
          key: LabourHomeScreen.openKey(d.id),
          onPressed: () => openAssigned(context, ref, d.id),
          child: Text(l.clOpen),
        ),
      ),
    );
  }
}

/// Opens an assigned design as the backend has it now — asked for again by
/// its id, so a design taken away since is refused — to look at, and to
/// propose a change to. Nothing about it is kept on the device.
Future<void> openAssigned(
  BuildContext context,
  WidgetRef ref,
  String designId,
) async {
  try {
    final assigned = await ref.read(backendProvider)!.assignedDesign(designId);
    final design = Design.fromJson(assigned.data);
    ref
        .read(proposalProvider.notifier)
        .viewing(designId, assigned.revision, original: design);
    ref.read(workspaceProvider.notifier).openDesign(design);
    if (!context.mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const WorkspaceScreen()));
  } on Object catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problemOf(context, e))));
    }
  } finally {
    ref.read(proposalProvider.notifier).end();
  }
}

/// The five categories a design is begun as, as chips to choose one of.
class CategoryChoice extends StatelessWidget {
  final DesignKind? value;
  final ValueChanged<DesignKind> onChanged;
  const CategoryChoice({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static ValueKey<String> chipKey(DesignKind k) =>
      ValueKey('category-${k.name}');

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final k in DesignKind.categories)
        ChoiceChip(
          key: chipKey(k),
          avatar: Icon(kindIcon(k), size: 18),
          label: Text(k.labelIn(context.words)),
          selected: value == k,
          onSelected: (_) => onChanged(k),
        ),
    ],
  );
}

/// Asking for a new design for a customer the worker already works for.
/// It makes a request; the owner makes the design, if they approve.
class NewDesignRequestScreen extends ConsumerStatefulWidget {
  const NewDesignRequestScreen({super.key});

  static const customerKey = ValueKey('request-customer');
  static const nameKey = ValueKey('request-design-name');
  static const descriptionKey = ValueKey('request-description');
  static const submitKey = ValueKey('request-submit');
  static const noCustomersKey = ValueKey('request-no-customers');

  @override
  ConsumerState<NewDesignRequestScreen> createState() =>
      _NewDesignRequestState();
}

class _NewDesignRequestState extends ConsumerState<NewDesignRequestScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _key = newClientKey();
  String? _customer;
  DesignKind? _kind;
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final problem = _customer == null
        ? l.clChooseCustomer
        : _name.text.trim().isEmpty
        ? l.clDesignNameNeeded
        : _kind == null
        ? l.clChooseCategory
        : null;
    setState(() => _problem = problem);
    if (problem != null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(backendProvider)!
          .requestNewDesign(
            customerId: _customer!,
            name: _name.text.trim(),
            category: _kind!.name,
            description: _description.text.trim(),
            clientKey: _key,
          );
      ref.read(cloudRevisionProvider.notifier).changed();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.clRequestSent)));
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) setState(() => _problem = problemOf(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final customers = ref.watch(myCustomersProvider);
    return AccountScaffold(
      title: l.clAskNewDesign,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeading(heading: l.clAskNewDesign, lead: l.clRequestLead),
          FormCard(
            children: [
              customers.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => FormProblem(problemOf(context, e)),
                data: (all) => all.isEmpty
                    ? Text(
                        l.clNoScopedCustomers,
                        key: NewDesignRequestScreen.noCustomersKey,
                      )
                    : DropdownButtonFormField<String>(
                        key: NewDesignRequestScreen.customerKey,
                        initialValue: _customer,
                        decoration: InputDecoration(labelText: l.clCustomer),
                        items: [
                          for (final c in all)
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                        ],
                        onChanged: (v) => setState(() => _customer = v),
                      ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: NewDesignRequestScreen.nameKey,
                controller: _name,
                decoration: InputDecoration(labelText: l.clDesignName),
              ),
              const SizedBox(height: 12),
              Text(l.clCategory),
              const SizedBox(height: 6),
              CategoryChoice(
                value: _kind,
                onChanged: (k) => setState(() => _kind = k),
              ),
              const SizedBox(height: 12),
              TextField(
                key: NewDesignRequestScreen.descriptionKey,
                controller: _description,
                maxLines: 3,
                decoration: InputDecoration(labelText: l.clDescription),
              ),
              FormProblem(_problem),
              const SizedBox(height: 16),
              BusyButton(
                key: NewDesignRequestScreen.submitKey,
                label: l.clSendRequest,
                busy: _busy,
                icon: Icons.send,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asking for a new customer and their first design: the customer's own
/// details, as the customer form asks them. Nothing is made until the
/// owner approves.
class NewCustomerRequestScreen extends ConsumerStatefulWidget {
  const NewCustomerRequestScreen({super.key});

  static const customerNameKey = ValueKey('request-customer-name');
  static const phoneKey = ValueKey('request-customer-phone');
  static const submitKey = ValueKey('request-customer-submit');

  @override
  ConsumerState<NewCustomerRequestScreen> createState() =>
      _NewCustomerRequestState();
}

class _NewCustomerRequestState extends ConsumerState<NewCustomerRequestScreen> {
  final _customer = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _key = newClientKey();
  DesignKind? _kind;
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    for (final c in [
      _customer,
      _phone,
      _address,
      _notes,
      _name,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final problem = _customer.text.trim().isEmpty
        ? l.clCustomerNameNeeded
        : _name.text.trim().isEmpty
        ? l.clDesignNameNeeded
        : _kind == null
        ? l.clChooseCategory
        : null;
    setState(() => _problem = problem);
    if (problem != null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(backendProvider)!
          .requestNewCustomer(
            customer: {
              'name': _customer.text.trim(),
              'phone': _phone.text.trim(),
              'address': _address.text.trim(),
              'notes': _notes.text.trim(),
            },
            name: _name.text.trim(),
            category: _kind!.name,
            description: _description.text.trim(),
            clientKey: _key,
          );
      ref.read(cloudRevisionProvider.notifier).changed();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.clRequestSent)));
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) setState(() => _problem = problemOf(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AccountScaffold(
      title: l.clAskNewCustomer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeading(heading: l.clAskNewCustomer, lead: l.clRequestLead),
          FormCard(
            children: [
              TextField(
                key: NewCustomerRequestScreen.customerNameKey,
                controller: _customer,
                decoration: InputDecoration(labelText: l.clCustomerName),
              ),
              const SizedBox(height: 12),
              TextField(
                key: NewCustomerRequestScreen.phoneKey,
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l.clPhone),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _address,
                decoration: InputDecoration(labelText: l.clAddress),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: InputDecoration(labelText: l.clNotes),
              ),
              const Divider(height: 32),
              TextField(
                key: NewDesignRequestScreen.nameKey,
                controller: _name,
                decoration: InputDecoration(labelText: l.clDesignName),
              ),
              const SizedBox(height: 12),
              Text(l.clCategory),
              const SizedBox(height: 6),
              CategoryChoice(
                value: _kind,
                onChanged: (k) => setState(() => _kind = k),
              ),
              const SizedBox(height: 12),
              TextField(
                key: NewDesignRequestScreen.descriptionKey,
                controller: _description,
                maxLines: 3,
                decoration: InputDecoration(labelText: l.clDescription),
              ),
              FormProblem(_problem),
              const SizedBox(height: 16),
              BusyButton(
                key: NewCustomerRequestScreen.submitKey,
                label: l.clSendRequest,
                busy: _busy,
                icon: Icons.send,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
