import 'string_keys.dart';

/// Kurdish (Sorani).
///
/// Written in the Arabic script, read right to left, with the trade words a
/// workshop already uses — توری for an insect screen, بەتاڵ for an opening
/// left unglazed.
///
/// These translations have not yet been read by a native speaker at the
/// factory. Anything that reads wrongly can be corrected in this file alone,
/// without touching a widget.
const Map<T, String> kurdishStrings = {
  // -- shared words --------------------------------------------------------
  T.appName: 'ProFrame',
  T.back: 'گەڕانەوە',
  T.cancel: 'هەڵوەشاندنەوە',
  T.close: 'داخستن',
  T.save: 'پاشەکەوتکردن',
  T.delete: 'سڕینەوە',
  T.rename: 'گۆڕینی ناو',
  T.duplicate: 'لەبەرگرتنەوە',
  T.edit: 'دەستکاری',
  T.addNote: 'زیادکردنی تێبینی',
  T.editNote: 'دەستکاری ئەم تێبینییە',
  T.deleteNote: 'سڕینەوەی ئەم تێبینییە',
  T.hideNote: 'شاردنەوەی ئەم تێبینییە',
  T.showNote: 'پیشاندانی',
  T.keepIt: 'بیهێڵەوە',
  T.selected: 'هەڵبژێردراو',
  T.note: 'تێبینی',
  T.notes: 'تێبینییەکان',
  T.panels: 'خانەکان',
  T.dividers: 'دابەشکەرەکان',
  T.width: 'پانی',
  T.height: 'بەرزی',
  T.colour: 'ڕەنگ',
  T.material: 'کەرەستە',
  T.problems: 'کێشەکان',
  T.properties: 'تایبەتمەندییەکان',
  T.showProperties: 'پیشاندانی تایبەتمەندییەکان',
  T.hideProperties: 'شاردنەوەی تایبەتمەندییەکان',
  T.showPropertiesPanel: 'پیشاندانی پانێڵی تایبەتمەندییەکان',
  T.hidePropertiesPanel: 'شاردنەوەی پانێڵی تایبەتمەندییەکان',

  // -- units ---------------------------------------------------------------
  T.unitMillimetre: 'مم',
  T.unitCentimetre: 'سم',
  T.unitMetre: 'م',
  T.unitInch: 'ئینچ',
  T.unitMillimetreName: 'میلیمەتر',
  T.unitCentimetreName: 'سەنتیمەتر',
  T.unitMetreName: 'مەتر',
  T.unitInchName: 'ئینچ',

  // -- products and materials ----------------------------------------------
  T.productDoor: 'دەرگا',
  T.productWindow: 'پەنجەرە',
  T.materialPvc: 'پی ڤی سی',
  T.materialAluminium: 'ئەلومینیۆم',
  T.viewedFromOutside: 'لە دەرەوە بینراوە',
  T.viewedFromInside: 'لە ناوەوە بینراوە',
  T.dimensionOuterFrame: 'چوارچێوەی دەرەوە',
  T.dimensionOuterFrameHelp: 'پێوانەکان بۆ خودی چوارچێوەن، لە لێوارەوە بۆ لێوار.',
  T.dimensionWallOpening: 'کردنەوەی دیوار',
  T.dimensionWallOpeningHelp:
      'پێوانەکان بۆ کونی دیوارن. چوارچێوەکە بە ئەندازەی بۆشایی دانان بچووکتر دەبێت.',
  T.behaviourFixed: 'جێگیر',
  T.behaviourFixedHelp: 'ناکرێتەوە.',
  T.behaviourOpening: 'دەکرێتەوە',
  T.behaviourOpeningHelp: 'لەپەڕەیەکی کراوە یان لەپەڕەی دەرگا.',
  T.mechanismHinged: 'ڕەزەیی',
  T.mechanismHingedHelp: 'لەسەر ڕەزە لە لایەکەوە دەسوڕێتەوە.',
  T.mechanismTilt: 'لارکەرەوە',
  T.mechanismTiltHelp: 'لە خوارەوە هەڵواسراوە: سەرەوەی بەرەو ناوەوە لار دەبێتەوە.',
  T.mechanismSlidingLeft: 'بۆ چەپ دەخلیسکێت',
  T.mechanismSlidingLeftHelp: 'بەسەر ئەو خانەیەدا دەخلیسکێت کە لە چەپیەتی.',
  T.mechanismSlidingRight: 'بۆ ڕاست دەخلیسکێت',
  T.mechanismSlidingRightHelp: 'بەسەر ئەو خانەیەدا دەخلیسکێت کە لە ڕاستیەتی.',
  T.hingeLeft: 'ڕەزەکان لە چەپەوە',
  T.hingeRight: 'ڕەزەکان لە ڕاستەوە',
  T.hingeTop: 'ڕەزەکان لە سەرەوە',
  T.hingeBottom: 'ڕەزەکان لە خوارەوە',
  T.opensInward: 'بۆ ناوەوە دەکرێتەوە',
  T.opensOutward: 'بۆ دەرەوە دەکرێتەوە',
  T.finishWhite: 'سپی',
  T.finishCream: 'کرێمی',
  T.finishGrey: 'خۆڵەمێشی',
  T.finishAnthracite: 'خۆڵەمێشی تۆخ',
  T.finishBlack: 'ڕەش',
  T.finishBrown: 'قاوەیی',
  T.finishGoldenOak: 'دار بەڕووی زێڕین',
  T.profileGenericPvc: 'سیستەمی گشتی پی ڤی سی',
  T.profileGenericAluminium: 'سیستەمی گشتی ئەلومینیۆم',

  T.assumptionsPvc:
      'تەنها پڕۆفایلی پێشبینین. لەسەر سیستەمێکی باوی پی ڤی سی ٧٠ مم بە پێنج '
          'ژوورە. تایبەتمەندی بەرهەمهێنەر نییە: پێویستە پانی ڕووەکان و قووڵی و '
          'شوێنی شووشە و سنووری قەبارە بە داتای دابینکەرەکەت بگۆڕدرێن پێش '
          'ئەوەی هیچیان بۆ دروستکردن بەکاربهێنرێن.',
  T.assumptionsAluminium:
      'تەنها پڕۆفایلی پێشبینین. لەسەر سیستەمێکی باوی ئەلومینیۆمی ٦٥ مم بە '
          'پچڕانی گەرمی. تایبەتمەندی بەرهەمهێنەر نییە: پێویستە پانی ڕووەکان و '
          'قووڵی و شوێنی شووشە و سنووری قەبارە بە داتای دابینکەرەکەت بگۆڕدرێن '
          'پێش ئەوەی هیچیان بۆ دروستکردن بەکاربهێنرێن.',

  // -- projects screen -----------------------------------------------------
  T.openProjectFile: 'کردنەوەی فایلی پڕۆژە',
  T.factorySettings: 'ڕێکخستنەکانی کارگە',
  T.newDesign: 'دیزاینی نوێ',
  T.projectsUnreadable: 'پڕۆژە پاشەکەوتکراوەکان ناخوێنرێنەوە',
  T.projectGone: 'ئەم پڕۆژەیە چیتر نییە.',
  T.deleteProjectTitle: 'ئەم پڕۆژەیە بسڕدرێتەوە؟',
  T.deleteProjectBody:
      '"{name}" لەم ئامێرە لادەبرێت. ناکرێت بگەڕێتەوە.',
  T.projectDeleted: '"{name}" سڕایەوە.',
  T.projectCopied: '"{name}" لەبەرگیرایەوە.',
  T.noSavedDesigns: 'هێشتا هیچ دیزاینێک پاشەکەوت نەکراوە',
  T.noSavedDesignsHelp:
      'دەست بنێ بە "دیزاینی نوێ"، دەرگا یان پەنجەرە هەڵبژێرە، و وەک لەسەر '
          'کاغەز بیکێشە.',
  T.moreForProject: 'زیاتر بۆ {name}',
  T.renameProject: 'گۆڕینی ناوی پڕۆژە',
  T.whatShouldItBeCalled: 'ناوی ئەم دیزاینە چی بێت؟',
  T.projectCouldNotOpen: 'ئەم پڕۆژەیە نەکرایەوە',
  T.fileNotText: 'ئەم فایلە دەق نییە، بۆیە پڕۆژەی ProFrame نییە.',
  T.fileCouldNotOpen: 'ئەم فایلە نەکرایەوە: {error}',

  T.projectDamaged: 'ئەم پڕۆژەیە ناکرێتەوە.',
  T.damagedProject: 'پڕۆژەی تێکچوو',
  T.panelCount: '{count} خانە',
  T.noticeInformation: 'زانیاری',
  T.noticeCaution: 'سەرنج بدە',
  T.noticeProblem: 'کێشە',

  // -- new design ----------------------------------------------------------
  T.backToProjects: 'گەڕانەوە بۆ پڕۆژەکان',
  T.whatAreYouMaking: 'چی دروست دەکەیت؟',
  T.whatIsItMadeFrom: 'لە چی دروست دەکرێت؟',
  T.colourHelp: 'ڕەنگی خودی دەرگا یان پەنجەرەکە.',
  T.profileSystem: 'سیستەمی پڕۆفایل',
  T.previewProfilesTitle: 'ئەمانە پڕۆفایلی پێشبینینن',
  T.previewProfilesHelp:
      'هیچ داتایەکی بەرهەمهێنەر لەم بەرنامەیەدا نییە. ئەندازەی پڕۆفایلەکان '
          'نموونەی گشتین تاکو پێشبینینە سێ ڕەهەندییەکە ڕاست دەربکەوێت. پێویستە '
          'پێش هەر بەرهەمهێنانێک بە مەقتەعی ڕاستەقینەی دابینکەرەکەت بگۆڕدرێن.',
  T.profileFaceAndDepth: 'ڕووی چوارچێوە {face} مم، قووڵی {depth} مم',
  T.chooseProductAndMaterial: 'بۆ بەردەوامبوون بەرهەم و کەرەستە هەڵبژێرە.',
  T.startDrawing: 'دەست بکە بە کێشان',

  // -- canvas --------------------------------------------------------------
  T.undo: 'پاشگەزبوونەوە',
  T.redo: 'دووبارەکردنەوە',
  T.designNoteTooltip: 'تێبینی بۆ هەموو دیزاینەکە',
  T.saveThisProject: 'پاشەکەوتکردنی ئەم پڕۆژەیە',
  T.export: 'ناردنە دەرەوە',
  T.notSaved: 'پاشەکەوت نەکراوە',
  T.projectSaved: '"{name}" پاشەکەوت کرا.',
  T.panelWidth: 'پانی خانە',
  T.panelWidthHelp: 'خانەی تەنیشتی دەگۆڕێت تاکو کۆی گشتی نەگۆڕێت.',
  T.totalWidth: 'پانی گشتی',
  T.totalHeight: 'بەرزی گشتی',
  T.noteForThisDesign: 'تێبینی بۆ ئەم دیزاینە',
  T.noteForThisDesignHelp: 'تێبینی گشتی یان هەرچی کڕیارەکە داوای کردووە.',
  T.noteExample:
      'بۆ نموونە: توری، بەتاڵ، شووشەی داپۆشراو. تێبینی خانەکە وەسف دەکات و '
          'هەرگیز ناگۆڕێت.',
  T.moveThisDivider: 'جوڵاندنی ئەم دابەشکەرە',
  T.dragItOnTheDrawing: 'لەسەر وێنەکە ڕایبکێشە',
  T.move: 'جوڵاندن',
  T.deleteThisDivider: 'سڕینەوەی ئەم دابەشکەرە',
  T.twoPanelsBecomeOne: 'دوو خانەکە دەبنە یەک',
  T.thisDesign: 'ئەم دیزاینە',
  T.fixedCount: 'جێگیر (CH)',
  T.openingCount: 'دەکرێتەوە (Z)',
  T.nothingLeftToConfirm: 'هیچ نەماوە بۆ پشتڕاستکردنەوە',
  T.stillToConfirm: 'ماوە بۆ پشتڕاستکردنەوە',
  T.everythingConfirmed:
      'هەموو پێوانەکان و هەموو کردنەوەکان پشتڕاست کراونەتەوە. پڕۆفایلەکان '
          'هێشتا پێشبینینی گشتین، بۆیە ئەمە دیزاینە نەک داتای بەرهەمهێنان.',
  T.whatIsStillToConfirm: 'چی ماوە بۆ پشتڕاستکردنەوە',
  T.drawFrameToPreview: 'چوارچێوەیەک بکێشە بۆ پێشبینین',
  T.preview3d: 'پێشبینینی سێ ڕەهەندی',
  T.preview25d: 'پێشبینینی ٢٫٥ ڕەهەندی',
  T.toolDraw: 'کێشان',
  T.toolDrawHelp: 'چوارچێوە و دابەشکەر و نیشانەی کردنەوە بکێشە',
  T.toolMove: 'جوڵاندن',
  T.toolMoveHelp: 'کاغەزەکە ڕابکێشە، بە دوو پەنجە گەورەی بکە',
  T.toolSelect: 'هەڵبژاردن',
  T.toolSelectHelp: 'دەست لە خانە یان دابەشکەرێک بدە، تێبینی ڕابکێشە بۆ جوڵاندنی',
  T.fit: 'پڕکردنەوە',
  T.fitHelp: 'وێنەکە بە قەبارەی شاشە بکە',
  T.wholeSheet: 'هەموو کاغەزەکە',
  T.wholeSheetHelp: 'دووبارە هەموو کاغەزەکە پیشان بدە',
  T.notesOn: 'تێبینییەکان دیارن',
  T.notesOff: 'تێبینییەکان شاردراونەتەوە',
  T.hideNoteLabels: 'شاردنەوەی ناونیشانی تێبینییەکان',
  T.showNoteLabels: 'پیشاندانی ناونیشانی تێبینییەکان',
  T.deleteSelected: 'سڕینەوەی ئەوەی هەڵبژێردراوە',
  T.selectSomethingFirst: 'سەرەتا شتێک هەڵبژێرە',
  T.sizeConfirmed: 'پشتڕاستکراوە',
  T.sizeNotConfirmed: 'پشتڕاست نەکراوە',

  T.dividerTooClose: 'دابەشکەر ناتوانێت ئەوەندە لە لێوارەکە نزیک بێتەوە.',
  T.tapSomethingFirst: 'سەرەتا دەست لە شتێک بدە، پاشان بیسڕەوە.',
  T.panelFixedAgain: 'ئەم خانەیە دیسان جێگیر بوو (CH).',
  T.panelIsPartOfFrame:
      'خانە بەشێکە لە چوارچێوەکە. دابەشکەری تەنیشتی بسڕەوە تاکو لەگەڵ '
          'دراوسێکەی یەک بگرێت.',
  T.neighbourNowWide: 'ئێستا پانی خانەی تەنیشتی {width}ـە.',

  // -- what is still to confirm, and what is wrong ------------------------
  T.panelNumber: 'خانەی {number}',
  T.sourceEstimated: 'خەمڵێنراو',
  T.sourceDerived: 'لە وێنەکەوە دەرهێنراوە',
  T.askNotInterpreted: 'هێشتا وێنەکە نەخوێنراوەتەوە.',
  T.askWidthMissing: 'پانی گشتی نەنووسراوە.',
  T.askWidthUnconfirmed: 'پانی گشتی {source}ـە، پشتڕاست نەکراوە.',
  T.askHeightMissing: 'بەرزی گشتی نەنووسراوە.',
  T.askHeightUnconfirmed: 'بەرزی گشتی {source}ـە، پشتڕاست نەکراوە.',
  T.askHingeSide: '{panel} دەکرێتەوە، بەڵام چۆنیەتی کردنەوەی پشتڕاست نەکراوە.',
  T.findWidthMissing: 'پانی گشتی نەنووسراوە.',
  T.findWidthNotPositive: 'پانی گشتی سفر یان کەمترە.',
  T.findHeightMissing: 'بەرزی گشتی نەنووسراوە.',
  T.findHeightNotPositive: 'بەرزی گشتی سفر یان کەمترە.',
  T.findFittingGapNoWidth:
      'بۆشایی دانانی {gap} لە هەر لایەکەوە هیچ چوارچێوەیەک ناهێڵێتەوە لە '
          'کردنەوەیەکی {opening}.',
  T.findFittingGapNoHeight: 'بۆشایی دانان هیچ بەرزییەک بۆ چوارچێوە ناهێڵێتەوە.',
  T.findPanelHasNoSize: '{panel} هیچ پێوانەیەکی نییە.',
  T.findPanelUnderMinimum:
      '{panel} {width} × {height}ـە، کەمتر لە کەمترین {minimum}.',
  T.findPanelOutsideFrame: '{panel} لە دەرەوەی چوارچێوەکەیە.',
  T.findGapBetweenPanels: 'بۆشاییەکی {gap} لەنێوان دوو خانەدا هەیە کە هیچی تێدا نییە.',
  T.findPanelsOverlap: 'دوو خانە بە {gap} یەکتر دەپۆشن.',
  T.findRowDoesNotFillFrame:
      'خانەکانی یەک ڕیز کۆی {total} دەکەن، بەڵام چوارچێوەکە {frame} پانە.',
  T.findOpeningNotConfirmed:
      '{panel} دەکرێتەوە، بەڵام چۆنیەتی کردنەوەی پشتڕاست نەکراوەتەوە.',
  T.findSashTooWide:
      'پانی {panel} {width}ـە، زیاتر لە سنووری {limit} بۆ لەپەڕەیەکی کراوە لە '
          '{profile}.',
  T.findSashTooTall:
      'بەرزی {panel} {height}ـە، زیاتر لە سنووری {limit} بۆ لەپەڕەیەکی کراوە لە '
          '{profile}.',
  T.fixWidthMissing: 'دەست لە پانی ژێر وێنەکە بدە و بینووسە.',
  T.fixWidthNotPositive: 'پانییەک گەورەتر لە سفر بنووسە.',
  T.fixHeightMissing: 'دەست لە بەرزی تەنیشت وێنەکە بدە و بینووسە.',
  T.fixHeightNotPositive: 'بەرزییەک گەورەتر لە سفر بنووسە.',
  T.fixFittingGapWidth: 'بۆشایی دانان کەم بکەرەوە، یان پێوانەی کردنەوەکە بپشکنە.',
  T.fixFittingGapHeight:
      'بۆشایی دانان کەم بکەرەوە، یان بەرزی کردنەوەکە بپشکنە.',
  T.fixPanelHasNoSize: 'دابەشکەری تەنیشتی بجوڵێنە، یان پاشگەز ببەرەوە.',
  T.fixPanelUnderMinimum: 'پانتری بکە، یان دابەشکەری تەنیشتی لابە.',
  T.fixPanelOutsideFrame:
      'پاشگەز ببەرەوە لەو گۆڕانکارییەی جوڵاندی، یان دابەشکەرەکە دووبارە بکێشە.',
  T.fixGapBetweenPanels: 'یەکێکیان پانتر بکە، یان دابەشکەری نێوانیان بجوڵێنە.',
  T.fixPanelsOverlap: 'یەکێکیان تەسکتر بکە، یان دابەشکەری نێوانیان بجوڵێنە.',
  T.fixRowDoesNotFillFrame:
      'پانی خانەیەک بگۆڕە — خانەی تەنیشتی جیاوازییەکە هەڵدەگرێت.',
  T.fixOpeningNotConfirmed:
      'دەستت لەسەری ڕابگرە و لایەنی ڕەزە و ئاراستەکە هەڵبژێرە.',
  T.fixSashTooWide:
      'جێگیری بکە (CH)، یان تەسکتری بکە، یان سیستەمێک هەڵبژێرە بۆ لەپەڕەی پانتر.',
  T.fixSashTooTall: 'جێگیری بکە (CH)، یان ترانسۆمێک لەسەرەوەی زیاد بکە.',
  T.notesMovedWithPanels: '{count} تێبینی لەگەڵ خانەکانیان جووڵان.',
  T.notesRemovedNowhereToGo: '{count} تێبینی جێگایان نەما و لابران.',
  T.refuseNoPanels: 'هیچ خانەیەک نییە قەبارەی بگۆڕدرێت.',
  T.refuseNotInRow: 'ئەم خانەیە لەم ڕیزەدا نییە.',
  T.refuseOnlyPanel:
      'ئەمە تەنها خانەیە، بۆیە پانییەکەی پانی چوارچێوەکەیە. لەبری ئەوە پانی '
          'گشتی بگۆڕە.',
  T.refuseTooNarrow: 'خانە ناتوانێت تەسکتر بێت لە {minimum}.',
  T.refuseNotEnoughRoom:
      'جێگای پێویست نییە. پانکردنەوەی ئەم خانەیە بۆ {requested} خانەی تەنیشتی '
          'لە {neighbour} دەهێڵێتەوە، کەمتر لە کەمترین {minimum}.',
  T.refuseWidestIs: 'پانترین شتێک کە دەکرێت {width}ـە.',

  T.useDrawingAsFrame: 'وێنەکەم وەک چوارچێوە بەکاربهێنە',
  T.frameFromDrawingMade:
      'چوارچێوەکە ئەو چوارگۆشەیەیە کە هەموو ئەوەی کێشاوتە دەگرێتەوە. پێوانە '
          'ڕاستەقینەکان لە خوارەوە بنووسە، یان پاشگەز ببەرەوە و دووبارە بیکێشە.',
  T.drawingTooSmallForFrame: 'ئەوەی تا ئێستا کێشراوە بەشی دروستکردنی چوارچێوە ناکات.',

  // -- panel properties ----------------------------------------------------
  T.panelType: 'جۆر',
  T.howItOpens: 'چۆن دەکرێتەوە',
  T.confirmHowItOpens:
      'نیشانەی تیرەکە لایەنی ڕەزەکانی دیاری کرد. ئێستا پشتڕاست بکەرەوە چۆن دەکرێتەوە.',
  T.glass: 'شووشە',
  T.mesh: 'توری',
  T.meshHelp: 'تۆڕی دژە مێش لەسەر ئەم خانەیە',
  T.emptyOpening: 'بەتاڵ',
  T.emptyOpeningHelp: 'نە شووشە و نە تەختە لەم کردنەوەیەدا',

  // -- typing a size -------------------------------------------------------
  T.size: 'پێوانە',
  T.set: 'دانان',
  T.typeANumber: 'ژمارەیەک بنووسە، بۆ نموونە {example}.',
  T.sizeMustBePositive: 'پێوانە دەبێت لە سفر گەورەتر بێت.',
  T.saveNote: 'پاشەکەوتکردنی تێبینی',

  // -- 3D preview ----------------------------------------------------------
  T.backToEdit: 'گەڕانەوە بۆ دەستکاری',
  T.turnAround: 'سووڕاندنەوەی بەرهەمەکە',
  T.closeEveryPanel: 'داخستنی هەموو خانەکان',
  T.fitTheView: 'پڕکردنەوەی دیمەن',
  T.panelIsFixed: 'ئەم خانەیە {code}ـە — جێگیرە، بۆیە ناکرێتەوە.',
  T.openThisPanel: 'ئەم خانەیە بکەرەوە',
  T.notMeasured: 'نەپێوراوە',
  T.notConfirmed: 'پشتڕاست نەکراوە',
  T.designNote: 'تێبینی دیزاین',
  T.emptyPanel: 'بەتاڵ',
  T.nothingOpens:
      'هیچ شتێک لەم دیزاینەدا ناکرێتەوە. دەستت لەسەر خانەیەک لە وێنەکە ڕابگرە '
          'تاکو بیکەیت بە Z.',
  T.previewOnly: 'تەنها پێشبینین — پڕۆفایلەکان گشتین، داتای بەرهەمهێنان نین.',
  T.previewOnlyTapToOpen:
      'دەست لە خانەیەکی Z بدە بۆ کردنەوەی. تەنها پێشبینین — پڕۆفایلەکان گشتین، '
          'داتای بەرهەمهێنان نین.',
  T.viewAngle: 'گۆشەی دیمەن',

  // -- export --------------------------------------------------------------
  T.measurementsIncomplete: 'پێوانەکان تەواو نین',
  T.everyExportPreview: 'هەموو ناردنێکی دەرەوە وەک پێشبینین نیشانە دەکرێت.',
  T.drawing: 'وێنە',
  T.includeDimensions: 'پێوانەکانیش لەگەڵ بێت',
  T.includeNoteMarkers: 'نیشانەی تێبینییەکانیش لەگەڵ بێت',
  T.designSheetPdf: 'پەڕەی دیزاین (PDF)',
  T.designSheetPdfHelp: 'وێنە، پێوانەکان، ڕێنمایی CH/Z و هەموو تێبینییەکان.',
  T.drawingPng: 'وێنە (PNG)',
  T.drawingPngHelp: 'ڕووی پێشەوە وەک وێنە.',
  T.projectFileProframe: 'فایلی پڕۆژە (.proframe)',
  T.projectFileHelp:
      'خودی دیزاینەکە کە دەستکاری دەکرێت — تەنها ئەمە بۆ دەستکاری دەکرێتەوە.',
  T.exportFooter:
      'PDF یان PNG وێنەیەکی ئەم دیزاینەیە. تەنها فایلی پڕۆژە پێوانەکان و '
          'ڕێکخستنی CH/Z و تێبینییەکان هەڵدەگرێت، و تەنها ئەو دەکرێتەوە و '
          'دەستکاری دەکرێت.',
  T.exportFailed: 'ناردنە دەرەوە سەرکەوتوو نەبوو: {error}',
  T.fileBytes: '{size} بایت',
  T.fileKilobytes: '{size} کیلۆبایت',

  // -- the exported sheet --------------------------------------------------
  T.sheetConfirmed: 'پشتڕاستکراوە',
  T.sheetNotConfirmed: 'پشتڕاست نەکراوە',
  T.sheetPreviewIncomplete: 'پێشبینین — پێوانەکان تەواو نین',
  T.sheetDoNotManufacture: 'لەسەر ئەم پەڕەیە بەرهەم مەهێنە.',
  T.sheetFrontView: 'ڕووی پێشەوە',
  T.sheetNothingDrawn: 'هێشتا هیچ نەکێشراوە.',
  T.sheetNotToScale: 'بە پێوەر نییە — بۆ پەڕەکە ڕێکخراوە.',
  T.sheetSpecification: 'تایبەتمەندییەکان',
  T.sheetProduct: 'بەرهەم',
  T.sheetProfile: 'پڕۆفایل',
  T.sheetGenericSuffix: '(پێشبینینی گشتی)',
  T.sheetOverallSize: 'پێوانەی گشتی',
  T.sheetMeasuredAs: 'پێوانە بە',
  T.sheetViewedFrom: 'وێنەکە بینراوە لە',
  T.sheetLegend: 'ڕێنمایی',
  T.sheetLegendFixed: 'جێگیر — ناکرێتەوە',
  T.sheetLegendOpening: 'لەپەڕەی کراوە یان لەپەڕەی دەرگا',
  T.sheetPanels: 'خانەکان',
  T.sheetDesignNotes: 'تێبینییەکانی دیزاین',
  T.sheetSectionNotes: 'تێبینییەکانی خانەکان',
  T.sheetFooter:
      'پەڕەی دیزاینی بینراو. داتای بەرهەمهێنان نییە: بەرهەمهێنان پێویستی بە '
          'داتای پڕۆفایلی پشتڕاستکراوە و یاسای دروستکردن و پێداچوونەوەی '
          'کارگە هەیە.',
  T.sheetGeneratedAt: 'دروستکراوە لە {when} بە کاتی UTC.',
  T.sheetFittingGapDetail:
      'بۆشایی دانانی {gap} لە هەر لایەکەوە، چوارچێوەکە دەبێتە {width} × {height}.',
  T.sheetNotMeasured: 'نەپێوراوە',

  // -- leaving and recovering ----------------------------------------------
  T.saveBeforeLeaving: 'پێش ڕۆیشتن پاشەکەوت بکرێت؟',
  T.unsavedChanges: 'ئەم دیزاینە گۆڕانکاری تێدایە کە پاشەکەوت نەکراون.',
  T.keepEditing: 'بەردەوامبوون لە دەستکاری',
  T.leaveWithoutSaving: 'ڕۆیشتن بەبێ پاشەکەوتکردن',
  T.recoverTitle: 'دیزاینی ناتەواو بگەڕێنرێتەوە؟',
  T.recoverBody:
      'کاتێک بەرنامەکە جاری پێشوو داخرا، کار لەسەر "{name}" دەکرا. هێشتا وەک '
          'پڕۆژە پاشەکەوت نەکراوە.',
  T.discardIt: 'فڕێیبدە',
  T.recover: 'گەڕاندنەوە',

  // -- settings ------------------------------------------------------------
  T.settingsNotice:
      'ئەمانە خاڵی دەستپێکن بۆ دیزاینی نوێ. دیزاینە پاشەکەوتکراوەکان ناگۆڕێن.',
  T.restoreDefaults: 'گەڕاندنەوەی بنەڕەتەکان',
  T.defaultsForNewDesign: 'بنەڕەتەکان بۆ دیزاینی نوێ',
  T.staffTypeAndRead: 'ئەوەی کارمەندان دەینووسن و دەیخوێننەوە',
  T.howThisFactoryMeasures: 'ئەم کارگەیە چۆن دەپێوێت',
  T.drawingsReadFrom: 'وێنەکان دەخوێنرێنەوە لە',
  T.sizesMean: 'پێوانەکان مانای',
  T.fittingGap: 'بۆشایی دانان',
  T.fittingGapNow:
      'لە هەر لایەکەوە جێدەهێڵرێت کاتێک پێوانە بۆ کردنەوەی دیوار بێت. ئێستا {gap}.',
  T.fittingGapHelp:
      'ئەو بۆشاییەی لە هەر لایەکەوە لەنێوان چوارچێوە و کردنەوەی دیوار '
          'جێدەهێڵرێت. هەمیشە لە دیزاینەکەدا پیشان دەدرێت و هەرگیز بە نهێنی '
          'جێبەجێ ناکرێت.',
  T.profileSystems: 'سیستەمەکانی پڕۆفایل',
  T.profileSizes:
      'چوارچێوە {face} × {depth} مم · لەپەڕە {sash} مم · دابەشکەر {divider} مم '
          '· شوێنی شووشە {rebate} مم',
  T.largestLeaf: 'گەورەترین لەپەڕەی کراوە {width} × {height} مم',
  T.genericPreviewProfile: 'پڕۆفایلی پێشبینینی گشتی',
  T.replacingWithRealData: 'گۆڕینیان بە داتای ڕاستەقینە',
  T.replacingWithRealDataHelp:
      'سیستەمەکانی سەرەوە لەم وەشانەدا دانراون. لە ڕێگەی یەک ڕووکارەوە '
          'دەخوێنرێنەوە، بۆیە کەتەلۆگی دابینکەرێک دەتوانێت جێگایان بگرێتەوە بەبێ '
          'گۆڕینی بەشەکانی تری بەرنامەکە — بەڵام ئەو کارە نەکراوە، چونکە هیچ '
          'کەتەلۆگێک پێشکەش نەکراوە.',
  T.appLanguageSection: 'زمان و ژمارەکان',
  T.language: 'زمان',
  T.languageHelp: 'هەموو وشەیەکی بەرنامەکە دەگۆڕێت. هیچ دیزاینێکی پاشەکەوتکراو ناگۆڕێت.',
  T.numerals: 'ژمارەکان',
  T.numeralsWestern: '0 1 2 3',
  T.numeralsArabicIndic: '٠ ١ ٢ ٣',
  T.numeralsHelp: 'پێوانەکان بە چ ژمارەیەک بنووسرێن. بە هەردووکیان دەتوانیت بنووسیت.',
};
