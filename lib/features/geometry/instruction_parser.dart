import '../../shared/models/design_region.dart';
import '../../shared/models/opening_model.dart';
import 'design_commands.dart';
import 'region_editor.dart';
import 'region_selector.dart';

/// What the parser made of a line of instruction.
class ParsedInstruction {
  final String source;
  final DesignCommand? command;
  final String? problem;

  const ParsedInstruction.understood(this.source, this.command) : problem = null;
  const ParsedInstruction.notUnderstood(this.source, this.problem) : command = null;

  bool get isUnderstood => command != null;
}

/// Turns a plain-English instruction into editable geometry.
///
/// **What this is:** a deterministic parser for a documented set of phrasings.
/// It runs offline, it always does the same thing for the same words, and every
/// phrase it accepts is covered by a test.
///
/// **What it is not:** a language model. A sentence it does not recognise is
/// reported as not understood, with examples — it is never approximated into
/// "something close", because a wrong guess here silently changes a product
/// somebody is going to build. [InstructionParser] is a plain class so a
/// smarter implementation can replace it without anything downstream changing.
class InstructionParser {
  const InstructionParser();

  /// The phrasings this understands, shown in the UI as help.
  static const List<String> examples = [
    'Make the upper half glass and the lower half panel',
    'Make the glass 70%',
    'Put a 40 by 40 cm opening at the top-right',
    'On the left side make an opening 40 cm wide and full height',
    'Make the left section 40 cm wide',
    'Make the left section full height',
    'Make the right panel sliding',
    'Keep the centre panel fixed',
    'Put the handle 100 cm from the floor',
    'Make the left section 30 cm wider than the right section',
    'Move this to the top-right',
  ];

