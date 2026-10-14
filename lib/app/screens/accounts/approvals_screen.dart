import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/accounts/accounts.dart';
import '../../../domain/dimensions/units.dart';
import '../../../domain/model/customer.dart';
import '../../../domain/model/design.dart';
import '../../../domain/model/new_design_setup.dart';
import '../../../domain/text/names.dart';
import '../../../infrastructure/cloud/backend.dart';
import '../../canvas/design_preview.dart';
import '../../l10n/l10n.dart';
import '../../state/cloud.dart';
import '../../state/workspace.dart';
import '../../theme/app_theme.dart';
import 'account_ui.dart';

/// The owner's approval center: what the workers have asked for, waiting,
/// approved and rejected. Only the factory's owner decides, and the backend
/// is what holds that.
class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  static const pendingTab = ValueKey('approvals-pending');
  static const approvedTab = ValueKey('approvals-approved');
  static const rejectedTab = ValueKey('approvals-rejected');
  static const emptyKey = ValueKey('approvals-empty');

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const OwnerOnly(child: _Approvals());
}

class _Approvals extends ConsumerWidget {
  const _Approvals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final all = ref.watch(requestsProvider);
    final pending = ref.watch(pendingCountProvider);
    Widget list(bool Function(WorkRequest) which) => all.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: FormProblem(problemOf(context, e)),
      ),
      data: (requests) {
        final shown = requests.where(which).toList();
        if (shown.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.clNoRequests, key: ApprovalsScreen.emptyKey),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [for (final r in shown) RequestTile(request: r)],
        );
      },
    );
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: context.palette.shell,
        appBar: AppBar(
          backgroundColor: context.palette.band,
          foregroundColor: context.palette.onBand,
          title: Text(l.clApprovals),
          bottom: TabBar(
            labelColor: context.palette.onBand,
            unselectedLabelColor: context.palette.onBand.withValues(alpha: 0.7),
            indicatorColor: context.palette.onBand,
            tabs: [
              Tab(
                key: ApprovalsScreen.pendingTab,
                text: l.clPendingTab(pending),
              ),
              Tab(key: ApprovalsScreen.approvedTab, text: l.clStatusApproved),
              Tab(key: ApprovalsScreen.rejectedTab, text: l.clStatusRejected),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            list((r) => r.status == RequestStatus.pending),
            list((r) => r.status == RequestStatus.approved),
            list(
              (r) =>
                  r.status != RequestStatus.pending &&
                  r.status != RequestStatus.approved,
            ),
          ],
        ),
      ),
    );
  }
}

/// One request in a list: what it is, who asked, for whom, when, and where
/// it is.
class RequestTile extends ConsumerWidget {
  final WorkRequest request;
  const RequestTile({super.key, required this.request});

  static ValueKey<String> tileKey(String id) => ValueKey('request-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final r = request;
    final who = ref.watch(accountNamesProvider).value?[r.requestedBy] ?? '';
    return Card(
      key: tileKey(r.id),
      child: ListTile(
        leading: Icon(switch (r.kind) {
          RequestKind.newDesign => Icons.note_add_outlined,
          RequestKind.newCustomerDesign => Icons.person_add_alt,
          RequestKind.designChange => Icons.edit_note,
        }),
        title: Text(
          '${requestKindIn(l, r.kind)} · ${r.designName}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [if (who.isNotEmpty) who, whenIn(l, r.createdAt)].join(' · '),
        ),
        trailing: StatusChip.request(context, r.status),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => RequestScreen(request: r)),
        ),
      ),
    );
  }
}

/// A request in full, for the owner to decide and for the worker who made
/// it to follow.
class RequestScreen extends ConsumerStatefulWidget {
  final WorkRequest request;
  const RequestScreen({super.key, required this.request});

  static const noteKey = ValueKey('request-note');
  static const approveKey = ValueKey('request-approve');
  static const rejectKey = ValueKey('request-reject');
  static const cancelKey = ValueKey('request-cancel');
  static const assignKey = ValueKey('request-assign');
  static const duplicateKey = ValueKey('request-duplicate');
  static const compareKey = ValueKey('request-compare');

