import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/new_design_setup.dart';
import '../../infrastructure/customer_store.dart';
import '../l10n/l10n.dart';
import '../l10n/name_text.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'customers_screen.dart' show initialsOf;
import 'design_name_screen.dart';

/// The one step before a new design: who it is for.
///
/// That is all that is asked, because it is what finds the design again
/// among every other one the workshop has drawn — the list of designs is
/// searched by the person it was drawn for. So it is needed: **Continue**
/// waits until there is a name, and then goes on to the design's own name
/// — *Basement Door*, never the person's — and then *Choose your design*.
///
/// **The customers already kept are found as the name is typed**, a letter
/// at a time, by the same search as the first screen's — by name, or by
/// phone where a number is typed. Tapping one goes on with that customer,
/// so the design is theirs and no second customer of the same name is
/// made; a name nobody has goes on as a new customer, as before.
class NewDesignScreen extends ConsumerStatefulWidget {
  const NewDesignScreen({super.key});

  /// The field's key, for finding it.
  static const customerField = ValueKey('new-design-customer');

  /// The customer [id] offered under the field.
  static ValueKey<String> suggestionKey(String id) =>
      ValueKey('new-design-suggestion-$id');

  /// The line under the suggestions going on with a new customer.
  static const newCustomerKey = ValueKey('new-design-new-customer');

  /// How many customers are offered at once.
  static const shown = 6;

  @override
  ConsumerState<NewDesignScreen> createState() => _NewDesignScreenState();
}

class _NewDesignScreenState extends ConsumerState<NewDesignScreen> {
  final _customer = TextEditingController();

  /// The customers found for what is typed now.
  List<CustomerSummary> _found = const [];

  /// Which search is the latest, so an answer to an older one is dropped.
  int _asked = 0;

  @override
  void initState() {
    super.initState();
    _customer.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _customer.dispose();
    super.dispose();
  }

  String get _who => _customer.text.trim();

  Future<void> _search(String typed) async {
    final ask = ++_asked;
    if (typed.trim().isEmpty) {
      setState(() => _found = const []);
      return;
    }
    List<CustomerSummary> found;
    try {
      final page = await ref
          .read(customerStoreProvider)
          .page(query: typed, limit: NewDesignScreen.shown);
      found = page.items;
    } on Object {
      // Nobody to offer — no permission to see customers, or nothing kept.
      found = const [];
    }
    if (!mounted || ask != _asked) return;
    setState(() => _found = found);
  }

  /// The customer called exactly what is typed, whatever its case or
  /// spacing, if one was found.
  CustomerSummary? get _exactly {
    final wanted = _who.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    for (final c in _found) {
      if (c.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ==
          wanted) {
        return c;
      }
    }
    return null;
  }

  void _go(NewDesignSetup setup) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => DesignNameScreen(setup: setup)),
  );

  void _continue() {
    if (_who.isEmpty) return;
    final same = _exactly;
    _go(
      same == null
          ? NewDesignSetup.forPerson(_who)
          : NewDesignSetup(customerId: same.id, customer: same.name),
    );
  }

  void _pick(CustomerSummary customer) {
    _customer.text = customer.name;
    _go(NewDesignSetup(customerId: customer.id, customer: customer.name));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.newDesign)),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.palette.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.newDesign,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: context.palette.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.whoIsThisFor,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.palette.muted,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      context.l10n.personCustomer,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: context.palette.ink,
                      ),
                    ),
                  ),
                  TextField(
                    key: NewDesignScreen.customerField,
                    controller: _customer,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onChanged: _search,
                    onSubmitted: (_) => _continue(),
                    decoration: InputDecoration(
                      hintText: context.l10n.personHint,
                      hintStyle: TextStyle(color: context.palette.muted),
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: context.palette.muted,
                      ),
                      filled: true,
                      fillColor: context.palette.shell,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.palette.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  if (_who.isNotEmpty)
                    _Suggestions(
                      found: _found,
                      typed: _who,
                      exact: _exactly != null,
                      onPick: _pick,
                      onNew: _continue,
                    ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _who.isEmpty ? null : _continue,
                    child: Text(context.l10n.fwContinue),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The customers kept whose name or phone holds what is typed, under the
/// field, and — where nobody is called exactly that — going on with a new
/// customer of that name.
class _Suggestions extends StatelessWidget {
  final List<CustomerSummary> found;
  final String typed;
  final bool exact;
  final ValueChanged<CustomerSummary> onPick;
  final VoidCallback onNew;

  const _Suggestions({
    required this.found,
    required this.typed,
    required this.exact,
    required this.onPick,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        decoration: BoxDecoration(
          color: p.shell,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (found.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 4),
                  child: Text(
                    l.ndExisting,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: p.muted,
                    ),
                  ),
                ),
              for (final c in found)
                InkWell(
                  key: NewDesignScreen.suggestionKey(c.id),
                  onTap: () => onPick(c),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: p.band,
                          child: Text(
                            initialsOf(c.name),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              NameText(
                                c.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: p.ink,
                                ),
                              ),
                              if (c.phone.trim().isNotEmpty)
                                Text(
                                  c.phone.trim(),
                                  textDirection: TextDirection.ltr,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: p.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: p.muted, size: 20),
                      ],
                    ),
                  ),
                ),
              if (!exact) ...[
                if (found.isNotEmpty) Divider(height: 1, color: p.hairline),
                InkWell(
                  key: NewDesignScreen.newCustomerKey,
                  onTap: onNew,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_add_alt_1_outlined,
                          color: p.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            found.isEmpty
                                ? l.ndNoneFound(typed)
                                : l.ndNewCustomer(typed),
                            style: TextStyle(fontSize: 14, color: p.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
