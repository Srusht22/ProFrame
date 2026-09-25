import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dimensions/units.dart';
import '../../domain/model/design.dart';
import '../canvas/design_preview.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'new_design_screen.dart';
import 'workspace_screen.dart';

/// Whether [design] is one the user is looking for with [query]: its
/// customer, its name, its id or its [shortIdOf] holding what they typed,
/// whatever the case. An empty query finds every design.
bool designMatches(Design design, String query) {
  final wanted = query.trim().toLowerCase();
  if (wanted.isEmpty) return true;
  return [
    design.customer ?? '',
    design.name,
    design.id,
    shortIdOf(design),
  ].any((field) => field.toLowerCase().contains(wanted));
}

/// A short number for [design] that a person can read out and type back
/// in: the moment it was made, to the millisecond, written in letters and
/// figures — eight characters, and different for every design made a
/// millisecond apart. A design whose id carries no such moment is known by
/// the end of its id.
String shortIdOf(Design design) {
  final runs = RegExp(r'\d+').allMatches(design.id).map((m) => m[0]!);
  final longest = runs.fold('', (a, b) => b.length > a.length ? b : a);
  final moment = longest.length >= 13 ? int.tryParse(longest) : null;
  if (moment == null) {
    final id = design.id;
    return id.substring(id.length > 6 ? id.length - 6 : 0).toUpperCase();
  }
  // Microseconds where the platform has them, milliseconds where it does
  // not — the web's clock stops at the millisecond.
  final millis = longest.length >= 16 ? moment ~/ 1000 : moment;
  return millis.toRadixString(36).toUpperCase();
}

/// How long ago [then] was, as a person would say it, seen from [now].
String editedAgo(DateTime then, DateTime now) {
  final gone = now.difference(then);
  String ago(int n, String unit) => '$n $unit${n == 1 ? '' : 's'} ago';
  if (gone.inSeconds < 60) return 'Edited just now';
  if (gone.inMinutes < 60) return 'Edited ${ago(gone.inMinutes, 'minute')}';
  if (gone.inHours < 24) return 'Edited ${ago(gone.inHours, 'hour')}';
  if (gone.inDays == 1) return 'Edited yesterday';
  if (gone.inDays < 7) return 'Edited ${ago(gone.inDays, 'day')}';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final date = '${then.day} ${months[then.month - 1]}';
  return then.year == now.year ? 'Edited $date' : 'Edited $date ${then.year}';
}

/// Where the app opens: every design the workshop has made, the most
/// recently edited first, a search across them, and **New Design**.
///
/// A workshop draws for hundreds of people, so the first thing on screen is
/// not *door or window* but the designs themselves: carry on with one, or
/// begin another. Each is shown by a picture of the design itself — its own
/// saved geometry, drawn — never by a picture of doors in general.
class DesignsScreen extends ConsumerStatefulWidget {
  const DesignsScreen({super.key});

  @override
  ConsumerState<DesignsScreen> createState() => _DesignsScreenState();
}

class _DesignsScreenState extends ConsumerState<DesignsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _newDesign() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const NewDesignScreen()));

  /// Opens [design] exactly as it was saved — its sketch, its geometry, its
  /// openings, its materials — to carry on where it was left.
  void _open(Design design) {
    ref.read(workspaceProvider.notifier).openDesign(design);
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const WorkspaceScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedDesignsProvider);
    // Nowhere to keep designs reads as none kept yet, not as a failure: the
    // way forward is the same.
    final all = saved.value ?? const <Design>[];
    final loading = saved.isLoading && !saved.hasValue;
    final found = [
      for (final design in all)
        if (designMatches(design, _query)) design,
    ];

    return Scaffold(
      backgroundColor: AppTheme.shell,
      body: LayoutBuilder(
        builder: (context, room) {
          final phone = room.maxWidth < 600;
          final gutter = phone ? 16.0 : 32.0;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  phone: phone,
                  gutter: gutter,
                  count: all.length,
                  search: _search,
                  onSearch: (query) => setState(() => _query = query),
                  onNewDesign: _newDesign,
                ),
              ),
              if (loading)
                // Reading the kept designs takes a moment; nothing is said
                // in that moment rather than a spinner that would be gone
                // before it was read.
                const SliverToBoxAdapter(child: SizedBox.shrink())
              else if (all.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NothingYet(onNewDesign: _newDesign),
                )
              else ...[
                SliverToBoxAdapter(
                  child: _Centred(
                    gutter: gutter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 28, bottom: 14),
                      child: _SectionTitle(
                        title: _query.trim().isEmpty
                            ? 'Recent Designs'
                            : 'Results',
                        count: found.length,
                      ),
                    ),
                  ),
                ),
                if (found.isEmpty)
                  SliverToBoxAdapter(
                    child: _Centred(
                      gutter: gutter,
                      child: _NoMatch(query: _query.trim()),
                    ),
                  )
                else
                  _Designs(
                    designs: found,
                    width: room.maxWidth,
                    gutter: gutter,
                    phone: phone,
                    onOpen: _open,
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The width the designs screen lays its content out in.
const _contentWidth = 1200.0;

/// [child], no wider than [_contentWidth], centred, with [gutter] either
/// side.
class _Centred extends StatelessWidget {
  final double gutter;
  final Widget child;

  const _Centred({required this.gutter, required this.child});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _contentWidth),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: child,
      ),
    ),
  );
}