  @override
  ConsumerState<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends ConsumerState<RequestScreen> {
  final _note = TextEditingController();
  bool _assign = false;
  bool _busy = false;
  String? _problem;
  late final WorkRequest _request = widget.request;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _owner => ref.read(sessionProvider).value?.isOwner ?? false;

  Future<void> _decide(Future<void> Function() action, String done) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await action();
      ref.read(cloudRevisionProvider.notifier).changed();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) setState(() => _problem = problemOf(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Makes what was asked for, through the application's own rules for a
  /// new design and a new customer, and has the backend keep it once.
  Future<void> _approve() async {
    final l = context.l10n;
    final backend = ref.read(backendProvider)!;
    final sync = ref.read(ownerSyncProvider);
    final r = _request;
    final note = _note.text.trim();
    await _decide(() async {
      // Anything the owner changed meanwhile is on the backend first.
      await sync?.push();
      switch (r.kind) {
        case RequestKind.newDesign:
          final customer = await ref
              .read(customerStoreProvider)
              .load(r.customerId ?? '');
          final design = _newDesign(r, customer?.id, customer?.name);
          await backend.approveNewDesign(
            r.id,
            design: design.toJson(),
            assign: _assign,
            note: note,
          );
        case RequestKind.newCustomerDesign:
          final asked = r.customerAsked;
          final customer = ref
              .read(customerStoreProvider)
              .fresh(
                name: '${asked['name'] ?? ''}',
                phone: '${asked['phone'] ?? ''}',
                address: '${asked['address'] ?? ''}',
                notes: '${asked['notes'] ?? ''}',
              );
          final design = _newDesign(r, customer.id, customer.name);
          await backend.approveNewCustomer(
            r.id,
            customer: customer.toJson(),
            design: design.toJson(),
            assign: _assign,
            note: note,
          );
        case RequestKind.designChange:
          final proposed = r.proposed;
          // The proposal must be a design this application can read.
          if (proposed == null) throw BackendError('invalid');
          Design.fromJson(proposed);
          final made = await backend.approveChange(r.id, note: note);
          await sync?.adoptDesign(r.designId!, made.data, made.revision);
      }
      await sync?.pull();
    }, l.clApprovedDone);
  }

  Design _newDesign(WorkRequest r, String? customerId, String? customer) {
    final kind = r.kindAsked;
    if (customerId == null || kind == null) {
      throw BackendError('customer_missing');
    }
    return NewDesignSetup(customerId: customerId, customer: customer)
        .withName(r.designName)
        .withKind(kind)
        .begin(id: 'design-${DateTime.now().microsecondsSinceEpoch}');
  }

  Future<void> _reject() async {
    final l = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.clRejectTitle),
        content: Text(l.clRejectBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l.actCancel),
          ),
          FilledButton(
            key: const ValueKey('reject-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l.clReject),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await _decide(
      () => ref
          .read(backendProvider)!
          .reject(_request.id, note: _note.text.trim()),
      l.clRejectedDone,
    );
  }

  Future<void> _cancel() => _decide(
    () => ref.read(backendProvider)!.cancelRequest(_request.id),
    context.l10n.clCancelledDone,
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = _request;
    final names = ref.watch(accountNamesProvider).value ?? const {};
    final pending = r.status == RequestStatus.pending;
    final asked = r.customerAsked;
    return AccountScaffold(
      title: requestKindIn(l, r.kind),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusChip.request(context, r.status),
          ),
          const SizedBox(height: 12),
          _Field(l.clRequestedBy, names[r.requestedBy] ?? ''),
          _Field(l.clRequestedOn, whenIn(l, r.createdAt)),
          if (r.kind == RequestKind.newCustomerDesign) ...[
            _Field(l.clCustomer, '${asked['name'] ?? ''}'),
            _Field(l.clPhone, '${asked['phone'] ?? ''}'),
            _Field(l.clAddress, '${asked['address'] ?? ''}'),
            _Field(l.clNotes, '${asked['notes'] ?? ''}'),
          ] else
            _CustomerName(customerId: r.customerId),
          _Field(l.clDesignName, r.designName),
          if (r.kindAsked case final kind?)
            _Field(l.clCategory, kind.labelIn(context.words)),
          _Field(l.clDescription, r.description),
          if (r.decidedAt != null) ...[
            _Field(l.clDecidedOn, whenIn(l, r.decidedAt)),
            _Field(l.clDecisionNote, r.decisionNote ?? ''),
          ],
          if (_owner && pending && r.kind == RequestKind.newCustomerDesign)
            _Duplicates(
              name: '${asked['name'] ?? ''}',
              phone: '${asked['phone'] ?? ''}',
            ),
          if (r.kind == RequestKind.designChange && _owner)
            _Compare(request: r),
          FormProblem(_problem),
          const SizedBox(height: 16),
          if (_owner && pending) ...[
            TextField(
              key: RequestScreen.noteKey,
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(labelText: l.clNoteForWorker),
            ),
            if (r.kind != RequestKind.designChange)
              CheckboxListTile(
                key: RequestScreen.assignKey,
                contentPadding: EdgeInsets.zero,
                value: _assign,
                onChanged: (v) => setState(() => _assign = v ?? false),
                title: Text(l.clGiveAccess(names[r.requestedBy] ?? '')),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: RequestScreen.rejectKey,
                    onPressed: _busy ? null : _reject,
                    child: Text(l.clReject),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BusyButton(
                    key: RequestScreen.approveKey,
                    label: l.clApprove,
                    busy: _busy,
                    icon: Icons.check,
                    onPressed: _approve,
                  ),
                ),
              ],
            ),
          ],
          if (!_owner && pending)
            OutlinedButton(
              key: RequestScreen.cancelKey,
              onPressed: _busy ? null : _cancel,
              child: Text(l.clCancelRequest),
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  const _Field(this.label, this.value);

  @override
  Widget build(BuildContext context) => value.trim().isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: context.palette.muted),
              ),
              Text(value),
            ],
          ),
        );
}