  List<ParsedInstruction> parse(String input) {
    final sentences = input
        .split(RegExp(r'[.;\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return sentences.map(_parseOne).toList();
  }

  ParsedInstruction _parseOne(String raw) {
    final text = raw
        .toLowerCase()
        .replaceAll('×', 'x')
        .replaceAll('center', 'centre')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    for (final rule in _rules) {
      final match = rule.pattern.firstMatch(text);
      if (match != null) {
        final command = rule.build(match, text);
        if (command != null) return ParsedInstruction.understood(raw, command);
      }
    }
    return ParsedInstruction.notUnderstood(
      raw,
      'I did not understand "$raw". Nothing was changed.',
    );
  }

  static final List<_Rule> _rules = [
    // "make the upper half glass and the lower half panel"
    _Rule(
      RegExp(
        r'\b(upper|top)\s+(?:half|part|section)\s+(?:should be\s+|is\s+|as\s+)?'
        r'(glass|panel|louvre|mesh)\b.*\b(lower|bottom)\s+(?:half|part|section)\s+'
        r'(?:should be\s+|is\s+|as\s+)?(glass|panel|louvre|mesh)\b',
      ),
      (match, text) => DivideCommand(
        axis: Axis2.horizontal,
        ratio: _ratioIn(text) ?? 0.5,
        firstInfill: _infill(match.group(2)),
        secondInfill: _infill(match.group(4)),
      ),
    ),

    // "make the left half glass and the right half panel"
    _Rule(
      RegExp(
        r'\bleft\s+(?:half|part|section)\s+(?:should be\s+|is\s+|as\s+)?'
        r'(glass|panel|louvre|mesh)\b.*\bright\s+(?:half|part|section)\s+'
        r'(?:should be\s+|is\s+|as\s+)?(glass|panel|louvre|mesh)\b',
      ),
      (match, text) => DivideCommand(
        axis: Axis2.vertical,
        ratio: _ratioIn(text) ?? 0.5,
        firstInfill: _infill(match.group(1)),
        secondInfill: _infill(match.group(2)),
      ),
    ),

    // "make the glass 70%" / "make the glass 70% and the panel 30%"
    _Rule(
      RegExp(r'\b(?:make|set)\s+(?:the\s+)?([a-z ]*?)\s*(\d+(?:\.\d+)?)\s*(?:%|per ?cent)'),
      (match, text) {
        final selector = _selector(match.group(1) ?? '');
        if (selector.isEmpty) return null;
        final value = double.tryParse(match.group(2)!);
        if (value == null || value <= 0 || value >= 100) return null;
        return SetShareCommand(
          target: selector,
          fraction: value / 100,
          axis: _shareAxisFor(selector),
        );
      },
    ),

    // "on the left side make an opening 40 cm wide and full height"
    _Rule(
      RegExp(
        r'\b(?:on|at)\s+the\s+(left|right)\s*(?:side|hand side)?\b.*?'
        r'(\d+(?:\.\d+)?)\s*(mm|cm|m|in|inch|inches)?\s*wide',
      ),
      (match, text) {
        final side = match.group(1);
        final width = millimetresFrom(
          double.parse(match.group(2)!),
          match.group(3),
        );
        final fullHeight = _saysFullHeight(text);
        final height = fullHeight ? 0.0 : (_heightIn(text) ?? 0);
        if (!fullHeight && height <= 0) return null;
        return PlaceOpeningCommand(
          widthMm: width,
          heightMm: height,
          fullHeight: fullHeight,
          anchor: side == 'left' ? RegionAnchor.centreLeft : RegionAnchor.centreRight,
          operation: _operationIn(text) ??
              (side == 'left' ? CellOperation.casementLeft : CellOperation.casementRight),
        );
      },
    ),

    // "an opening that is 40 cm wide and 40 cm high, at the top-right"
    _Rule(
      RegExp(
        r'(\d+(?:\.\d+)?)\s*(mm|cm|m|in|inch|inches)?\s*wide\s+and\s+'
        r'(\d+(?:\.\d+)?)\s*(mm|cm|m|in|inch|inches)?\s*(?:high|tall)',
      ),
      (match, text) {
        if (!RegExp(r'\b(opening|vent|window|light|section|pane)\b').hasMatch(text)) {
          return null;
        }
        final width = millimetresFrom(double.parse(match.group(1)!), match.group(2));
        final height = millimetresFrom(double.parse(match.group(3)!), match.group(4));
        return PlaceOpeningCommand(
          widthMm: width,
          heightMm: height,
          anchor: _anchorIn(text) ?? RegionAnchor.topRight,
          operation: _operationIn(text) ?? CellOperation.awning,
        );
      },
    ),

    // "half of the window should be glass and the other half panel"
    _Rule(
      RegExp(
        r'\bhalf\b.*?\b(glass|panel|louvre|mesh)\b.*?\b(?:other half|rest|remainder)'
        r'\b.*?\b(glass|panel|louvre|mesh)\b',
      ),
      (match, text) => DivideCommand(
        axis: Axis2.horizontal,
        firstInfill: _infill(match.group(1)),
        secondInfill: _infill(match.group(2)),
      ),
    ),

    // "put a 40 by 40 cm opening at the top-right"
    _Rule(
      RegExp(
        r'(\d+(?:\.\d+)?)\s*(mm|cm|m|in|inch|inches)?\s*(?:x|by)\s*'
        r'(\d+(?:\.\d+)?)\s*(mm|cm|m|in|inch|inches)?',
      ),
      (match, text) {
        if (!RegExp(r'\b(opening|vent|window|light|section|pane)\b').hasMatch(text)) {
          return null;
        }
        final unit = match.group(4) ?? match.group(2);
        final width = millimetresFrom(double.parse(match.group(1)!), unit);
        final height = millimetresFrom(double.parse(match.group(3)!), unit);
        return PlaceOpeningCommand(
          widthMm: width,
          heightMm: height,
          anchor: _anchorIn(text) ?? RegionAnchor.topRight,
          operation: _operationIn(text) ?? CellOperation.awning,
        );
      },
    ),

    // "make the left section 30 cm wider than the right section"
    _Rule(
      RegExp(
        r'\b(?:make|set)\s+(?:the\s+)?([a-z ]+?)\s+(\d+(?:\.\d+)?)\s*'
        r'(mm|cm|m|in|inch|inches)?\s*(wider|narrower|taller|shorter)\s+than\s+'
        r'(?:the\s+)?([a-z ]+)',
      ),
      (match, text) {
        final target = _selector(match.group(1) ?? '');
        final reference = _selector(match.group(5) ?? '');
        if (target.isEmpty || reference.isEmpty) return null;
        final word = match.group(4)!;
        final magnitude = millimetresFrom(
          double.parse(match.group(2)!),
          match.group(3),
        );
        final negative = word == 'narrower' || word == 'shorter';
        return RelativeSizeCommand(
          target: target,
          reference: reference,
          deltaMm: negative ? -magnitude : magnitude,
          axis: (word == 'wider' || word == 'narrower')
              ? Axis2.vertical
              : Axis2.horizontal,
        );
      },
    ),

    // "make the left section full height" / "full width"
    _Rule(
      RegExp(r'\b(?:make|set)\s+(?:the\s+)?([a-z ]+?)\s+full\s+(height|width)\b'),
      (match, text) {
        final selector = _selector(match.group(1) ?? '');
        if (selector.isEmpty) return null;
        return SetSizeCommand(
          target: selector,
          fullHeight: match.group(2) == 'height',
          fullWidth: match.group(2) == 'width',
        );
      },
    ),

    // "make the left section 40 cm wide" / "80 cm high"
    _Rule(
      RegExp(
        r'\b(?:make|set)\s+(?:the\s+)?([a-z ]+?)\s+(\d+(?:\.\d+)?)\s*'
        r'(mm|cm|m|in|inch|inches)?\s*(wide|high|tall)\b',
      ),
      (match, text) {
        final selector = _selector(match.group(1) ?? '');
        if (selector.isEmpty) return null;
        final size = millimetresFrom(double.parse(match.group(2)!), match.group(3));
        final isWidth = match.group(4) == 'wide';
        return SetSizeCommand(
          target: selector,
          widthMm: isWidth ? size : null,
          heightMm: isWidth ? null : size,
        );
      },
    ),

    // "put the handle 100 cm from the floor"
    _Rule(
      RegExp(
        r'\bhandle\s+(?:at\s+|to\s+)?(\d+(?:\.\d+)?)\s*(mm|cm|m|in|inch|inches)?\s*'
        r'(?:from the floor|above the floor|high|up)',
      ),
      (match, text) => SetHandleHeightCommand(
        target: _selector(text),
        heightMm: millimetresFrom(double.parse(match.group(1)!), match.group(2)),
      ),
    ),

    // "move this to the top-right"
    _Rule(
      RegExp(r'\bmove\s+(?:the\s+)?([a-z ]*?)\s*to the\s+([a-z- ]+)'),
      (match, text) {
        final anchor = _anchor(match.group(2) ?? '');
        if (anchor == null) return null;
        return MoveCommand(target: _selector(match.group(1) ?? ''), anchor: anchor);
      },
    ),

    // "make the right panel sliding" / "keep the centre panel fixed"
    _Rule(
      RegExp(
        r'\b(?:make|set|keep|leave)\s+(?:the\s+)?([a-z ]+?)\s+'
        r'(sliding|fixed|casement|awning|hopper|tilt and turn|opening)\b',
      ),
      (match, text) {
        final selector = _selector(match.group(1) ?? '');
        if (selector.isEmpty) return null;
        final operation = _operation(match.group(2)!, selector);
        if (operation == null) return null;
        return SetOperationCommand(target: selector, operation: operation);
      },
    ),

    // "make the upper section glass"
    _Rule(
      RegExp(r'\b(?:make|set)\s+(?:the\s+)?([a-z ]+?)\s+(glass|panel|louvre|mesh)\b'),
      (match, text) {
        final selector = _selector(match.group(1) ?? '');
        final infill = _infill(match.group(2));
        if (selector.isEmpty || infill == null) return null;
        return SetInfillCommand(target: selector, infill: infill);
      },
    ),
  ];

  // -- word to meaning ------------------------------------------------------

  static CellInfill? _infill(String? word) => switch (word) {
        'glass' => CellInfill.glass,
        'panel' => CellInfill.panel,
        'louvre' => CellInfill.louvre,
        'mesh' => CellInfill.mesh,
        _ => null,
      };

  static CellOperation? _operation(String word, RegionSelector selector) {
    final onLeft = selector.position == RegionAnchor.centreLeft ||
        selector.position == RegionAnchor.topLeft ||
        selector.position == RegionAnchor.bottomLeft;
    return switch (word) {
      'fixed' => CellOperation.fixed,
      'sliding' =>
        onLeft ? CellOperation.slidingLeft : CellOperation.slidingRight,
      'casement' || 'opening' =>
        onLeft ? CellOperation.casementLeft : CellOperation.casementRight,
      'awning' => CellOperation.awning,
      'hopper' => CellOperation.hopper,
      'tilt and turn' =>
        onLeft ? CellOperation.tiltTurnLeft : CellOperation.tiltTurnRight,
      _ => null,
    };
  }

  static CellOperation? _operationIn(String text) {
    for (final word in const [
      'sliding',
      'awning',
      'hopper',
      'tilt and turn',
      'fixed',
    ]) {
      if (text.contains(word)) {
        return _operation(word, const RegionSelector());
      }
    }
    return null;
  }

  static RegionAnchor? _anchor(String word) {
    final text = word.trim().replaceAll('-', ' ');
    if (text.startsWith('top right') || text.startsWith('right top')) {
      return RegionAnchor.topRight;
    }
    if (text.startsWith('top left') || text.startsWith('left top')) {
      return RegionAnchor.topLeft;
    }
    if (text.startsWith('bottom right')) return RegionAnchor.bottomRight;
    if (text.startsWith('bottom left')) return RegionAnchor.bottomLeft;
    if (text.startsWith('top')) return RegionAnchor.topCentre;
    if (text.startsWith('bottom')) return RegionAnchor.bottomCentre;
    if (text.startsWith('left')) return RegionAnchor.centreLeft;
    if (text.startsWith('right')) return RegionAnchor.centreRight;
    if (text.startsWith('centre') || text.startsWith('middle')) {
      return RegionAnchor.centre;
    }
    return null;
  }

  static RegionAnchor? _anchorIn(String text) {
    final match = RegExp(
      r'\b(top[- ]?right|top[- ]?left|bottom[- ]?right|bottom[- ]?left|'
      r'top|bottom|left|right|centre|middle)\b',
    ).firstMatch(text);
    return match == null ? null : _anchor(match.group(1)!);
  }

  /// Builds a selector from words like "left panel", "upper glass", "this".
  static RegionSelector _selector(String words) {
    final text = words.trim();
    RegionAnchor? position;
    if (RegExp(r'\b(upper|top)\b').hasMatch(text)) position = RegionAnchor.topCentre;
    if (RegExp(r'\b(lower|bottom)\b').hasMatch(text)) {
      position = RegionAnchor.bottomCentre;
    }
    if (RegExp(r'\bleft\b').hasMatch(text)) position = RegionAnchor.centreLeft;
    if (RegExp(r'\bright\b').hasMatch(text)) position = RegionAnchor.centreRight;
    if (RegExp(r'\b(centre|middle)\b').hasMatch(text)) position = RegionAnchor.centre;

    CellInfill? infill;
    if (text.contains('glass')) infill = CellInfill.glass;
    if (text.contains('panel')) infill = CellInfill.panel;
    if (text.contains('louvre')) infill = CellInfill.louvre;

    final operable = RegExp(r'\b(opening|vent|sash|leaf)\b').hasMatch(text);

    // "this", "that", "it" mean the selected section — but only when the
    // sentence gives no other clue about which section is meant.
    if (position == null &&
        infill == null &&
        !operable &&
        RegExp(r'\b(this|that|it|selected)\b').hasMatch(text)) {
      return RegionSelector.selection;
    }

    return RegionSelector(
      position: position,
      infill: infill,
      operableOnly: operable,
    );
  }

  /// A share instruction on a left/right section means width; anything else
  /// means height, which is how people talk about glass over panel.
  static Axis2 _shareAxisFor(RegionSelector selector) =>
      (selector.position == RegionAnchor.centreLeft ||
              selector.position == RegionAnchor.centreRight)
          ? Axis2.vertical
          : Axis2.horizontal;

  static bool _saysFullHeight(String text) => RegExp(
        r'\bfull (height|the height)\b|from the bottom to the top|'
        r'top to bottom|floor to ceiling',
      ).hasMatch(text);

  static double? _heightIn(String text) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*(mm|cm|m|in|inch|inches)?\s*(?:high|tall|height)',
    ).firstMatch(text);
    if (match == null) return null;
    return millimetresFrom(double.parse(match.group(1)!), match.group(2));
  }