/// The band across the top: the title, how many designs there are, the
/// search, and **New Design**.
class _Header extends StatelessWidget {
  final bool phone;
  final double gutter;
  final int count;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final VoidCallback onNewDesign;

  const _Header({
    required this.phone,
    required this.gutter,
    required this.count,
    required this.search,
    required this.onSearch,
    required this.onNewDesign,
  });

  @override
  Widget build(BuildContext context) {
    final newDesign = FilledButton.icon(
      onPressed: onNewDesign,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.accent,
        foregroundColor: AppTheme.primary,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.add, size: 22),
      label: const Text('New Design'),
    );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROFRAME',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: AppTheme.accent.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Designs',
          style: TextStyle(
            fontSize: phone ? 30 : 36,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          count == 0
              ? 'Every design you make is kept here.'
              : '$count ${count == 1 ? 'design' : 'designs'}',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.accent.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
    final field = TextField(
      controller: search,
      onChanged: onSearch,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 15, color: AppTheme.ink),
      decoration: InputDecoration(
        hintText: 'Search designs...',
        hintStyle: const TextStyle(color: AppTheme.muted),
        filled: true,
        fillColor: AppTheme.surface,
        prefixIcon: const Icon(Icons.search, color: AppTheme.muted),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: search,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close, color: AppTheme.muted),
                  onPressed: () {
                    search.clear();
                    onSearch('');
                  },
                ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.accent, width: 2),
        ),
      ),
    );

    return ColoredBox(
      color: AppTheme.primary,
      child: SafeArea(
        bottom: false,
        child: _Centred(
          gutter: gutter,
          child: Padding(
            padding: EdgeInsets.only(top: phone ? 20 : 40, bottom: 24),
            child: phone
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title,
                      const SizedBox(height: 20),
                      field,
                      const SizedBox(height: 12),
                      newDesign,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: title),
                          const SizedBox(width: 16),
                          newDesign,
                        ],
                      ),
                      const SizedBox(height: 24),
                      field,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _SectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppTheme.ink,
        ),
      ),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
      ),
    ],
  );
}

/// The designs found, as a grid of cards where there is room and a list of
/// cards a thumb can work down on a phone.
class _Designs extends StatelessWidget {
  final List<Design> designs;
  final double width;
  final double gutter;
  final bool phone;
  final ValueChanged<Design> onOpen;

  const _Designs({
    required this.designs,
    required this.width,
    required this.gutter,
    required this.phone,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final across = (width > _contentWidth ? _contentWidth : width) - gutter * 2;
    final side = (width - across) / 2;
    if (phone) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: side),
        sliver: SliverList.separated(
          itemCount: designs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => DesignCard(
            design: designs[i],
            now: now,
            wide: true,
            onOpen: () => onOpen(designs[i]),
          ),
        ),
      );
    }
    final columns = (across / 280).floor().clamp(2, 4);
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: side),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 18,
          crossAxisSpacing: 18,
          mainAxisExtent: DesignCard.gridHeight,
        ),
        itemCount: designs.length,
        itemBuilder: (context, i) => DesignCard(
          design: designs[i],
          now: now,
          wide: false,
          onOpen: () => onOpen(designs[i]),
        ),
      ),
    );
  }
}

