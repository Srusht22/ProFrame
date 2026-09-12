import 'string_keys.dart';

/// English — the language the app is written in, and the fallback for any
/// phrase another table has not translated yet.
const Map<T, String> englishStrings = {
  // -- shared words --------------------------------------------------------
  T.appName: 'ProFrame',
  T.back: 'Back',
  T.cancel: 'Cancel',
  T.close: 'Close',
  T.save: 'Save',
  T.delete: 'Delete',
  T.rename: 'Rename',
  T.duplicate: 'Duplicate',
  T.edit: 'Edit',
  T.addNote: 'Add a note',
  T.editNote: 'Edit this note',
  T.deleteNote: 'Delete this note',
  T.hideNote: 'Hide this note',
  T.showNote: 'Show it',
  T.keepIt: 'Keep it',
  T.selected: 'selected',
  T.note: 'Note',
  T.notes: 'Notes',
  T.panels: 'Panels',
  T.dividers: 'Dividers',
  T.width: 'Width',
  T.height: 'Height',
  T.colour: 'Colour',
  T.material: 'Material',
  T.problems: 'Problems',
  T.properties: 'Properties',
  T.showProperties: 'Show properties',
  T.hideProperties: 'Hide properties',
  T.showPropertiesPanel: 'Show the properties panel',
  T.hidePropertiesPanel: 'Hide the properties panel',

  // -- units ---------------------------------------------------------------
  T.unitMillimetre: 'mm',
  T.unitCentimetre: 'cm',
  T.unitMetre: 'm',
  T.unitInch: 'in',
  T.unitMillimetreName: 'Millimetres',
  T.unitCentimetreName: 'Centimetres',
  T.unitMetreName: 'Metres',
  T.unitInchName: 'Inches',

  // -- products and materials ----------------------------------------------
  T.productDoor: 'Door',
  T.productWindow: 'Window',
  T.materialPvc: 'PVC',
  T.materialAluminium: 'Aluminium',
  T.viewedFromOutside: 'Viewed from outside',
  T.viewedFromInside: 'Viewed from inside',
  T.dimensionOuterFrame: 'The outer frame',
  T.dimensionOuterFrameHelp: 'Sizes are the frame itself, edge to edge.',
  T.dimensionWallOpening: 'The wall opening',
  T.dimensionWallOpeningHelp:
      'Sizes are the hole in the wall. The frame is made smaller by the '
          'fitting gap.',
  T.behaviourFixed: 'Fixed',
  T.behaviourFixedHelp: 'Does not open.',
  T.behaviourOpening: 'Opening',
  T.behaviourOpeningHelp: 'An opening sash or door leaf.',
  T.mechanismHinged: 'Hinged',
  T.mechanismHingedHelp: 'Swings on hinges at one edge.',
  T.mechanismTilt: 'Tilt',
  T.mechanismTiltHelp: 'Bottom-hung: the top tilts inward.',
  T.mechanismSlidingLeft: 'Slides left',
  T.mechanismSlidingLeftHelp: 'Slides across the panel to its left.',
  T.mechanismSlidingRight: 'Slides right',
  T.mechanismSlidingRightHelp: 'Slides across the panel to its right.',
  T.hingeLeft: 'Hinges on the left',
  T.hingeRight: 'Hinges on the right',
  T.hingeTop: 'Hinges at the top',
  T.hingeBottom: 'Hinges at the bottom',
  T.opensInward: 'Opens inward',
  T.opensOutward: 'Opens outward',
  T.finishWhite: 'White',
  T.finishCream: 'Cream',
  T.finishGrey: 'Grey',
  T.finishAnthracite: 'Anthracite',
  T.finishBlack: 'Black',
  T.finishBrown: 'Brown',
  T.finishGoldenOak: 'Golden oak',
  T.profileGenericPvc: 'Generic PVC casement',
  T.profileGenericAluminium: 'Generic aluminium casement',

  // -- projects screen -----------------------------------------------------
  T.openProjectFile: 'Open a project file',
  T.factorySettings: 'Factory settings',
  T.newDesign: 'New design',
  T.projectsUnreadable: 'Saved projects could not be read',
  T.projectGone: 'That project is no longer there.',
  T.deleteProjectTitle: 'Delete this project?',
  T.deleteProjectBody:
      '"{name}" will be removed from this device. This cannot be undone.',
  T.projectDeleted: 'Deleted "{name}".',
  T.projectCopied: 'Copied "{name}".',
  T.noSavedDesigns: 'No saved designs yet',
  T.noSavedDesignsHelp:
      'Tap New design, choose a door or a window, and draw it the way you '
          'would on paper.',
  T.moreForProject: 'More for {name}',
  T.renameProject: 'Rename project',
  T.whatShouldItBeCalled: 'What should this design be called?',
  T.projectCouldNotOpen: 'That project could not be opened',
  T.fileNotText: 'That file is not text, so it is not a ProFrame project.',
  T.fileCouldNotOpen: 'That file could not be opened: {error}',

  T.projectDamaged: 'This project cannot be opened.',
  T.damagedProject: 'Damaged project',
  T.panelCount: '{count} panels',
  T.noticeInformation: 'Information',
  T.noticeCaution: 'Check this',
  T.noticeProblem: 'Problem',

  // -- new design ----------------------------------------------------------
  T.backToProjects: 'Back to projects',
  T.whatAreYouMaking: 'What are you making?',
  T.whatIsItMadeFrom: 'What is it made from?',
  T.colourHelp: 'The colour of the door or window itself.',
  T.profileSystem: 'Profile system',
  T.previewProfilesTitle: 'These are preview profiles',
  T.previewProfilesHelp:
      'No manufacturer data is included in this app. The profile sizes are '
          'generic examples so the 3D preview looks right. They must be '
          "replaced with your supplier's real sections before anything is "
          'manufactured.',
  T.profileFaceAndDepth: '{face} mm frame face, {depth} mm deep',
  T.chooseProductAndMaterial: 'Choose a product and a material to continue.',
  T.startDrawing: 'Start drawing',

  // -- canvas --------------------------------------------------------------
  T.undo: 'Undo',
  T.redo: 'Redo',
  T.designNoteTooltip: 'Note for the whole design',
  T.saveThisProject: 'Save this project',
  T.export: 'Export',
  T.notSaved: 'Not saved',
  T.projectSaved: 'Saved "{name}".',
  T.panelWidth: 'Panel width',
  T.panelWidthHelp: 'The panel beside it changes to keep the total the same.',
  T.totalWidth: 'Total width',
  T.totalHeight: 'Total height',
  T.noteForThisDesign: 'Note for this design',
  T.noteForThisDesignHelp:
      'General remarks or anything the customer asked for.',
  T.noteExample:
      'For example: توري, فارغ, frosted glass. A note describes the panel; it '
          'never changes it.',
  T.moveThisDivider: 'Move this divider',
  T.dragItOnTheDrawing: 'Drag it on the drawing',
  T.move: 'Move',
  T.deleteThisDivider: 'Delete this divider',
  T.twoPanelsBecomeOne: 'The two panels become one',
  T.thisDesign: 'This design',
  T.fixedCount: 'Fixed (CH)',
  T.openingCount: 'Opening (Z)',
  T.nothingLeftToConfirm: 'Nothing left to confirm',
  T.stillToConfirm: 'Still to confirm',
  T.everythingConfirmed:
      'Every dimension and opening has been confirmed. The profiles are still '
          'generic previews, so this is a design, not production data.',
  T.whatIsStillToConfirm: 'What is still to confirm',
  T.drawFrameToPreview: 'Draw a frame to preview',
  T.preview3d: '3D Preview',
  T.preview25d: '2.5D preview',
  T.toolDraw: 'Draw',
  T.toolDrawHelp: 'Draw the frame, dividers and opening marks',
  T.toolMove: 'Move',
  T.toolMoveHelp: 'Drag the sheet, pinch to zoom',
  T.toolSelect: 'Select',
  T.toolSelectHelp: 'Tap a panel or a divider, drag a note to move it',
  T.fit: 'Fit',
  T.fitHelp: 'Fit the drawing to the screen',
  T.wholeSheet: 'Whole sheet',
  T.wholeSheetHelp: 'Show the whole sheet again',
  T.notesOn: 'Notes on',
  T.notesOff: 'Notes off',
  T.hideNoteLabels: 'Hide the note labels',
  T.showNoteLabels: 'Show the note labels',
  T.deleteSelected: 'Delete what is selected',
  T.selectSomethingFirst: 'Select something first',
  T.sizeConfirmed: 'confirmed',
  T.sizeNotConfirmed: 'not confirmed',

  T.dividerTooClose: 'A divider cannot go that close to the edge.',
  T.tapSomethingFirst: 'Tap something first, then delete it.',
  T.panelFixedAgain: 'That panel is fixed (CH) again.',
  T.panelIsPartOfFrame:
      'A panel is part of the frame. Delete the divider beside it to join it '
          'to its neighbour.',
  T.neighbourNowWide: 'The panel beside it is now {width}.',

  // -- what is still to confirm, and what is wrong ------------------------
  T.panelNumber: 'Panel {number}',
  T.sourceEstimated: 'estimated',
  T.sourceDerived: 'worked out from the drawing',
  T.askNotInterpreted: 'The drawing has not been interpreted yet.',
  T.askWidthMissing: 'The overall width has not been entered.',
  T.askWidthUnconfirmed: 'The overall width is {source}, not confirmed.',
  T.askHeightMissing: 'The overall height has not been entered.',
  T.askHeightUnconfirmed: 'The overall height is {source}, not confirmed.',
  T.askHingeSide: '{panel} opens, but how it opens is not confirmed.',
  T.findWidthMissing: 'The overall width has not been entered.',
  T.findWidthNotPositive: 'The overall width is zero or negative.',
  T.findHeightMissing: 'The overall height has not been entered.',
  T.findHeightNotPositive: 'The overall height is zero or negative.',
  T.findFittingGapNoWidth:
      'The fitting gap of {gap} each side leaves no frame at all in a '
          '{opening} opening.',
  T.findFittingGapNoHeight: 'The fitting gap leaves no frame height at all.',
  T.findPanelHasNoSize: '{panel} has no size.',
  T.findPanelUnderMinimum:
      '{panel} is {width} × {height}, under the {minimum} minimum.',
  T.findPanelOutsideFrame: '{panel} sits outside the frame.',
  T.findGapBetweenPanels:
      'There is a {gap} gap between two panels that nothing fills.',
  T.findPanelsOverlap: 'Two panels overlap by {gap}.',
  T.findRowDoesNotFillFrame:
      'The panels in one row add up to {total}, but the frame is {frame} wide.',
  T.findOpeningNotConfirmed:
      '{panel} opens, but how it opens has not been confirmed.',
  T.findSashTooWide:
      '{panel} is {width} wide, over the {limit} limit for an opening leaf in '
          '{profile}.',
  T.findSashTooTall:
      '{panel} is {height} tall, over the {limit} limit for an opening leaf in '
          '{profile}.',
  T.fixWidthMissing: 'Tap the width below the drawing and type it.',
  T.fixWidthNotPositive: 'Type a width greater than zero.',
  T.fixHeightMissing: 'Tap the height beside the drawing and type it.',
  T.fixHeightNotPositive: 'Type a height greater than zero.',
  T.fixFittingGapWidth: 'Reduce the fitting gap, or check the opening size.',
  T.fixFittingGapHeight: 'Reduce the fitting gap, or check the opening height.',
  T.fixPanelHasNoSize: 'Move the divider beside it, or undo the last change.',
  T.fixPanelUnderMinimum: 'Widen it, or remove the divider beside it.',
  T.fixPanelOutsideFrame:
      'Undo the change that moved it, or redraw the divider.',
  T.fixGapBetweenPanels: 'Widen one of them, or move the divider between them.',
  T.fixPanelsOverlap: 'Narrow one of them, or move the divider between them.',
  T.fixRowDoesNotFillFrame:
      'Change a panel width — the panel beside it will take up the difference.',
  T.fixOpeningNotConfirmed:
      'Long-press it and choose the hinge side and direction.',
  T.fixSashTooWide:
      'Make it fixed (CH), narrow it, or choose a system rated for a wider '
          'leaf.',
  T.fixSashTooTall: 'Make it fixed (CH), or add a transom above it.',
  T.notesMovedWithPanels: '{count} notes moved with their panels.',
  T.notesRemovedNowhereToGo: '{count} notes had nowhere to go and were removed.',
  T.refuseNoPanels: 'There are no panels to resize.',
  T.refuseNotInRow: 'That panel is not in this row.',
  T.refuseOnlyPanel:
      'This is the only panel, so its width is the frame width. Change the '
          'overall width instead.',
  T.refuseTooNarrow: 'A panel cannot be narrower than {minimum}.',
  T.refuseNotEnoughRoom:
      'There is not enough room. Widening this panel to {requested} would '
          'leave the panel beside it at {neighbour}, under the {minimum} '
          'minimum.',
  T.refuseWidestIs: 'The widest it can be is {width}.',

  // -- panel properties ----------------------------------------------------
  T.panelType: 'Type',
  T.howItOpens: 'How it opens',
  T.confirmHowItOpens:
      'The chevron said which edge the hinges are on. Confirm how it opens.',
  T.glass: 'Glass',
  T.mesh: 'Mesh (توري)',
  T.meshHelp: 'An insect screen on this panel',
  T.emptyOpening: 'Empty (فارغ)',
  T.emptyOpeningHelp: 'No glass and no panel in this opening',

  // -- typing a size -------------------------------------------------------
  T.size: 'Size',
  T.set: 'Set',
  T.typeANumber: 'Type a number, for example {example}.',
  T.sizeMustBePositive: 'A size has to be more than zero.',
  T.saveNote: 'Save note',

  // -- 3D preview ----------------------------------------------------------
  T.backToEdit: 'Back to edit',
  T.turnAround: 'Turn the product around',
  T.closeEveryPanel: 'Close every panel',
  T.fitTheView: 'Fit the view',
  T.panelIsFixed: 'This panel is {code} — fixed, so it does not open.',
  T.openThisPanel: 'Open this panel',
  T.notMeasured: 'Not measured',
  T.notConfirmed: 'Not confirmed',
  T.designNote: 'Design note',
  T.emptyPanel: 'Empty',
  T.nothingOpens:
      'Nothing in this design opens. Long-press a panel on the drawing to '
          'make it a Z.',
  T.previewOnly:
      'Preview only — the profiles are generic, not manufacturing data.',
  T.previewOnlyTapToOpen:
      'Tap a Z panel to open it. Preview only — the profiles are generic, not '
          'manufacturing data.',
  T.viewAngle: 'View angle',

  // -- export --------------------------------------------------------------
  T.measurementsIncomplete: 'Measurements are incomplete',
  T.everyExportPreview: 'Every export will be labelled as a preview.',
  T.drawing: 'Drawing',
  T.includeDimensions: 'Include dimensions',
  T.includeNoteMarkers: 'Include note markers',
  T.designSheetPdf: 'Design sheet (PDF)',
  T.designSheetPdfHelp: 'Drawing, dimensions, CH/Z legend and every note.',
  T.drawingPng: 'Drawing (PNG)',
  T.drawingPngHelp: 'The front view as a picture.',
  T.projectFileProframe: 'Project file (.proframe)',
  T.projectFileHelp:
      'The editable design itself — the only one that reopens for editing.',
  T.exportFooter:
      'A PDF or a PNG is a picture of this design. Only the project file '
          'carries the dimensions, the CH/Z settings and the notes, and only '
          'it can be opened and edited again.',
  T.exportFailed: 'That export failed: {error}',
  T.fileBytes: '{size} bytes',
  T.fileKilobytes: '{size} KB',

  // -- leaving and recovering ----------------------------------------------
  T.saveBeforeLeaving: 'Save before leaving?',
  T.unsavedChanges: 'This design has changes that are not saved yet.',
  T.keepEditing: 'Keep editing',
  T.leaveWithoutSaving: 'Leave without saving',
  T.recoverTitle: 'Recover unfinished design?',
  T.recoverBody:
      '"{name}" was being worked on when the app last closed. It has not been '
          'saved as a project yet.',
  T.discardIt: 'Discard it',
  T.recover: 'Recover',

  // -- settings ------------------------------------------------------------
  T.settingsNotice:
      'These are the starting points for a new design. Designs already saved '
          'are not changed.',
  T.restoreDefaults: 'Restore defaults',
  T.defaultsForNewDesign: 'Defaults for a new design',
  T.staffTypeAndRead: 'Staff type and read',
  T.howThisFactoryMeasures: 'How this factory measures',
  T.drawingsReadFrom: 'Drawings are read from',
  T.sizesMean: 'Sizes mean',
  T.fittingGap: 'Fitting gap',
  T.fittingGapNow:
      'Left each side when a size is a wall opening. Currently {gap}.',
  T.fittingGapHelp:
      'The gap left on each side between the frame and the wall opening. It '
          'is always shown in the design, never applied invisibly.',
  T.profileSystems: 'Profile systems',
  T.profileSizes:
      'Frame {face} × {depth} mm · sash {sash} mm · divider {divider} mm · '
          'rebate {rebate} mm',
  T.largestLeaf: 'Largest opening leaf {width} × {height} mm',
  T.genericPreviewProfile: 'Generic preview profile',
  T.replacingWithRealData: 'Replacing these with real data',
  T.replacingWithRealDataHelp:
      'The profile systems above are built into this version. They are read '
          'through one interface, so a supplier catalogue can replace them '
          'without the rest of the app changing — but that work has not been '
          'done, because no catalogue has been supplied.',
  T.appLanguageSection: 'Language and numbers',
  T.language: 'Language',
  T.languageHelp:
      'Changes every word in the app. It never changes a saved design.',
  T.numerals: 'Numbers',
  T.numeralsWestern: '0 1 2 3',
  T.numeralsArabicIndic: '٠ ١ ٢ ٣',
  T.numeralsHelp: 'Which digits sizes are written with. You can type either.',
};