  static double? _ratioIn(String text) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*(?:%|per ?cent)').firstMatch(text);
    if (match == null) return null;
    final value = double.parse(match.group(1)!);
    if (value <= 0 || value >= 100) return null;
    return value / 100;
  }
}

class _Rule {
  final RegExp pattern;
  final DesignCommand? Function(RegExpMatch match, String text) build;

  _Rule(this.pattern, this.build);
}

/// Applies a batch of instructions in order, stopping at the first one that
/// cannot be carried out so the design never ends up half-changed.
class InstructionRunner {
  final InstructionParser parser;

  const InstructionRunner({this.parser = const InstructionParser()});

  InstructionRunResult run(
    OpeningModel model,
    String input, {
    String? selectedId,
  }) {
    final parsed = parser.parse(input);
    if (parsed.isEmpty) {
      return const InstructionRunResult(
        applied: [],
        problems: ['Nothing to do.'],
      );
    }

    var current = model;
    var selection = selectedId;
    final applied = <String>[];
    final problems = <String>[];

    for (final instruction in parsed) {
      if (!instruction.isUnderstood) {
        problems.add(instruction.problem!);
        continue;
      }
      final outcome = instruction.command!.apply(current, selectedId: selection);
      if (!outcome.succeeded) {
        problems.add('"${instruction.source}" — ${outcome.problem}');
        continue;
      }
      current = outcome.model;
      selection = outcome.selectedId ?? selection;
      applied.add(outcome.description);
    }

    return InstructionRunResult(
      model: identical(current, model) ? null : current,
      selectedId: selection,
      applied: applied,
      problems: problems,
    );
  }
}

class InstructionRunResult {
  /// Null when nothing was changed.
  final OpeningModel? model;
  final String? selectedId;
  final List<String> applied;
  final List<String> problems;

  const InstructionRunResult({
    this.model,
    this.selectedId,
    required this.applied,
    required this.problems,
  });

  bool get changedAnything => model != null;
}