/// One design: a picture of it, who it is for, what it is called, how big
/// it is, what kind, when it was last edited, and the way into it.
///
/// [wide] lays it out as a row — the picture beside the words — for a
/// phone, where a column of tall cards would be a long way to scroll.
class DesignCard extends StatefulWidget {
  final Design design;
  final DateTime now;
  final bool wide;
  final VoidCallback onOpen;

  /// How tall the picture is on a card in the grid.
  static const previewHeight = 156.0;

  /// How tall a card in the grid is: the picture, and room under it for the
  /// words to run to two lines of tags and still leave the way in.
  static const gridHeight = previewHeight + 196;

  const DesignCard({
    super.key,
    required this.design,
    required this.now,
    required this.wide,
    required this.onOpen,
  });

  @override
  State<DesignCard> createState() => _DesignCardState();
}

class _DesignCardState extends State<DesignCard> {
  bool _hover = false;

  IconData get _kindIcon => switch (widget.design.kind) {
    DesignKind.door => Icons.door_front_door_outlined,
    DesignKind.window => Icons.window_outlined,
    DesignKind.both => Icons.splitscreen_outlined,
    DesignKind.sliding => Icons.door_sliding_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final design = widget.design;
    final customer = design.customer?.trim();
    final hasCustomer = customer != null && customer.isNotEmpty;
    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.hairline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: RepaintBoundary(child: DesignPreview(design: design)),
      ),
    );

    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          hasCustomer ? customer : 'No customer',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: hasCustomer ? AppTheme.ink : AppTheme.muted,
            fontStyle: hasCustomer ? FontStyle.normal : FontStyle.italic,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                design.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: AppTheme.ink),
              ),
            ),
            const SizedBox(width: 8),
            // The design's number, to read out and search for.
            Text(
              '#${shortIdOf(design)}',
              style: const TextStyle(
                fontSize: 11.5,
                letterSpacing: 0.4,
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Chip(icon: _kindIcon, label: design.kind.label),
            if (design.frame != null)
              _Chip(
                icon: Icons.straighten,
                label:
                    '${Units.format(design.widthMm)} × '
                    '${Units.label(design.heightMm)}',
              ),
          ],
        ),
      ],
    );

    final foot = Row(
      children: [
        Expanded(
          child: Text(
            editedAgo(design.updatedAt, widget.now),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
        ),
        TextButton(
          onPressed: widget.onOpen,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 40),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Open',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward, size: 17),
            ],
          ),
        ),
      ],
    );

    final body = widget.wide
        ? Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 96, height: 124, child: preview),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [words, const SizedBox(height: 4), foot],
                  ),
                ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Every picture in a row the same size, however the words
                // under it fall.
                SizedBox(height: DesignCard.previewHeight, child: preview),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: words,
                ),
                const Spacer(),
                Padding(padding: const EdgeInsets.only(left: 4), child: foot),
              ],
            ),
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hover
                ? AppTheme.primary.withValues(alpha: 0.35)
                : AppTheme.hairline,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.ink.withValues(alpha: _hover ? 0.1 : 0.04),
              blurRadius: _hover ? 22 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onOpen,
            child: body,
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppTheme.shell,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.primary),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// No designs at all yet: say so, and offer the one thing to do.
class _NothingYet extends StatelessWidget {
  final VoidCallback onNewDesign;

  const _NothingYet({required this.onNewDesign});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.architecture,
              size: 34,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No recent designs yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create your first design to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, color: AppTheme.muted),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onNewDesign,
            icon: const Icon(Icons.add),
            label: const Text('New Design'),
          ),
        ],
      ),
    ),
  );
}

/// A search that finds nothing: say what was looked for.
class _NoMatch extends StatelessWidget {
  final String query;

  const _NoMatch({required this.query});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Column(
      children: [
        const Icon(Icons.search_off, size: 36, color: AppTheme.muted),
        const SizedBox(height: 12),
        Text(
          'No designs match “$query”',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Search by customer, design name or design number.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: AppTheme.muted),
        ),
      ],
    ),
  );
}
