import 'string_keys.dart';

/// Arabic.
///
/// Written for a workshop, not for a manual: the words a fitter and a
/// salesperson use — خانة for a section of a frame, درفة for a leaf, توري for
/// an insect screen, فارغ for an opening left unglazed.
///
/// These translations have not yet been read by a native speaker at the
/// factory. Anything that reads wrongly can be corrected in this file alone,
/// without touching a widget.
const Map<T, String> arabicStrings = {
  // -- shared words --------------------------------------------------------
  T.appName: 'ProFrame',
  T.back: 'رجوع',
  T.cancel: 'إلغاء',
  T.close: 'إغلاق',
  T.save: 'حفظ',
  T.delete: 'حذف',
  T.rename: 'تغيير الاسم',
  T.duplicate: 'نسخة',
  T.edit: 'تعديل',
  T.addNote: 'إضافة ملاحظة',
  T.editNote: 'تعديل هذه الملاحظة',
  T.deleteNote: 'حذف هذه الملاحظة',
  T.hideNote: 'إخفاء هذه الملاحظة',
  T.showNote: 'إظهارها',
  T.keepIt: 'الاحتفاظ به',
  T.selected: 'محدد',
  T.note: 'ملاحظة',
  T.notes: 'الملاحظات',
  T.panels: 'الخانات',
  T.dividers: 'الفواصل',
  T.width: 'العرض',
  T.height: 'الارتفاع',
  T.colour: 'اللون',
  T.material: 'المادة',
  T.problems: 'مشاكل',
  T.properties: 'الخصائص',
  T.showProperties: 'إظهار الخصائص',
  T.hideProperties: 'إخفاء الخصائص',
  T.showPropertiesPanel: 'إظهار لوحة الخصائص',
  T.hidePropertiesPanel: 'إخفاء لوحة الخصائص',

  // -- units ---------------------------------------------------------------
  T.unitMillimetre: 'ملم',
  T.unitCentimetre: 'سم',
  T.unitMetre: 'م',
  T.unitInch: 'إنش',
  T.unitMillimetreName: 'مليمتر',
  T.unitCentimetreName: 'سنتيمتر',
  T.unitMetreName: 'متر',
  T.unitInchName: 'إنش',

  // -- products and materials ----------------------------------------------
  T.productDoor: 'باب',
  T.productWindow: 'شباك',
  T.materialPvc: 'بي في سي',
  T.materialAluminium: 'ألمنيوم',
  T.viewedFromOutside: 'منظور من الخارج',
  T.viewedFromInside: 'منظور من الداخل',
  T.dimensionOuterFrame: 'الإطار الخارجي',
  T.dimensionOuterFrameHelp: 'القياسات للإطار نفسه، من حافة إلى حافة.',
  T.dimensionWallOpening: 'فتحة الجدار',
  T.dimensionWallOpeningHelp:
      'القياسات لفتحة الجدار. يصغر الإطار بمقدار فجوة التركيب.',
  T.behaviourFixed: 'ثابت',
  T.behaviourFixedHelp: 'لا يفتح.',
  T.behaviourOpening: 'يفتح',
  T.behaviourOpeningHelp: 'درفة تفتح أو درفة باب.',
  T.mechanismHinged: 'مفصلي',
  T.mechanismHingedHelp: 'يدور على مفصلات في إحدى الحواف.',
  T.mechanismTilt: 'قلّاب',
  T.mechanismTiltHelp: 'معلق من الأسفل: يميل الأعلى إلى الداخل.',
  T.mechanismSlidingLeft: 'ينزلق يساراً',
  T.mechanismSlidingLeftHelp: 'ينزلق فوق الخانة التي على يساره.',
  T.mechanismSlidingRight: 'ينزلق يميناً',
  T.mechanismSlidingRightHelp: 'ينزلق فوق الخانة التي على يمينه.',
  T.hingeLeft: 'المفصلات على اليسار',
  T.hingeRight: 'المفصلات على اليمين',
  T.hingeTop: 'المفصلات في الأعلى',
  T.hingeBottom: 'المفصلات في الأسفل',
  T.opensInward: 'يفتح للداخل',
  T.opensOutward: 'يفتح للخارج',
  T.finishWhite: 'أبيض',
  T.finishCream: 'كريمي',
  T.finishGrey: 'رمادي',
  T.finishAnthracite: 'رمادي فحمي',
  T.finishBlack: 'أسود',
  T.finishBrown: 'بني',
  T.finishGoldenOak: 'بلوط ذهبي',
  T.profileGenericPvc: 'نظام بي في سي عام',
  T.profileGenericAluminium: 'نظام ألمنيوم عام',

  T.assumptionsPvc:
      'بروفيل معاينة فقط. مبني على نظام بي في سي بعرض ٧٠ ملم بخمس حجرات، وهو '
          'نظام شائع. ليس مواصفة من مصنّع: يجب استبدال عروض الأوجه والأعماق '
          'والمجاري وحدود القياس ببيانات مورّدك قبل استخدام أي من هذا في '
          'التصنيع.',
  T.assumptionsAluminium:
      'بروفيل معاينة فقط. مبني على نظام ألمنيوم بعرض ٦٥ ملم بفاصل حراري، وهو '
          'نظام شائع. ليس مواصفة من مصنّع: يجب استبدال عروض الأوجه والأعماق '
          'والمجاري وحدود القياس ببيانات مورّدك قبل استخدام أي من هذا في '
          'التصنيع.',

  // -- projects screen -----------------------------------------------------
  T.openProjectFile: 'فتح ملف مشروع',
  T.factorySettings: 'إعدادات المصنع',
  T.newDesign: 'تصميم جديد',
  T.projectsUnreadable: 'تعذّرت قراءة المشاريع المحفوظة',
  T.projectGone: 'هذا المشروع لم يعد موجوداً.',
  T.deleteProjectTitle: 'حذف هذا المشروع؟',
  T.deleteProjectBody: 'سيُحذف "{name}" من هذا الجهاز. لا يمكن التراجع عن ذلك.',
  T.projectDeleted: 'تم حذف "{name}".',
  T.projectCopied: 'تم نسخ "{name}".',
  T.noSavedDesigns: 'لا توجد تصاميم محفوظة بعد',
  T.noSavedDesignsHelp:
      'اضغط "تصميم جديد"، اختر باباً أو شباكاً، وارسمه كما ترسمه على الورق.',
  T.moreForProject: 'المزيد لـ {name}',
  T.renameProject: 'تغيير اسم المشروع',
  T.whatShouldItBeCalled: 'ما اسم هذا التصميم؟',
  T.projectCouldNotOpen: 'تعذّر فتح هذا المشروع',
  T.fileNotText: 'هذا الملف ليس نصاً، فهو ليس مشروع ProFrame.',
  T.fileCouldNotOpen: 'تعذّر فتح هذا الملف: {error}',

  T.projectDamaged: 'لا يمكن فتح هذا المشروع.',
  T.damagedProject: 'مشروع تالف',
  T.panelCount: '{count} خانة',
  T.noticeInformation: 'معلومة',
  T.noticeCaution: 'انتبه لهذا',
  T.noticeProblem: 'مشكلة',

  // -- new design ----------------------------------------------------------
  T.backToProjects: 'رجوع إلى المشاريع',
  T.whatAreYouMaking: 'ما الذي تصنعه؟',
  T.whatIsItMadeFrom: 'من أي مادة؟',
  T.colourHelp: 'لون الباب أو الشباك نفسه.',
  T.profileSystem: 'نظام البروفيل',
  T.previewProfilesTitle: 'هذه بروفيلات للمعاينة فقط',
  T.previewProfilesHelp:
      'لا يتضمن هذا التطبيق أي بيانات من المصنّعين. مقاسات البروفيل أمثلة '
          'عامة كي تبدو المعاينة ثلاثية الأبعاد صحيحة. يجب استبدالها '
          'بمقاطع المورّد الحقيقية قبل أي تصنيع.',
  T.profileFaceAndDepth: 'وجه الإطار {face} ملم، العمق {depth} ملم',
  T.chooseProductAndMaterial: 'اختر المنتج والمادة للمتابعة.',
  T.startDrawing: 'ابدأ الرسم',

  // -- canvas --------------------------------------------------------------
  T.undo: 'تراجع',
  T.redo: 'إعادة',
  T.designNoteTooltip: 'ملاحظة على التصميم كله',
  T.saveThisProject: 'حفظ هذا المشروع',
  T.export: 'تصدير',
  T.notSaved: 'غير محفوظ',
  T.projectSaved: 'تم حفظ "{name}".',
  T.panelWidth: 'عرض الخانة',
  T.panelWidthHelp: 'تتغير الخانة المجاورة لتبقى المجموع نفسه.',
  T.totalWidth: 'العرض الكلي',
  T.totalHeight: 'الارتفاع الكلي',
  T.noteForThisDesign: 'ملاحظة على هذا التصميم',
  T.noteForThisDesignHelp: 'ملاحظات عامة أو أي شيء طلبه الزبون.',
  T.noteExample:
      'مثلاً: توري، فارغ، زجاج مطفي. الملاحظة تصف الخانة ولا تغيّرها أبداً.',
  T.moveThisDivider: 'تحريك هذا الفاصل',
  T.dragItOnTheDrawing: 'اسحبه على الرسم',
  T.move: 'تحريك',
  T.deleteThisDivider: 'حذف هذا الفاصل',
  T.twoPanelsBecomeOne: 'تصبح الخانتان خانة واحدة',
  T.thisDesign: 'هذا التصميم',
  T.fixedCount: 'ثابت (CH)',
  T.openingCount: 'يفتح (Z)',
  T.nothingLeftToConfirm: 'لم يبق شيء للتأكيد',
  T.stillToConfirm: 'بقي للتأكيد',
  T.everythingConfirmed:
      'تم تأكيد كل القياسات وكل الفتحات. البروفيلات ما زالت للمعاينة فقط، '
          'فهذا تصميم وليس بيانات إنتاج.',
  T.whatIsStillToConfirm: 'ما الذي بقي للتأكيد',
  T.drawFrameToPreview: 'ارسم إطاراً للمعاينة',
  T.preview3d: 'معاينة ثلاثية الأبعاد',
  T.preview25d: 'معاينة 2.5 بعد',
  T.toolDraw: 'رسم',
  T.toolDrawHelp: 'ارسم الإطار والفواصل وعلامات الفتح',
  T.toolMove: 'تحريك',
  T.toolMoveHelp: 'اسحب الورقة، واستعمل إصبعين للتكبير',
  T.toolSelect: 'تحديد',
  T.toolSelectHelp: 'اضغط على خانة أو فاصل، واسحب الملاحظة لتحريكها',
  T.fit: 'ملء الشاشة',
  T.fitHelp: 'اجعل الرسم يملأ الشاشة',
  T.wholeSheet: 'الورقة كاملة',
  T.wholeSheetHelp: 'إظهار الورقة كاملة من جديد',
  T.notesOn: 'الملاحظات ظاهرة',
  T.notesOff: 'الملاحظات مخفية',
  T.hideNoteLabels: 'إخفاء عناوين الملاحظات',
  T.showNoteLabels: 'إظهار عناوين الملاحظات',
  T.deleteSelected: 'حذف المحدد',
  T.selectSomethingFirst: 'حدد شيئاً أولاً',
  T.sizeConfirmed: 'مؤكد',
  T.sizeNotConfirmed: 'غير مؤكد',

  T.dividerTooClose: 'لا يمكن للفاصل أن يقترب إلى هذا الحد من الحافة.',
  T.tapSomethingFirst: 'اضغط على شيء أولاً، ثم احذفه.',
  T.panelFixedAgain: 'أصبحت هذه الخانة ثابتة (CH) من جديد.',
  T.panelIsPartOfFrame:
      'الخانة جزء من الإطار. احذف الفاصل المجاور لها لدمجها مع جارتها.',
  T.neighbourNowWide: 'أصبح عرض الخانة المجاورة {width}.',

  // -- what is still to confirm, and what is wrong ------------------------
  T.panelNumber: 'الخانة {number}',
  T.sourceEstimated: 'تقديري',
  T.sourceDerived: 'مستخرج من الرسم',
  T.askNotInterpreted: 'لم تتم قراءة الرسم بعد.',
  T.askWidthMissing: 'لم يُدخل العرض الكلي.',
  T.askWidthUnconfirmed: 'العرض الكلي {source}، وغير مؤكد.',
  T.askHeightMissing: 'لم يُدخل الارتفاع الكلي.',
  T.askHeightUnconfirmed: 'الارتفاع الكلي {source}، وغير مؤكد.',
  T.askHingeSide: '{panel} تفتح، لكن طريقة فتحها غير مؤكدة.',
  T.findWidthMissing: 'لم يُدخل العرض الكلي.',
  T.findWidthNotPositive: 'العرض الكلي صفر أو أقل.',
  T.findHeightMissing: 'لم يُدخل الارتفاع الكلي.',
  T.findHeightNotPositive: 'الارتفاع الكلي صفر أو أقل.',
  T.findFittingGapNoWidth:
      'فجوة التركيب {gap} على كل جانب لا تترك إطاراً على الإطلاق في فتحة '
          '{opening}.',
  T.findFittingGapNoHeight: 'فجوة التركيب لا تترك أي ارتفاع للإطار.',
  T.findPanelHasNoSize: '{panel} بلا قياس.',
  T.findPanelUnderMinimum:
      '{panel} قياسها {width} × {height}، أقل من الحد الأدنى {minimum}.',
  T.findPanelOutsideFrame: '{panel} خارج الإطار.',
  T.findGapBetweenPanels: 'توجد فجوة {gap} بين خانتين لا يملؤها شيء.',
  T.findPanelsOverlap: 'تتداخل خانتان بمقدار {gap}.',
  T.findRowDoesNotFillFrame:
      'مجموع الخانات في صف واحد {total}، بينما عرض الإطار {frame}.',
  T.findOpeningNotConfirmed: '{panel} تفتح، لكن طريقة فتحها لم تُؤكد.',
  T.findSashTooWide:
      'عرض {panel} هو {width}، وهو فوق الحد {limit} لدرفة تفتح في {profile}.',
  T.findSashTooTall:
      'ارتفاع {panel} هو {height}، وهو فوق الحد {limit} لدرفة تفتح في '
          '{profile}.',
  T.fixWidthMissing: 'اضغط على العرض أسفل الرسم واكتبه.',
  T.fixWidthNotPositive: 'اكتب عرضاً أكبر من صفر.',
  T.fixHeightMissing: 'اضغط على الارتفاع بجانب الرسم واكتبه.',
  T.fixHeightNotPositive: 'اكتب ارتفاعاً أكبر من صفر.',
  T.fixFittingGapWidth: 'قلّل فجوة التركيب، أو راجع قياس الفتحة.',
  T.fixFittingGapHeight: 'قلّل فجوة التركيب، أو راجع ارتفاع الفتحة.',
  T.fixPanelHasNoSize: 'حرّك الفاصل المجاور، أو تراجع عن آخر تغيير.',
  T.fixPanelUnderMinimum: 'وسّعها، أو احذف الفاصل المجاور لها.',
  T.fixPanelOutsideFrame: 'تراجع عن التغيير الذي حرّكها، أو أعد رسم الفاصل.',
  T.fixGapBetweenPanels: 'وسّع إحداهما، أو حرّك الفاصل بينهما.',
  T.fixPanelsOverlap: 'ضيّق إحداهما، أو حرّك الفاصل بينهما.',
  T.fixRowDoesNotFillFrame:
      'غيّر عرض خانة — الخانة المجاورة ستستوعب الفرق.',
  T.fixOpeningNotConfirmed: 'اضغط عليها مطولاً واختر جهة المفصلات والاتجاه.',
  T.fixSashTooWide:
      'اجعلها ثابتة (CH)، أو ضيّقها، أو اختر نظاماً يتحمل درفة أعرض.',
  T.fixSashTooTall: 'اجعلها ثابتة (CH)، أو أضف عارضة فوقها.',
  T.notesMovedWithPanels: 'انتقلت {count} ملاحظة مع خاناتها.',
  T.notesRemovedNowhereToGo: '{count} ملاحظة لم يبق لها مكان فحُذفت.',
  T.refuseNoPanels: 'لا توجد خانات لتغيير قياسها.',
  T.refuseNotInRow: 'هذه الخانة ليست في هذا الصف.',
  T.refuseOnlyPanel:
      'هذه هي الخانة الوحيدة، فعرضها هو عرض الإطار. غيّر العرض الكلي بدلاً '
          'من ذلك.',
  T.refuseTooNarrow: 'لا يمكن أن تكون الخانة أضيق من {minimum}.',
  T.refuseNotEnoughRoom:
      'لا توجد مساحة كافية. توسيع هذه الخانة إلى {requested} سيترك الخانة '
          'المجاورة عند {neighbour}، أقل من الحد الأدنى {minimum}.',
  T.refuseWidestIs: 'أقصى عرض ممكن هو {width}.',

  T.useDrawingAsFrame: 'استخدم رسمي كإطار',
  T.frameFromDrawingMade:
      'الإطار هو المستطيل المحيط بكل ما رسمته. اكتب القياسات الحقيقية أدناه، '
          'أو تراجع وارسمه من جديد.',
  T.drawingTooSmallForFrame: 'ما رُسم حتى الآن لا يكفي لصنع إطار منه.',

  // -- panel properties ----------------------------------------------------
  T.panelType: 'النوع',
  T.howItOpens: 'كيف يفتح',
  T.confirmHowItOpens:
      'علامة السهم بيّنت حافة المفصلات. أكّد الآن كيف يفتح.',
  T.glass: 'زجاج',
  T.mesh: 'توري',
  T.meshHelp: 'شبك ضد الحشرات على هذه الخانة',
  T.emptyOpening: 'فارغ',
  T.emptyOpeningHelp: 'لا زجاج ولا لوح في هذه الفتحة',

  // -- typing a size -------------------------------------------------------
  T.size: 'القياس',
  T.set: 'تثبيت',
  T.typeANumber: 'اكتب رقماً، مثلاً {example}.',
  T.sizeMustBePositive: 'القياس يجب أن يكون أكبر من صفر.',
  T.saveNote: 'حفظ الملاحظة',

  // -- 3D preview ----------------------------------------------------------
  T.backToEdit: 'رجوع إلى التعديل',
  T.turnAround: 'إدارة المنتج',
  T.closeEveryPanel: 'إغلاق كل الخانات',
  T.fitTheView: 'ملء الشاشة',
  T.panelIsFixed: 'هذه الخانة {code} — ثابتة، فهي لا تفتح.',
  T.openThisPanel: 'افتح هذه الخانة',
  T.notMeasured: 'غير مقاس',
  T.notConfirmed: 'غير مؤكد',
  T.designNote: 'ملاحظة التصميم',
  T.emptyPanel: 'فارغ',
  T.nothingOpens:
      'لا شيء في هذا التصميم يفتح. اضغط مطولاً على خانة في الرسم لجعلها Z.',
  T.previewOnly: 'معاينة فقط — البروفيلات عامة وليست بيانات تصنيع.',
  T.previewOnlyTapToOpen:
      'اضغط على خانة Z لفتحها. معاينة فقط — البروفيلات عامة وليست بيانات تصنيع.',
  T.viewAngle: 'زاوية النظر',

  // -- export --------------------------------------------------------------
  T.measurementsIncomplete: 'القياسات غير مكتملة',
  T.everyExportPreview: 'سيُوسم كل تصدير بأنه معاينة.',
  T.drawing: 'الرسم',
  T.includeDimensions: 'إدراج القياسات',
  T.includeNoteMarkers: 'إدراج علامات الملاحظات',
  T.designSheetPdf: 'ورقة التصميم (PDF)',
  T.designSheetPdfHelp: 'الرسم والقياسات ودليل CH/Z وكل الملاحظات.',
  T.drawingPng: 'الرسم (PNG)',
  T.drawingPngHelp: 'الواجهة الأمامية كصورة.',
  T.projectFileProframe: 'ملف المشروع (.proframe)',
  T.projectFileHelp: 'التصميم نفسه القابل للتعديل — وهو الوحيد الذي يُفتح للتعديل.',
  T.exportFooter:
      'ملف PDF أو PNG هو صورة لهذا التصميم. ملف المشروع وحده يحمل القياسات '
          'وإعدادات CH/Z والملاحظات، وهو وحده الذي يمكن فتحه وتعديله مرة أخرى.',
  T.exportFailed: 'فشل التصدير: {error}',
  T.fileBytes: '{size} بايت',
  T.fileKilobytes: '{size} كيلوبايت',

  // -- the exported sheet --------------------------------------------------
  T.sheetConfirmed: 'مؤكد',
  T.sheetNotConfirmed: 'غير مؤكد',
  T.sheetPreviewIncomplete: 'معاينة — القياسات غير مكتملة',
  T.sheetDoNotManufacture: 'لا تصنّع اعتماداً على هذه الورقة.',
  T.sheetFrontView: 'الواجهة الأمامية',
  T.sheetNothingDrawn: 'لم يُرسم شيء بعد.',
  T.sheetNotToScale: 'ليست بمقياس رسم — مُلائمة لحجم الصفحة.',
  T.sheetSpecification: 'المواصفات',
  T.sheetProduct: 'المنتج',
  T.sheetProfile: 'البروفيل',
  T.sheetGenericSuffix: '(معاينة عامة)',
  T.sheetOverallSize: 'القياس الكلي',
  T.sheetMeasuredAs: 'القياس يعني',
  T.sheetViewedFrom: 'الرسم منظور من',
  T.sheetLegend: 'الدليل',
  T.sheetLegendFixed: 'ثابت — لا يفتح',
  T.sheetLegendOpening: 'درفة تفتح أو درفة باب',
  T.sheetPanels: 'الخانات',
  T.sheetDesignNotes: 'ملاحظات التصميم',
  T.sheetSectionNotes: 'ملاحظات الخانات',
  T.sheetFooter:
      'ورقة تصميم مرئية. ليست بيانات تصنيع: التصنيع يتطلب بيانات بروفيل '
          'موثّقة وقواعد تصنيع ومراجعة من المصنع.',
  T.sheetGeneratedAt: 'أُنشئت في {when} بتوقيت UTC.',
  T.sheetFittingGapDetail:
      'فجوة تركيب {gap} على كل جانب، فيصبح الإطار {width} × {height}.',
  T.sheetNotMeasured: 'غير مقاس',

  // -- leaving and recovering ----------------------------------------------
  T.saveBeforeLeaving: 'حفظ قبل الخروج؟',
  T.unsavedChanges: 'في هذا التصميم تغييرات لم تُحفظ بعد.',
  T.keepEditing: 'متابعة التعديل',
  T.leaveWithoutSaving: 'الخروج دون حفظ',
  T.recoverTitle: 'استعادة تصميم غير مكتمل؟',
  T.recoverBody:
      'كان العمل جارياً على "{name}" عند إغلاق التطبيق آخر مرة، ولم يُحفظ '
          'كمشروع بعد.',
  T.discardIt: 'تجاهله',
  T.recover: 'استعادة',

  // -- settings ------------------------------------------------------------
  T.settingsNotice:
      'هذه نقاط البداية لأي تصميم جديد. التصاميم المحفوظة لا تتغير.',
  T.restoreDefaults: 'استعادة الافتراضيات',
  T.defaultsForNewDesign: 'الافتراضيات للتصميم الجديد',
  T.staffTypeAndRead: 'ما يكتبه الموظفون ويقرأونه',
  T.howThisFactoryMeasures: 'كيف يقيس هذا المصنع',
  T.drawingsReadFrom: 'تُقرأ الرسومات من',
  T.sizesMean: 'القياسات تعني',
  T.fittingGap: 'فجوة التركيب',
  T.fittingGapNow: 'تُترك على كل جانب عندما يكون القياس لفتحة جدار. حالياً {gap}.',
  T.fittingGapHelp:
      'الفجوة المتروكة على كل جانب بين الإطار وفتحة الجدار. تُعرض دائماً في '
          'التصميم ولا تُطبَّق أبداً دون إظهارها.',
  T.profileSystems: 'أنظمة البروفيل',
  T.profileSizes:
      'الإطار {face} × {depth} ملم · الدرفة {sash} ملم · الفاصل {divider} ملم '
          '· مجرى الزجاج {rebate} ملم',
  T.largestLeaf: 'أكبر درفة تفتح {width} × {height} ملم',
  T.genericPreviewProfile: 'بروفيل معاينة عام',
  T.replacingWithRealData: 'استبدالها ببيانات حقيقية',
  T.replacingWithRealDataHelp:
      'أنظمة البروفيل أعلاه مدمجة في هذه النسخة. تُقرأ عبر واجهة واحدة، فيمكن '
          'لكتالوج مورّد أن يحل محلها دون تغيير بقية التطبيق — لكن هذا العمل '
          'لم يُنجز بعد، لأنه لم يُزوَّد أي كتالوج.',
  T.appLanguageSection: 'اللغة والأرقام',
  T.language: 'اللغة',
  T.languageHelp: 'تغيّر كل كلمة في التطبيق. ولا تغيّر أي تصميم محفوظ.',
  T.numerals: 'الأرقام',
  T.numeralsWestern: '0 1 2 3',
  T.numeralsArabicIndic: '٠ ١ ٢ ٣',
  T.numeralsHelp: 'بأي أرقام تُكتب القياسات. يمكنك الكتابة بأي منها.',
};