class _CustomerName extends ConsumerWidget {
  final String? customerId;
  const _CustomerName({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = customerId;
    if (id == null) return const SizedBox.shrink();
    final account = ref.watch(sessionProvider).value;
    if (account == null || !account.isOwner) {
      final scoped = ref.watch(myCustomersProvider).value ?? const [];
      final name = scoped.where((c) => c.id == id).firstOrNull?.name ?? '';
      return _Field(context.l10n.clCustomer, name);
    }
    return FutureBuilder<Customer?>(
      future: ref.read(customerStoreProvider).load(id),
      builder: (context, snap) =>
          _Field(context.l10n.clCustomer, snap.data?.name ?? ''),
    );
  }
}

/// Customers already kept who might be the one asked for — by name or by
/// phone. A warning, never a merge: approving makes a new customer.
class _Duplicates extends ConsumerWidget {
  final String name;
  final String phone;
  const _Duplicates({required this.name, required this.phone});

  Future<List<Customer>> _find(WidgetRef ref) async {
    final store = ref.read(customerStoreProvider);
    final found = <String, Customer>{};
    for (final query in [name, phone]) {
      if (query.trim().isEmpty) continue;
      final page = await store.page(query: query.trim(), limit: 5);
      for (final s in page.items) {
        final c = await store.load(s.id);
        if (c != null) found[c.id] = c;
      }
    }
    return found.values.toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      FutureBuilder<List<Customer>>(
        future: _find(ref),
        builder: (context, snap) {
          final found = snap.data ?? const <Customer>[];
          if (found.isEmpty) return const SizedBox.shrink();
          final l = context.l10n;
          return Container(
            key: RequestScreen.duplicateKey,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.palette.notice,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: context.palette.onNotice),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.clPossibleDuplicate,
                        style: TextStyle(
                          color: context.palette.onNotice,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final c in found)
                  Text(
                    [c.name, if (c.phone.isNotEmpty) c.phone].join(' · '),
                    style: TextStyle(color: context.palette.onNotice),
                  ),
                const SizedBox(height: 6),
                Text(
                  l.clDuplicateNoMerge,
                  style: TextStyle(color: context.palette.onNotice),
                ),
              ],
            ),
          );
        },
      );
}

/// The design as it was and as proposed, drawn side by side, and what
/// measures differently.
class _Compare extends ConsumerWidget {
  final WorkRequest request;
  const _Compare({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return FutureBuilder<Map<String, Object?>?>(
      future: ref.read(backendProvider)!.requestBase(request.id),
      builder: (context, snap) {
        Design? read(Map<String, Object?>? json) {
          if (json == null) return null;
          try {
            return Design.fromJson(json);
          } on Object {
            return null;
          }
        }

        final before = read(snap.data);
        final after = read(request.proposed);
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (after == null) return FormProblem(l.clProposalUnreadable);
        return Column(
          key: RequestScreen.compareKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              l.clComparison,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (label, design) in [
                  (l.clOriginal, before),
                  (l.clProposed, after),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Text(label),
                          const SizedBox(height: 4),
                          AspectRatio(
                            aspectRatio: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: context.palette.surface,
                                border: Border.all(
                                  color: context.palette.hairline,
                                ),
                              ),
                              child: design == null
                                  ? const SizedBox.shrink()
                                  : DesignPreview(design: design),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {0: FlexColumnWidth(2)},
              children: [
                TableRow(
                  children: [
                    const SizedBox.shrink(),
                    Text(
                      l.clOriginal,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      l.clProposed,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                for (final (label, of) in <(String, String Function(Design))>[
                  (l.clMeasureWidth, (d) => _mm(d.frame?.outline.width)),
                  (l.clMeasureHeight, (d) => _mm(d.frame?.outline.height)),
                  (l.clMeasureDepth, (d) => _mm(d.depthMm)),
                  (l.clMeasureBars, (d) => '${d.dividers.length}'),
                  (l.clMeasureLights, (d) => '${d.sections.length}'),
                  (l.clMeasureOpenings, (d) => '${d.openings.length}'),
                ])
                  _row(
                    context,
                    label,
                    before == null ? '' : of(before),
                    of(after),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _mm(double? mm) => mm == null ? '—' : Units.label(mm);

  TableRow _row(
    BuildContext context,
    String label,
    String before,
    String after,
  ) {
    final changed = before != after;
    final style = TextStyle(
      fontWeight: changed ? FontWeight.w700 : FontWeight.w400,
      color: changed ? context.palette.primary : null,
    );
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(label),
        ),
        Text(context.figure(before)),
        Text(context.figure(after), style: style),
      ],
    );
  }
}

/// What kind of design was asked for, for a test.
DesignKind? kindAskedOf(WorkRequest r) => r.kindAsked;
