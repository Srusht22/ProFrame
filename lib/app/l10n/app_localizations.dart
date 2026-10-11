import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ckb.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ckb'),
    Locale('en'),
  ];

  /// The application's name; a product name, not translated.
  ///
  /// In en, this message translates to:
  /// **'ProFrame'**
  String get appTitle;

  /// Tooltip of the back arrow.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get fwBack;

  /// Close button or tooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get fwClose;

  /// Cancel button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get fwCancel;

  /// OK button.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get fwOk;

  /// Save button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get fwSave;

  /// Continue button.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get fwContinue;

  /// Delete button or tooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get fwDelete;

  /// More options tooltip.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get fwMore;

  /// Tooltip of a menu button.
  ///
  /// In en, this message translates to:
  /// **'Show menu'**
  String get fwShowMenu;

  /// Search field label.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get fwSearch;

  /// Clear a text field.
  ///
  /// In en, this message translates to:
  /// **'Clear text'**
  String get fwClearText;

  /// Dismiss a dialog or menu (screen reader).
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get fwDismiss;

  /// A dialog (screen reader).
  ///
  /// In en, this message translates to:
  /// **'Dialog'**
  String get fwDialog;

  /// An alert dialog (screen reader).
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get fwAlert;

  /// A popup menu (screen reader).
  ///
  /// In en, this message translates to:
  /// **'Popup menu'**
  String get fwPopupMenu;

  /// A sheet rising from the bottom (screen reader).
  ///
  /// In en, this message translates to:
  /// **'Bottom sheet'**
  String get fwBottomSheet;

  /// Date picker heading.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get fwSelectDate;

  /// Date picker text field.
  ///
  /// In en, this message translates to:
  /// **'Enter date'**
  String get fwEnterDate;

  /// Date picker format hint.
  ///
  /// In en, this message translates to:
  /// **'dd/mm/yyyy'**
  String get fwDateFormat;

  /// Date picker error.
  ///
  /// In en, this message translates to:
  /// **'Invalid format.'**
  String get fwInvalidDate;

  /// Date picker error.
  ///
  /// In en, this message translates to:
  /// **'Out of range.'**
  String get fwDateOutOfRange;

  /// Date picker mode button.
  ///
  /// In en, this message translates to:
  /// **'Switch to calendar'**
  String get fwToCalendar;

  /// Date picker mode button.
  ///
  /// In en, this message translates to:
  /// **'Switch to input'**
  String get fwToInput;

  /// Date picker tooltip.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get fwNextMonth;

  /// Date picker tooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get fwPreviousMonth;

  /// Date picker (screen reader).
  ///
  /// In en, this message translates to:
  /// **'Select year'**
  String get fwSelectYear;

  /// Today, in a calendar.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get fwToday;

  /// A selected date (screen reader).
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get fwSelected;

  /// Text selection menu.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get fwCopy;

  /// Text selection menu.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get fwCut;

  /// Text selection menu.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get fwPaste;

  /// Text selection menu.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get fwSelectAll;

  /// Expand a folded section (screen reader).
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get fwExpand;

  /// Fold a section (screen reader).
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get fwCollapse;

  /// Refresh (screen reader).
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get fwRefresh;

  /// Month name.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get fwJanuary;

  /// Month name.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get fwFebruary;

  /// Month name.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get fwMarch;

  /// Month name.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get fwApril;

  /// Month name.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get fwMay;

  /// Month name.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get fwJune;

  /// Month name.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get fwJuly;

  /// Month name.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get fwAugust;

  /// Month name.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get fwSeptember;

  /// Month name.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get fwOctober;

  /// Month name.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get fwNovember;

  /// Month name.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get fwDecember;

  /// Weekday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get fwSunday;

  /// Weekday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get fwMonday;

  /// Weekday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get fwTuesday;

  /// Weekday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get fwWednesday;

  /// Weekday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get fwThursday;

  /// Weekday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get fwFriday;

  /// Weekday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get fwSaturday;

  /// The seven weekdays' initials, Sunday first, separated by commas, for a calendar's column heads.
  ///
  /// In en, this message translates to:
  /// **'S,M,T,W,T,F,S'**
  String get fwNarrowWeekdays;

  /// The settings screen's title, and the button that opens it.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Heading of the language choice.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Under the language choice.
  ///
  /// In en, this message translates to:
  /// **'The application changes language at once. Customers, designs, prices and records are not changed.'**
  String get settingsLanguageNote;

  /// Heading of the light or dark choice, and its button's tooltip.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// Follow the device's light or dark setting.
  ///
  /// In en, this message translates to:
  /// **'Match device'**
  String get appearanceSystem;

  /// Light appearance.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// Dark appearance.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// [domain] Design category: a door.
  ///
  /// In en, this message translates to:
  /// **'Door'**
  String get kindDoor;

  /// [domain] Design category: a window.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get kindWindow;

  /// [domain] Design category: doors and windows in one frame.
  ///
  /// In en, this message translates to:
  /// **'Door & window'**
  String get kindBoth;

  /// [domain] Design category: sliding panels.
  ///
  /// In en, this message translates to:
  /// **'Sliding'**
  String get kindSliding;

  /// [domain] Design category: sloped, under-stair and custom shapes.
  ///
  /// In en, this message translates to:
  /// **'Angled / Asymmetrical'**
  String get kindAngled;

  /// [domain] A category this version does not know.
  ///
  /// In en, this message translates to:
  /// **'Unsupported category'**
  String get kindUnsupported;

  /// [domain] A door, in the middle of a sentence.
  ///
  /// In en, this message translates to:
  /// **'door'**
  String get nounDoor;

  /// [domain] A window, in the middle of a sentence.
  ///
  /// In en, this message translates to:
  /// **'window'**
  String get nounWindow;

  /// [domain] A door and window design, in the middle of a sentence.
  ///
  /// In en, this message translates to:
  /// **'door & window'**
  String get nounBoth;

  /// [domain] A sliding design, in the middle of a sentence.
  ///
  /// In en, this message translates to:
  /// **'sliding'**
  String get nounSliding;

  /// [domain] An angled design, in the middle of a sentence.
  ///
  /// In en, this message translates to:
  /// **'angled design'**
  String get nounAngled;

  /// [domain] A design of an unknown category, in the middle of a sentence.
  ///
  /// In en, this message translates to:
  /// **'design of an unsupported category'**
  String get nounUnsupported;

  /// [domain] A design with no name, e.g. 'Untitled window'.
  ///
  /// In en, this message translates to:
  /// **'Untitled {noun}'**
  String untitledDesign(String noun);

  /// [domain] What a door is built of: not said yet.
  ///
  /// In en, this message translates to:
  /// **'Not said'**
  String get constructionPending;

  /// [domain] Built of panel.
  ///
  /// In en, this message translates to:
  /// **'Panel'**
  String get constructionPanel;

  /// [domain] Built of glass.
  ///
  /// In en, this message translates to:
  /// **'Glass'**
  String get constructionGlass;

  /// [domain] Built of panel and glass.
  ///
  /// In en, this message translates to:
  /// **'Panel + glass'**
  String get constructionBoth;

  /// [domain] Material: uPVC profile (kept as the trade name).
  ///
  /// In en, this message translates to:
  /// **'uPVC'**
  String get matUpvc;

  /// [domain] Material: aluminium.
  ///
  /// In en, this message translates to:
  /// **'Aluminium'**
  String get matAluminium;

  /// [domain] Material: wood.
  ///
  /// In en, this message translates to:
  /// **'Wood'**
  String get matWood;

  /// [domain] Material: steel.
  ///
  /// In en, this message translates to:
  /// **'Steel'**
  String get matSteel;

  /// [domain] Material: clear glass.
  ///
  /// In en, this message translates to:
  /// **'Clear glass'**
  String get matClearGlass;

  /// [domain] Material: frosted (obscured) glass.
  ///
  /// In en, this message translates to:
  /// **'Frosted glass'**
  String get matFrostedGlass;

  /// [domain] Material: tinted glass.
  ///
  /// In en, this message translates to:
  /// **'Tinted glass'**
  String get matTintedGlass;

  /// [domain] Material: a solid (opaque) panel.
  ///
  /// In en, this message translates to:
  /// **'Solid panel'**
  String get matPanel;

  /// [domain] Material: louvre slats.
  ///
  /// In en, this message translates to:
  /// **'Louvre'**
  String get matLouvre;

  /// [domain] Material: insect mesh.
  ///
  /// In en, this message translates to:
  /// **'Insect mesh'**
  String get matMesh;

  /// [domain] Material: rubber gasket.
  ///
  /// In en, this message translates to:
  /// **'Rubber gasket'**
  String get matRubber;

  /// [domain] Material class: glass.
  ///
  /// In en, this message translates to:
  /// **'Glass'**
  String get classGlass;

  /// [domain] Material class: panel.
  ///
  /// In en, this message translates to:
  /// **'Panel'**
  String get classPanel;

  /// [domain] Material class: PVC.
  ///
  /// In en, this message translates to:
  /// **'PVC'**
  String get classPvc;

  /// [domain] Material class: aluminium.
  ///
  /// In en, this message translates to:
  /// **'Aluminium'**
  String get classAluminium;

  /// [domain] Material class: wood.
  ///
  /// In en, this message translates to:
  /// **'Wood'**
  String get classWood;

  /// [domain] Material class: rubber.
  ///
  /// In en, this message translates to:
  /// **'Rubber gasket'**
  String get classRubber;

  /// [domain] Material class: metal.
  ///
  /// In en, this message translates to:
  /// **'Metal'**
  String get classMetal;

  /// [domain] Material class: polished metal of a handle.
  ///
  /// In en, this message translates to:
  /// **'Handle metal'**
  String get classHandleMetal;

  /// [domain] Material class: satin metal of a hinge.
  ///
  /// In en, this message translates to:
  /// **'Hinge metal'**
  String get classHingeMetal;

  /// [domain] Material class: mesh.
  ///
  /// In en, this message translates to:
  /// **'Mesh'**
  String get classMesh;

  /// [domain] Colour name.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get colourBlack;

  /// [domain] Colour name.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get colourWhite;

  /// [domain] Colour name.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get colourSilver;

  /// [domain] Colour name.
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get colourGrey;

  /// [domain] Colour name.
  ///
  /// In en, this message translates to:
  /// **'Bronze'**
  String get colourBronze;

  /// [domain] Colour name.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get colourBrown;

  /// [domain] Colour name: a white with a little grey.
  ///
  /// In en, this message translates to:
  /// **'Off white'**
  String get colourOffWhite;

  /// [domain] Colour name.
  ///
  /// In en, this message translates to:
  /// **'Cream'**
  String get colourCream;

  /// [domain] Colour name: a very dark grey.
  ///
  /// In en, this message translates to:
  /// **'Graphite'**
  String get colourGraphite;

  /// [domain] Colour name.
  ///
  /// In en, this message translates to:
  /// **'Deep green'**
  String get colourDeepGreen;

  /// [domain] Colour name.
  ///
  /// In en, this message translates to:
  /// **'Steel blue'**
  String get colourSteelBlue;

  /// [domain] Colour name: the colour of oak wood.
  ///
  /// In en, this message translates to:
  /// **'Oak'**
  String get colourOak;

  /// [domain] Colour name: the colour of walnut wood.
  ///
  /// In en, this message translates to:
  /// **'Walnut'**
  String get colourWalnut;

  /// [domain] Colour name: a deep dark red.
  ///
  /// In en, this message translates to:
  /// **'Oxblood'**
  String get colourOxblood;

  /// [domain] Colour name: the colour of clear glass.
  ///
  /// In en, this message translates to:
  /// **'Clear glass'**
  String get colourClearGlass;

  /// [domain] Colour name: frosted glass.
  ///
  /// In en, this message translates to:
  /// **'Frosted'**
  String get colourFrosted;

  /// [domain] Colour name.
  ///
  /// In en, this message translates to:
  /// **'Warm cream'**
  String get colourWarmCream;

  /// [domain] Glass look: clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get glassClear;

  /// [domain] Glass look: tinted.
  ///
  /// In en, this message translates to:
  /// **'Tinted'**
  String get glassTinted;

  /// [domain] Glass look: frosted.
  ///
  /// In en, this message translates to:
  /// **'Frosted'**
  String get glassFrosted;

  /// [domain] Glass look: dark tinted.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get glassDark;

  /// [domain] Glass look: blue-grey tinted.
  ///
  /// In en, this message translates to:
  /// **'Blue-grey'**
  String get glassBlueGrey;

  /// [domain] How a section opens: it does not.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get mechFixed;

  /// [domain] Explains Fixed.
  ///
  /// In en, this message translates to:
  /// **'Does not open'**
  String get mechFixedHint;

  /// [domain] How a section opens: hinged on the left.
  ///
  /// In en, this message translates to:
  /// **'Hinged left'**
  String get mechHingedLeft;

  /// [domain] Explains Hinged left.
  ///
  /// In en, this message translates to:
  /// **'Hinges on the left, opens from the right'**
  String get mechHingedLeftHint;

  /// [domain] How a section opens: hinged on the right.
  ///
  /// In en, this message translates to:
  /// **'Hinged right'**
  String get mechHingedRight;

  /// [domain] Explains Hinged right.
  ///
  /// In en, this message translates to:
  /// **'Hinges on the right, opens from the left'**
  String get mechHingedRightHint;

  /// [domain] How a section opens: hinged at the top.
  ///
  /// In en, this message translates to:
  /// **'Top hung'**
  String get mechTopHung;

  /// [domain] Explains Top hung.
  ///
  /// In en, this message translates to:
  /// **'Hinges at the top, opens outward at the bottom'**
  String get mechTopHungHint;

  /// [domain] How a section opens: hinged at the bottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom hung'**
  String get mechBottomHung;

  /// [domain] Explains Bottom hung.
  ///
  /// In en, this message translates to:
  /// **'Hinges at the bottom, opens inward at the top'**
  String get mechBottomHungHint;

  /// [domain] How a section opens: slides to the left.
  ///
  /// In en, this message translates to:
  /// **'Sliding left'**
  String get mechSlidingLeft;

  /// [domain] Explains Sliding left.
  ///
  /// In en, this message translates to:
  /// **'Slides to the left'**
  String get mechSlidingLeftHint;

  /// [domain] How a section opens: slides to the right.
  ///
  /// In en, this message translates to:
  /// **'Sliding right'**
  String get mechSlidingRight;

  /// [domain] Explains Sliding right.
  ///
  /// In en, this message translates to:
  /// **'Slides to the right'**
  String get mechSlidingRightHint;

  /// [domain] How a section opens: tilt and turn.
  ///
  /// In en, this message translates to:
  /// **'Tilt and turn'**
  String get mechTiltAndTurn;

  /// [domain] Explains Tilt and turn.
  ///
  /// In en, this message translates to:
  /// **'Tilts at the top and turns on one side'**
  String get mechTiltAndTurnHint;

  /// [domain] How a section opens: folds in leaves.
  ///
  /// In en, this message translates to:
  /// **'Bi-fold'**
  String get mechBifold;

  /// [domain] Explains Bi-fold.
  ///
  /// In en, this message translates to:
  /// **'Folds back in leaves'**
  String get mechBifoldHint;

  /// [domain] How a section opens: turns about a central axis.
  ///
  /// In en, this message translates to:
  /// **'Pivot'**
  String get mechPivot;

  /// [domain] Explains Pivot.
  ///
  /// In en, this message translates to:
  /// **'Turns about a central axis'**
  String get mechPivotHint;

  /// [domain] Ironmongery: a handle.
  ///
  /// In en, this message translates to:
  /// **'Handle'**
  String get hwHandle;

  /// [domain] Ironmongery: a lever handle on a backplate.
  ///
  /// In en, this message translates to:
  /// **'Lever'**
  String get hwLever;

  /// [domain] Ironmongery: a round knob.
  ///
  /// In en, this message translates to:
  /// **'Knob'**
  String get hwKnob;

  /// [domain] Ironmongery: a lock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get hwLock;

  /// [domain] Ironmongery: a hinge.
  ///
  /// In en, this message translates to:
  /// **'Hinge'**
  String get hwHinge;

  /// [domain] Ironmongery: a letter plate.
  ///
  /// In en, this message translates to:
  /// **'Letter plate'**
  String get hwLetterplate;

  /// [domain] Ironmongery: a door viewer.
  ///
  /// In en, this message translates to:
  /// **'Peephole'**
  String get hwPeephole;

  /// [domain] Ironmongery: a door closer.
  ///
  /// In en, this message translates to:
  /// **'Closer'**
  String get hwCloser;

  /// [domain] Ironmongery: the long bar a sliding panel is pulled by.
  ///
  /// In en, this message translates to:
  /// **'Pull handle'**
  String get hwPull;

  /// [domain] A pleated insect screen in a cassette.
  ///
  /// In en, this message translates to:
  /// **'Pleated screen'**
  String get hwScreen;

  /// [domain] The sensor that opens an automatic entrance.
  ///
  /// In en, this message translates to:
  /// **'Sensor'**
  String get hwSensor;

  /// [domain] The frame of the design.
  ///
  /// In en, this message translates to:
  /// **'Frame'**
  String get elFrame;

  /// [domain] A section of the design.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get elSection;

  /// [domain] A note written on the drawing.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get elNote;

  /// [domain] An arrow drawn on the drawing.
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get elArrow;

  /// [domain] An upright line dividing the design.
  ///
  /// In en, this message translates to:
  /// **'Vertical divider'**
  String get elVerticalDivider;

  /// [domain] A level line dividing the design.
  ///
  /// In en, this message translates to:
  /// **'Horizontal divider'**
  String get elHorizontalDivider;

  /// [domain] A sloped line dividing the design.
  ///
  /// In en, this message translates to:
  /// **'Angled divider'**
  String get elAngledDivider;

  /// [domain] Money received from the customer.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payTypePayment;

  /// [domain] Money returned to the customer.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get payTypeRefund;

  /// [domain] Payment method.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get payCash;

  /// [domain] Payment method.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get payBankTransfer;

  /// [domain] Payment method.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get payCard;

  /// [domain] Payment method: another way.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get payOther;

  /// [domain] Payment method of a payment brought over from before the ledger.
  ///
  /// In en, this message translates to:
  /// **'Legacy / unknown'**
  String get payLegacy;

  /// [domain] A payment method described by the user.
  ///
  /// In en, this message translates to:
  /// **'Other — {detail}'**
  String payOtherDetail(String detail);

  /// [domain] A discount as a percentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get discountPercent;

  /// [domain] A discount as a fixed amount of money.
  ///
  /// In en, this message translates to:
  /// **'Fixed amount'**
  String get discountFixed;

  /// [domain] 3D projection as the eye sees it.
  ///
  /// In en, this message translates to:
  /// **'Perspective'**
  String get projectionPerspective;

  /// [domain] 3D projection keeping parallel edges parallel.
  ///
  /// In en, this message translates to:
  /// **'Orthographic'**
  String get projectionParallel;

  /// [domain] Price group: the frame's border and the lines inside the design.
  ///
  /// In en, this message translates to:
  /// **'Border and internal lines'**
  String get groupNormalProfile;

  /// [domain] Price group: the profile round each opening.
  ///
  /// In en, this message translates to:
  /// **'Opening profile'**
  String get groupOpeningProfile;

  /// [domain] Price group: other profile by the metre, a sliding track.
  ///
  /// In en, this message translates to:
  /// **'Other profile'**
  String get groupOtherProfile;

  /// [domain] Price group: what a colour adds.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get groupColour;

  /// [domain] Price group: glass.
  ///
  /// In en, this message translates to:
  /// **'Glass'**
  String get groupGlass;

  /// [domain] Price group: panel.
  ///
  /// In en, this message translates to:
  /// **'Panel'**
  String get groupPanel;

  /// [domain] Price group: handles, hinges, locks.
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get groupHardware;

  /// [domain] Price group: labour.
  ///
  /// In en, this message translates to:
  /// **'Labour'**
  String get groupLabour;

  /// [domain] Price group: installation.
  ///
  /// In en, this message translates to:
  /// **'Installation'**
  String get groupInstallation;

  /// [domain] Price unit: counted by the piece.
  ///
  /// In en, this message translates to:
  /// **'each'**
  String get unitEach;

  /// [domain] Glass row: the design has glass, not included in the price.
  ///
  /// In en, this message translates to:
  /// **'Not included'**
  String get glassNotIncluded;

  /// [domain] Glass row: included, but no glass to charge.
  ///
  /// In en, this message translates to:
  /// **'No measurable glass to price'**
  String get glassNothingToCharge;

  /// [domain] A material the design does not use.
  ///
  /// In en, this message translates to:
  /// **'Not used'**
  String get glassNotUsed;

  /// [domain] Aluminium profile category: System Aluminium.
  ///
  /// In en, this message translates to:
  /// **'System Aluminium'**
  String get catSystemAluminium;

  /// [domain] Aluminium profile category: Bend Shoulder Aluminium (product term, kept in English pending review).
  ///
  /// In en, this message translates to:
  /// **'Bend Shoulder Aluminium'**
  String get catBendShoulderAluminium;

  /// [domain] The frame's border profile.
  ///
  /// In en, this message translates to:
  /// **'Border'**
  String get partBorder;

  /// [domain] The lines inside the design, cut from the same profile.
  ///
  /// In en, this message translates to:
  /// **'Internal lines'**
  String get partLines;

  /// How many designs a customer has.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No designs yet} =1{1 design} other{{count} designs}}'**
  String designsCount(int count);

  /// Customers screen, for somebody not allowed to see them.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to view customers.'**
  String get customersNoAccess;

  /// Heading over the list of customers.
  ///
  /// In en, this message translates to:
  /// **'All Customers'**
  String get customersAll;

  /// Heading over the customers a search found.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get customersResults;

  /// Button: add a customer.
  ///
  /// In en, this message translates to:
  /// **'New Customer'**
  String get newCustomer;

  /// Button: begin a new design.
  ///
  /// In en, this message translates to:
  /// **'New Design'**
  String get newDesign;

  /// The product's name in capitals over the customers' heading; a name, not translated.
  ///
  /// In en, this message translates to:
  /// **'PROFRAME'**
  String get brandWordmark;

  /// The customers screen's title.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customersTitle;

  /// Under the title when there are no customers.
  ///
  /// In en, this message translates to:
  /// **'Everyone you draw for is kept here.'**
  String get customersEmptyLine;

  /// How many customers are kept.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 customer} other{{count} customers}}'**
  String customersCount(int count);

  /// Hint in the customers' search field.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone...'**
  String get customersSearchHint;

  /// Tooltip: empty the search field.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// A customer card with no phone number.
  ///
  /// In en, this message translates to:
  /// **'No phone number'**
  String get noPhoneNumber;

  /// Empty customers list heading.
  ///
  /// In en, this message translates to:
  /// **'No customers yet'**
  String get customersNoneYet;

  /// Empty customers list explanation.
  ///
  /// In en, this message translates to:
  /// **'Add the people you draw for, and keep their designs together.'**
  String get customersNoneYetLine;

  /// A search that found nobody.
  ///
  /// In en, this message translates to:
  /// **'No customer matches \"{query}\".'**
  String customersNoMatch(String query);

  /// [domain] An opening (a part of the design that opens) by its number across the drawing.
  ///
  /// In en, this message translates to:
  /// **'Opening {number}'**
  String openingNumbered(int number);

  /// [domain] An opening, where it has no number.
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get openingAlone;

  /// [domain] The opening, in a sentence.
  ///
  /// In en, this message translates to:
  /// **'the opening'**
  String get openingThe;

  /// [domain] A part of the design, in a sentence.
  ///
  /// In en, this message translates to:
  /// **'a part'**
  String get partA;

  /// [domain] The top member of a frame.
  ///
  /// In en, this message translates to:
  /// **'Head'**
  String get placeHead;

  /// [domain] The bottom member of a frame.
  ///
  /// In en, this message translates to:
  /// **'Sill'**
  String get placeSill;

  /// [domain] The left upright member of a frame.
  ///
  /// In en, this message translates to:
  /// **'Left jamb'**
  String get placeLeftJamb;

  /// [domain] The right upright member of a frame.
  ///
  /// In en, this message translates to:
  /// **'Right jamb'**
  String get placeRightJamb;

  /// [domain] A sloping side of a frame, upper left.
  ///
  /// In en, this message translates to:
  /// **'Raking upper left side'**
  String get placeRakingUpperLeft;

  /// [domain] A sloping side of a frame, upper right.
  ///
  /// In en, this message translates to:
  /// **'Raking upper right side'**
  String get placeRakingUpperRight;

  /// [domain] A sloping side of a frame, lower left.
  ///
  /// In en, this message translates to:
  /// **'Raking lower left side'**
  String get placeRakingLowerLeft;

  /// [domain] A sloping side of a frame, lower right.
  ///
  /// In en, this message translates to:
  /// **'Raking lower right side'**
  String get placeRakingLowerRight;

  /// [domain] A line of the design by its number.
  ///
  /// In en, this message translates to:
  /// **'Line {n}'**
  String lineNumbered(int n);

  /// [domain] A line drawn inside an opening.
  ///
  /// In en, this message translates to:
  /// **'Line {n} (inside {opening})'**
  String lineInside(int n, String opening);

  /// [domain] Size: the width of the frame's border profile.
  ///
  /// In en, this message translates to:
  /// **'Frame border'**
  String get measFrameBorder;

  /// [domain] Size: the thickness of the lines dividing the design.
  ///
  /// In en, this message translates to:
  /// **'Bar thickness'**
  String get measBarThickness;

  /// [domain] Size: the whole design's width.
  ///
  /// In en, this message translates to:
  /// **'Overall width'**
  String get measOverallWidth;

  /// [domain] Size: the whole design's height.
  ///
  /// In en, this message translates to:
  /// **'Overall height'**
  String get measOverallHeight;

  /// [domain] A width.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get axisWidth;

  /// [domain] A height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get axisHeight;

  /// [domain] A part of the design that does not open, by its number.
  ///
  /// In en, this message translates to:
  /// **'Fixed light {n}'**
  String measFixedLight(int n);

  /// [domain] A pane inside a part: the part, what fills the pane, and its number.
  ///
  /// In en, this message translates to:
  /// **'{around} — {material} {n}'**
  String measPane(String around, String material, int n);

  /// [domain] The height of one side of an angled frame.
  ///
  /// In en, this message translates to:
  /// **'{side} height'**
  String sideHeight(String side);

  /// [domain] The width of one side of an angled frame.
  ///
  /// In en, this message translates to:
  /// **'{side} width'**
  String sideWidth(String side);

  /// [domain] Two things joined: a and b.
  ///
  /// In en, this message translates to:
  /// **'{a} and {b}'**
  String joinAnd(String a, String b);

  /// [domain] Two things offered: a or b.
  ///
  /// In en, this message translates to:
  /// **'{a} or {b}'**
  String joinOr(String a, String b);

  /// [domain] Why a design cannot be priced.
  ///
  /// In en, this message translates to:
  /// **'This design\'s category is not supported by this version of ProFrame, so its price is unavailable.'**
  String get reqUnsupported;

  /// [domain] Why a design cannot be priced: lines drawn since the last reading.
  ///
  /// In en, this message translates to:
  /// **'The drawing has changes that have not been read. Please Read the drawing before calculating the price.'**
  String get reqNotRead;

  /// [domain] Why a design cannot be priced.
  ///
  /// In en, this message translates to:
  /// **'Please complete the outer frame to calculate the price.'**
  String get reqFrame;

  /// [domain] Why a design cannot be priced.
  ///
  /// In en, this message translates to:
  /// **'Please draw the design to calculate the price.'**
  String get reqDraw;

  /// [domain] Why a design cannot be priced, with the geometry problem.
  ///
  /// In en, this message translates to:
  /// **'Please correct the geometry to calculate the price: {problem}'**
  String reqGeometry(String problem);

  /// [domain] Why a door cannot be priced.
  ///
  /// In en, this message translates to:
  /// **'Please choose what the door is built of — panel, glass or both — to calculate the price.'**
  String get reqConstruction;

  /// [domain] Why a design cannot be priced.
  ///
  /// In en, this message translates to:
  /// **'Please complete the panel/glass selection to calculate the price.'**
  String get reqPanelOrGlass;

  /// [domain] Why a design cannot be priced.
  ///
  /// In en, this message translates to:
  /// **'Please say whether {opening} is a door or a window to calculate the price.'**
  String reqOpeningKind(String opening);

  /// [domain] Why a design cannot be priced: sizes of the frame not given.
  ///
  /// In en, this message translates to:
  /// **'Please give the {which} to calculate the price.'**
  String reqFrameSizes(String which);

  /// [domain] Why a design cannot be priced: sizes of one part not given.
  ///
  /// In en, this message translates to:
  /// **'Please complete the dimensions of {group} (its {which}) to calculate the price.'**
  String reqGroupSizes(String group, String which);

  /// [domain] Why a design cannot be priced.
  ///
  /// In en, this message translates to:
  /// **'Please choose the material and colour of the profile to calculate the price.'**
  String get reqProfile;

  /// [domain] Why an aluminium design cannot be priced: no profile category chosen.
  ///
  /// In en, this message translates to:
  /// **'Please choose whether the {material} profile is {choices} to calculate the price.'**
  String reqCategoryAll(String material, String choices);

  /// [domain] Why an aluminium design cannot be priced: some parts have no category.
  ///
  /// In en, this message translates to:
  /// **'Please choose {choices} for {parts} to calculate the price.'**
  String reqCategorySome(String choices, String parts);

  /// [domain] The first missing thing, and how many more (one).
  ///
  /// In en, this message translates to:
  /// **'{first} {more} more thing needs completing too.'**
  String readinessMoreOne(String first, int more);

  /// [domain] The first missing thing, and how many more (several).
  ///
  /// In en, this message translates to:
  /// **'{first} {more} more things need completing too.'**
  String readinessMoreMany(String first, int more);

  /// [domain] Why a design cannot be measured.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been drawn yet.'**
  String get takeoffNothing;

  /// [domain] Why a design cannot be measured.
  ///
  /// In en, this message translates to:
  /// **'The outline cannot be measured.'**
  String get takeoffOutline;

  /// [domain] Why a design cannot be measured.
  ///
  /// In en, this message translates to:
  /// **'The design has no width or no height.'**
  String get takeoffNoSize;

  /// [domain] The chosen colour is not sold in this material.
  ///
  /// In en, this message translates to:
  /// **'Please select a colour available for {material}.'**
  String colourNotForMaterial(String material);

  /// [domain] The price list has no rate for this colour on this material.
  ///
  /// In en, this message translates to:
  /// **'Colour pricing is not configured for {material}.'**
  String colourNotConfigured(String material);

  /// [domain] The chosen colour is retired or unknown.
  ///
  /// In en, this message translates to:
  /// **'Colour pricing unavailable — please select an active colour.'**
  String get colourUnavailable;

  /// [domain] The price list has no price for this material.
  ///
  /// In en, this message translates to:
  /// **'The price list has no price for {material} profile.'**
  String colourNoProfile(String material);

  /// [domain] A colour the factory stocks as standard.
  ///
  /// In en, this message translates to:
  /// **'Standard colour'**
  String get gradeStandard;

  /// [domain] A colour the factory sells at a surcharge.
  ///
  /// In en, this message translates to:
  /// **'Non-standard colour'**
  String get gradeNonStandard;

  /// [domain] A colour the price list does not name.
  ///
  /// In en, this message translates to:
  /// **'Special colour'**
  String get gradeSpecial;

  /// [domain] Why a design cannot be priced.
  ///
  /// In en, this message translates to:
  /// **'This version of ProFrame cannot price a design of this category.'**
  String get engineUnsupported;

  /// [domain] Why a design cannot be priced.
  ///
  /// In en, this message translates to:
  /// **'The price list has no prices for {kind} designs.'**
  String engineNoCategory(String kind);

  /// [domain] Something the price list has no rate for.
  ///
  /// In en, this message translates to:
  /// **'The price list has no price for {what}.'**
  String engineMissing(String what);

  /// [domain] An extra charge in another currency than the price list's.
  ///
  /// In en, this message translates to:
  /// **'The extra charge \"{name}\" is in {currency}, and this design is priced in {listCurrency}. Write it in {listCurrency}.'**
  String engineExtraCurrency(String name, String currency, String listCurrency);

  /// [domain] What the price list lacks: a material's profile.
  ///
  /// In en, this message translates to:
  /// **'{material} profile'**
  String missProfile(String material);

  /// [domain] What the price list lacks: border and lines of a material or category.
  ///
  /// In en, this message translates to:
  /// **'{what} border and lines'**
  String missBorderLines(String what);

  /// [domain] What the price list lacks: an infill material.
  ///
  /// In en, this message translates to:
  /// **'{material} infill'**
  String missInfill(String material);

  /// [domain] What the price list lacks: a piece of ironmongery.
  ///
  /// In en, this message translates to:
  /// **'a {piece}'**
  String missPiece(String piece);

  /// [domain] A colour or glass of the user's own, not one of the named ones.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// [domain] Nothing chosen yet.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get notSelected;

  /// [domain] A price line: a material or category, and border or internal lines.
  ///
  /// In en, this message translates to:
  /// **'{what} — {part}'**
  String lineProfile(String what, String part);

  /// [domain] A price line: the opening profile of a material.
  ///
  /// In en, this message translates to:
  /// **'Opening profile — {material}'**
  String lineOpeningProfile(String material);

  /// [domain] A price line: what a colour adds to a material's profile.
  ///
  /// In en, this message translates to:
  /// **'{colour} {material} ({grade})'**
  String lineColour(String colour, String material, String grade);

  /// [domain] A price line: the track sliding panels run on.
  ///
  /// In en, this message translates to:
  /// **'Sliding track'**
  String get lineTrack;

  /// [domain] A price line: glass of a look.
  ///
  /// In en, this message translates to:
  /// **'{look} glass'**
  String lineGlass(String look);

  /// [domain] A price line: a sealed double-glazed unit.
  ///
  /// In en, this message translates to:
  /// **'Sealed unit — {glass}'**
  String lineSealed(String glass);

  /// [domain] A price line: a panel of a colour.
  ///
  /// In en, this message translates to:
  /// **'{colour} panel'**
  String linePanel(String colour);

  /// [domain] A price line: several pieces of ironmongery (English adds an s).
  ///
  /// In en, this message translates to:
  /// **'{piece}s'**
  String linePieces(String piece);

  /// [domain] A price line: the rollers sliding panels run on.
  ///
  /// In en, this message translates to:
  /// **'Rollers'**
  String get lineRollers;

  /// [domain] A price line: the labour of making.
  ///
  /// In en, this message translates to:
  /// **'Making'**
  String get lineMaking;

  /// [domain] A price line: labour priced by area.
  ///
  /// In en, this message translates to:
  /// **'Making, by area'**
  String get lineMakingArea;

  /// [domain] A price line: labour as a share of the materials.
  ///
  /// In en, this message translates to:
  /// **'Making, on materials'**
  String get lineMakingMaterials;

  /// [domain] A price line: installation.
  ///
  /// In en, this message translates to:
  /// **'Installation'**
  String get lineInstallation;

  /// [domain] A price line: installation by area.
  ///
  /// In en, this message translates to:
  /// **'Installation, by area'**
  String get lineInstallationArea;

  /// [domain] A design's card: lines drawn and not read.
  ///
  /// In en, this message translates to:
  /// **'Drawing not read'**
  String get stateNotRead;

  /// [domain] A design that can be priced.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get stateComplete;

  /// [domain] A design that cannot be priced yet.
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get stateIncomplete;

  /// [domain] Where the price would be.
  ///
  /// In en, this message translates to:
  /// **'Price unavailable until drawing is read'**
  String get noteNotRead;

  /// [domain] Where the price would be.
  ///
  /// In en, this message translates to:
  /// **'Not calculated yet'**
  String get noteNotCalculated;

  /// [domain] Where the price would be: the design or prices changed.
  ///
  /// In en, this message translates to:
  /// **'Price needs recalculation'**
  String get noteRecalculate;

  /// [domain] Where the price would be.
  ///
  /// In en, this message translates to:
  /// **'Price unavailable until design is completed'**
  String get noteIncomplete;

  /// [domain] Where the price would be.
  ///
  /// In en, this message translates to:
  /// **'Price unavailable'**
  String get noteUnavailable;

  /// [domain] Why the kept price is not current.
  ///
  /// In en, this message translates to:
  /// **'The design or the prices changed since this price was calculated. Calculate it again.'**
  String get msgRecalculate;

  /// [domain] A design that can be priced and has not been.
  ///
  /// In en, this message translates to:
  /// **'Calculate the price.'**
  String get msgCalculate;

  /// [domain] Why a design of an unknown category has no price.
  ///
  /// In en, this message translates to:
  /// **'Unsupported category. Price unavailable.'**
  String get reasonUnsupported;

  /// [domain] Why a design has no price.
  ///
  /// In en, this message translates to:
  /// **'The price list cannot price this design.'**
  String get reasonListCannot;

  /// [domain] Geometry check: a part with no name.
  ///
  /// In en, this message translates to:
  /// **'part of the design'**
  String get gfPartOfDesign;

  /// [domain] Geometry check: the frame.
  ///
  /// In en, this message translates to:
  /// **'the frame'**
  String get gfFrame;

  /// [domain] Geometry check: one side of the frame.
  ///
  /// In en, this message translates to:
  /// **'the {member} of the frame'**
  String gfMemberOfFrame(String member);

  /// [domain] Geometry check: a line inside an opening or a light.
  ///
  /// In en, this message translates to:
  /// **'a line inside {parent}'**
  String gfLineInside(String parent);

  /// [domain] Geometry check: a line dividing the design.
  ///
  /// In en, this message translates to:
  /// **'a bar'**
  String get gfBar;

  /// [domain] Geometry check: an upright dividing line.
  ///
  /// In en, this message translates to:
  /// **'a mullion'**
  String get gfMullion;

  /// [domain] Geometry check: a level dividing line.
  ///
  /// In en, this message translates to:
  /// **'a transom'**
  String get gfTransom;

  /// [domain] Geometry check: a sloping dividing line.
  ///
  /// In en, this message translates to:
  /// **'a sloped bar'**
  String get gfSlopedBar;

  /// [domain] Geometry check: a pane inside an opening.
  ///
  /// In en, this message translates to:
  /// **'a pane of {parent}'**
  String gfPaneOf(String parent);

  /// [domain] Geometry check: the region an opening fills.
  ///
  /// In en, this message translates to:
  /// **'the region of {opening}'**
  String gfRegionOf(String opening);

  /// [domain] Geometry check: a part that does not open.
  ///
  /// In en, this message translates to:
  /// **'a fixed light'**
  String get gfFixedLight;

  /// [domain] Geometry check: a piece of ironmongery of an opening.
  ///
  /// In en, this message translates to:
  /// **'a {piece} of {opening}'**
  String gfPieceOf(String piece, String opening);

  /// [domain] Geometry check: a piece of ironmongery.
  ///
  /// In en, this message translates to:
  /// **'a {piece}'**
  String gfPiece(String piece);

  /// [domain] Geometry check: a dimension the user stated.
  ///
  /// In en, this message translates to:
  /// **'the dimension you gave as {size}'**
  String gfDimensionGiven(String size);

  /// [domain] Geometry check: a dimension.
  ///
  /// In en, this message translates to:
  /// **'a dimension'**
  String get gfDimension;

  /// [domain] Geometry check: a note.
  ///
  /// In en, this message translates to:
  /// **'a note'**
  String get gfNote;

  /// [domain] Geometry check: an arrow.
  ///
  /// In en, this message translates to:
  /// **'an arrow'**
  String get gfArrow;

  /// [domain] Geometry check: the light a child belongs to.
  ///
  /// In en, this message translates to:
  /// **'the light it belongs to'**
  String get gfLightItBelongsTo;

  /// [domain] Geometry check: the part a child belongs to.
  ///
  /// In en, this message translates to:
  /// **'the part it belongs to'**
  String get gfPartItBelongsTo;

  /// [domain] Geometry check message.
  ///
  /// In en, this message translates to:
  /// **'{name} has a point that is not a number, so it cannot be placed.'**
  String gfNotANumber(String name);

  /// [domain] Geometry check message.
  ///
  /// In en, this message translates to:
  /// **'The frame\'s outline does not enclose a shape.'**
  String get gfFrameEnclosesNothing;

  /// [domain] Geometry check message.
  ///
  /// In en, this message translates to:
  /// **'{name} encloses no area.'**
  String gfEnclosesNothing(String name);

  /// [domain] Geometry check message.
  ///
  /// In en, this message translates to:
  /// **'Two sides of the frame cross each other.'**
  String get gfSidesCross;

  /// [domain] Geometry check message: two named sides cross.
  ///
  /// In en, this message translates to:
  /// **'The {first} of the frame crosses the {second}.'**
  String gfSideCrosses(String first, String second);

  /// [domain] Geometry check message.
  ///
  /// In en, this message translates to:
  /// **'The frame\'s outline touches itself.'**
  String get gfFrameTouchesItself;

  /// [domain] Geometry check message.
  ///
  /// In en, this message translates to:
  /// **'{name} crosses itself.'**
  String gfCrossesItself(String name);

  /// [domain] Geometry check message.
  ///
  /// In en, this message translates to:
  /// **'{name} is not connected to the frame or to another bar.'**
  String gfNotConnected(String name);

  /// [domain] Geometry check message.
  ///
  /// In en, this message translates to:
  /// **'{name} lies outside the frame.'**
  String gfOutsideFrame(String name);

  /// [domain] Geometry check message: a hinge or handle off the leaf it belongs to.
  ///
  /// In en, this message translates to:
  /// **'{name} is not on its leaf.'**
  String gfNotOnLeaf(String name);

  /// [domain] Geometry check message.
  ///
  /// In en, this message translates to:
  /// **'{name} lies outside {within}.'**
  String gfLiesOutside(String name, String within);

  /// [domain] Geometry check message.
  ///
  /// In en, this message translates to:
  /// **'{name} reaches outside {within}.'**
  String gfReachesOutside(String name, String within);

  /// [domain] Geometry check message.
  ///
  /// In en, this message translates to:
  /// **'{name} has lost the region it opens.'**
  String gfLostRegion(String name);

  /// [domain] Geometry check message.
  ///
  /// In en, this message translates to:
  /// **'The mark of {name} is outside the region it opens.'**
  String gfMarkOutside(String name);

  /// [domain] Geometry check message.
  ///
  /// In en, this message translates to:
  /// **'A dimension measures nothing: its two ends are at the same point.'**
  String get gfDimensionNothing;

  /// [domain] Geometry check message.
  ///
  /// In en, this message translates to:
  /// **'A dimension gives {size}, which is not a size.'**
  String gfDimensionNotSize(String size);

  /// [domain] Geometry check message.
  ///
  /// In en, this message translates to:
  /// **'The dimension you gave as {stated} no longer matches the drawing, which measures {measured}.'**
  String gfDimensionDisagrees(String stated, String measured);

  /// [domain] Geometry check message.
  ///
  /// In en, this message translates to:
  /// **'A dimension does not match the drawing.'**
  String get gfDimensionMismatch;

  /// [domain] Heading of the geometry check where there is an error.
  ///
  /// In en, this message translates to:
  /// **'Geometry needs attention'**
  String get gfTitleAttention;

  /// [domain] Heading of the geometry check where there are only warnings.
  ///
  /// In en, this message translates to:
  /// **'Geometry may need review'**
  String get gfTitleReview;

  /// [domain] Under the geometry check heading where there is an error.
  ///
  /// In en, this message translates to:
  /// **'Part of this design cannot be built as it is drawn. Nothing has been changed for you — put it right on your drawing.'**
  String get gfSummaryError;

  /// [domain] Under the geometry check heading where there are only warnings.
  ///
  /// In en, this message translates to:
  /// **'This design can be built, but something in it may not be what you meant. Nothing has been changed for you.'**
  String get gfSummaryWarning;

  /// [domain] Why a customer's total is not final.
  ///
  /// In en, this message translates to:
  /// **'1 design is incomplete'**
  String get whyIncompleteOne;

  /// [domain] Why a customer's total is not final.
  ///
  /// In en, this message translates to:
  /// **'{n} designs are incomplete'**
  String whyIncompleteMany(int n);

  /// [domain] Why a customer's total is not final.
  ///
  /// In en, this message translates to:
  /// **'1 design cannot be priced'**
  String get whyCannotOne;

  /// [domain] Why a customer's total is not final.
  ///
  /// In en, this message translates to:
  /// **'{n} designs cannot be priced'**
  String whyCannotMany(int n);

  /// [domain] Why a customer's total is not final.
  ///
  /// In en, this message translates to:
  /// **'1 design needs its price calculated'**
  String get whyCalculateOne;

  /// [domain] Why a customer's total is not final.
  ///
  /// In en, this message translates to:
  /// **'{n} designs need their prices calculated'**
  String whyCalculateMany(int n);

  /// [domain] What separates items in a list, with its space.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get listComma;

  /// [domain] The full stop that ends a sentence.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get sentenceStop;

  /// [domain] Why a customer's total is not final: an extra in another currency.
  ///
  /// In en, this message translates to:
  /// **'An extra charge is in {currencies}, not {currency}.'**
  String whyExtraOne(String currencies, String currency);

  /// [domain] Why a customer's total is not final: extras in another currency.
  ///
  /// In en, this message translates to:
  /// **'{n} extra charges are in {currencies}, not {currency}.'**
  String whyExtraMany(int n, String currencies, String currency);

  /// [domain] A customer's money: nothing to pay.
  ///
  /// In en, this message translates to:
  /// **'Nothing to pay'**
  String get payNothingToPay;

  /// [domain] A customer's money: the total is not final yet.
  ///
  /// In en, this message translates to:
  /// **'Pricing incomplete'**
  String get payPricingIncomplete;

  /// [domain] A customer's money: some is still due.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get payOutstanding;

  /// [domain] A customer's money: all paid.
  ///
  /// In en, this message translates to:
  /// **'Paid in full'**
  String get payPaidInFull;

  /// [domain] A customer's money: paid more than the total; the customer has credit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get payCredit;

  /// Asked before a customer is deleted.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteCustomerTitle(String name);

  /// Explains deleting a customer.
  ///
  /// In en, this message translates to:
  /// **'Only a customer with nothing of theirs kept can be deleted: no designs, payments, receipts, discounts, quotations or extra charges. Their record is then removed, and nothing else.'**
  String get deleteCustomerBody;

  /// Button and menu item: delete this customer.
  ///
  /// In en, this message translates to:
  /// **'Delete customer'**
  String get deleteCustomer;

  /// Heading when a customer could not be deleted.
  ///
  /// In en, this message translates to:
  /// **'Not deleted'**
  String get notDeleted;

  /// Notice after a customer is deleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted.'**
  String customerDeleted(String name);

  /// Undo the last action.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// Notice after a design is duplicated.
  ///
  /// In en, this message translates to:
  /// **'Copy made: {name}'**
  String copyMade(String name);

  /// For somebody not allowed to see designs.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to view designs.'**
  String get designsNoAccess;

  /// A customer page whose customer has been removed.
  ///
  /// In en, this message translates to:
  /// **'This customer is no longer kept.'**
  String get customerGone;

  /// A customer detail left empty.
  ///
  /// In en, this message translates to:
  /// **'Not given'**
  String get notGiven;

  /// Under a customer's name on their page.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Customer · no designs yet} =1{Customer · 1 design} other{Customer · {count} designs}}'**
  String customerSubtitle(int count);

  /// Heading of a customer's details.
  ///
  /// In en, this message translates to:
  /// **'Customer information'**
  String get customerInformation;

  /// Button: edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// A customer's phone number.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// A customer's address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// Notes about a customer.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Heading of a customer's designs.
  ///
  /// In en, this message translates to:
  /// **'Designs'**
  String get designsTitle;

  /// How many designs a search or filter shows, of all.
  ///
  /// In en, this message translates to:
  /// **'{found} of {count}'**
  String foundOf(int found, int count);

  /// Hint in the designs' search field.
  ///
  /// In en, this message translates to:
  /// **'Search designs by name...'**
  String get searchDesignsHint;

  /// Filter chip: every category.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// A search, quoted.
  ///
  /// In en, this message translates to:
  /// **'“{query}”'**
  String quoted(String query);

  /// A filter by category.
  ///
  /// In en, this message translates to:
  /// **'in {category}'**
  String inCategory(String category);

  /// A search or filter that found nothing.
  ///
  /// In en, this message translates to:
  /// **'No designs match {what}'**
  String noDesignsMatch(String what);

  /// Under a search that found nothing.
  ///
  /// In en, this message translates to:
  /// **'Search by the design\'s name, or choose another category.'**
  String get noDesignsMatchHint;

  /// Button: clear the search and filter.
  ///
  /// In en, this message translates to:
  /// **'Show all designs'**
  String get showAllDesigns;

  /// A customer with no designs.
  ///
  /// In en, this message translates to:
  /// **'No designs yet'**
  String get noDesignsYet;

  /// A customer with no designs.
  ///
  /// In en, this message translates to:
  /// **'Begin {name}\'s first door, window or sliding set.'**
  String beginFirstDesign(String name);

  /// When a design was last edited: today.
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String todayAt(String time);

  /// When a design was last edited: yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String yesterdayAt(String time);

  /// When a design was last edited: a date and a time.
  ///
  /// In en, this message translates to:
  /// **'{day} {month} {year}, {time}'**
  String dateAt(int day, String month, int year, String time);

  /// Tooltip of the three-dot menu.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// When a design was last edited.
  ///
  /// In en, this message translates to:
  /// **'Last edited: {when}'**
  String lastEdited(String when);

  /// Button: change a design's name.
  ///
  /// In en, this message translates to:
  /// **'Edit information'**
  String get editInformation;

  /// Button: open a design.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// A design the user completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get stageCompleted;

  /// A design ready but not completed.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get stageDraft;

  /// Label: what the profile is made of.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get labelMaterial;

  /// Label: the profile's colour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get labelColour;

  /// A label followed by its value.
  ///
  /// In en, this message translates to:
  /// **'{label}: '**
  String labelled(String label);

  /// A design's card, for somebody not allowed to see prices.
  ///
  /// In en, this message translates to:
  /// **'Price: hidden'**
  String get priceHidden;

  /// A design's card while its price is read.
  ///
  /// In en, this message translates to:
  /// **'Price: …'**
  String get priceLoading;

  /// A design's card: its price.
  ///
  /// In en, this message translates to:
  /// **'Price: {amount}'**
  String priceIs(String amount);

  /// A design's card: drawn on since it was read.
  ///
  /// In en, this message translates to:
  /// **'Price: needs update'**
  String get priceNeedsUpdate;

  /// A design's card: a colour to choose again.
  ///
  /// In en, this message translates to:
  /// **'Price: choose colour'**
  String get priceChooseColour;

  /// A design's card: the aluminium profile category to choose.
  ///
  /// In en, this message translates to:
  /// **'Price: choose profile'**
  String get priceChooseProfile;

  /// A design's card: the material to choose.
  ///
  /// In en, this message translates to:
  /// **'Price: choose material'**
  String get priceChooseMaterial;

  /// A design's card.
  ///
  /// In en, this message translates to:
  /// **'Price: not calculated'**
  String get priceNotCalculated;

  /// A design's card: the kept price is not current.
  ///
  /// In en, this message translates to:
  /// **'Price: recalculate'**
  String get priceRecalculate;

  /// A design's card.
  ///
  /// In en, this message translates to:
  /// **'Price: unavailable'**
  String get priceUnavailable;

  /// Button: see or calculate a design's price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// The twelve months as a date on a card writes them, January first, separated by commas.
  ///
  /// In en, this message translates to:
  /// **'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec'**
  String get fwShortMonths;

  /// [domain] Permission group.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get capGroupCustomers;

  /// [domain] Permission group.
  ///
  /// In en, this message translates to:
  /// **'Designs'**
  String get capGroupDesigns;

  /// [domain] Permission group.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get capGroupPricing;

  /// [domain] Permission group.
  ///
  /// In en, this message translates to:
  /// **'Customer finances'**
  String get capGroupFinances;

  /// [domain] Permission group.
  ///
  /// In en, this message translates to:
  /// **'Discounts'**
  String get capGroupDiscounts;

  /// [domain] Permission group.
  ///
  /// In en, this message translates to:
  /// **'Quotations'**
  String get capGroupQuotations;

  /// [domain] Permission group.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get capGroupPayments;

  /// [domain] Permission group.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get capGroupReceipts;

  /// [domain] Permission group.
  ///
  /// In en, this message translates to:
  /// **'Extra charges'**
  String get capGroupExtras;

  /// [domain] Permission group.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get capGroupStaff;

  /// [domain] Permission: view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get capView;

  /// [domain] Permission: add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get capAdd;

  /// [domain] Permission: edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get capEdit;

  /// [domain] Permission: delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get capDelete;

  /// [domain] Permission: create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get capCreate;

  /// [domain] Permission: edit and draw designs.
  ///
  /// In en, this message translates to:
  /// **'Edit and draw'**
  String get capEditAndDraw;

  /// [domain] Permission.
  ///
  /// In en, this message translates to:
  /// **'View prices'**
  String get capViewPrices;

  /// [domain] Permission.
  ///
  /// In en, this message translates to:
  /// **'Edit factory prices'**
  String get capEditFactoryPrices;

  /// [domain] Permission: see a customer's financial summary.
  ///
  /// In en, this message translates to:
  /// **'View summary'**
  String get capViewSummary;

  /// [domain] Permission: give and change discounts.
  ///
  /// In en, this message translates to:
  /// **'Apply and change'**
  String get capApplyAndChange;

  /// [domain] Permission: change a quotation's status.
  ///
  /// In en, this message translates to:
  /// **'Change status'**
  String get capChangeStatus;

  /// [domain] Permission: see the payment history.
  ///
  /// In en, this message translates to:
  /// **'View history'**
  String get capViewHistory;

  /// [domain] Permission.
  ///
  /// In en, this message translates to:
  /// **'Record payments'**
  String get capRecordPayments;

  /// [domain] Permission.
  ///
  /// In en, this message translates to:
  /// **'Record refunds'**
  String get capRecordRefunds;

  /// [domain] Permission: issue receipts.
  ///
  /// In en, this message translates to:
  /// **'Issue'**
  String get capIssue;

  /// [domain] Permission: remove extra charges.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get capRemove;

  /// [domain] Permission.
  ///
  /// In en, this message translates to:
  /// **'Add and edit staff'**
  String get capAddEditStaff;

  /// [domain] Permission.
  ///
  /// In en, this message translates to:
  /// **'Change permissions'**
  String get capChangePermissions;

  /// [domain] Who is signed in: the workshop's owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// [domain] Who is at the device: staff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get roleStaff;

  /// [domain] Who is at the device: nobody signed in.
  ///
  /// In en, this message translates to:
  /// **'Nobody signed in'**
  String get roleNobody;

  /// [domain] Refusal: somebody else tried to change the price list.
  ///
  /// In en, this message translates to:
  /// **'Only the owner can change the price list (asked by {who}).'**
  String deniedPriceList(String who);

  /// [domain] Refusal: a permission somebody does not hold. The key is the permission's code.
  ///
  /// In en, this message translates to:
  /// **'{who} does not have permission to {action} ({key}).'**
  String deniedAction(String who, String action, String key);

  /// [domain] A customer that has been removed.
  ///
  /// In en, this message translates to:
  /// **'This customer is no longer kept.'**
  String get storeCustomerGone;

  /// [domain] What a customer has: one design.
  ///
  /// In en, this message translates to:
  /// **'1 design'**
  String get hasDesignOne;

  /// [domain] What a customer has: designs.
  ///
  /// In en, this message translates to:
  /// **'{n} designs'**
  String hasDesignMany(int n);

  /// [domain] What a customer has: one payment.
  ///
  /// In en, this message translates to:
  /// **'1 payment'**
  String get hasPaymentOne;

  /// [domain] What a customer has: payments.
  ///
  /// In en, this message translates to:
  /// **'{n} payments'**
  String hasPaymentMany(int n);

  /// [domain] What a customer has: one receipt.
  ///
  /// In en, this message translates to:
  /// **'1 receipt'**
  String get hasReceiptOne;

  /// [domain] What a customer has: receipts.
  ///
  /// In en, this message translates to:
  /// **'{n} receipts'**
  String hasReceiptMany(int n);

  /// [domain] What a customer has: a discount.
  ///
  /// In en, this message translates to:
  /// **'a discount'**
  String get hasDiscount;

  /// [domain] What a customer has: quotations.
  ///
  /// In en, this message translates to:
  /// **'quotations'**
  String get hasQuotations;

  /// [domain] What a customer has: one extra charge.
  ///
  /// In en, this message translates to:
  /// **'1 extra charge'**
  String get hasExtraOne;

  /// [domain] What a customer has: extra charges.
  ///
  /// In en, this message translates to:
  /// **'{n} extra charges'**
  String hasExtraMany(int n);

  /// [domain] Why a customer cannot be deleted.
  ///
  /// In en, this message translates to:
  /// **'{name} cannot be deleted: they have {has}. A customer is deleted only when nothing of theirs would go with them — delete each design on its own; payments, receipts, discounts and quotations are the workshop\'s records and are kept.'**
  String cannotDeleteCustomer(String name, String has);

  /// [domain] A quotation that is not kept.
  ///
  /// In en, this message translates to:
  /// **'That quotation is not kept.'**
  String get quotationGone;

  /// [domain] A member of staff with no name.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get staffNameNeeded;

  /// [domain] A member of staff's name already used.
  ///
  /// In en, this message translates to:
  /// **'A member of staff is already called that.'**
  String get staffNameTaken;

  /// [domain] A PIN that is too short.
  ///
  /// In en, this message translates to:
  /// **'Use at least {n} digits.'**
  String pinTooShort(int n);

  /// [domain] The name of a duplicated design.
  ///
  /// In en, this message translates to:
  /// **'{name} (copy)'**
  String copyOf(String name);

  /// Title of the form editing a customer.
  ///
  /// In en, this message translates to:
  /// **'Edit Customer'**
  String get editCustomer;

  /// Under the title of the form editing a customer.
  ///
  /// In en, this message translates to:
  /// **'Change how to reach them or what to remember. Their designs stay exactly as they are.'**
  String get editCustomerLine;

  /// Under the title of the form making a customer.
  ///
  /// In en, this message translates to:
  /// **'Who are you drawing for? Their designs are kept together under them.'**
  String get newCustomerLine;

  /// After the label of a field that may be left empty (with its leading spaces).
  ///
  /// In en, this message translates to:
  /// **'  optional'**
  String get optionalField;

  /// A customer's name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// Example in the customer's name field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Adam'**
  String get nameHint;

  /// A customer's phone number field.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// Example in the phone field.
  ///
  /// In en, this message translates to:
  /// **'e.g. +964 750 123 4567'**
  String get phoneHint;

  /// Example in the address field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Salim Street 12, Sulaymaniyah'**
  String get addressHint;

  /// Hint in the notes field.
  ///
  /// In en, this message translates to:
  /// **'Anything to remember about them'**
  String get notesHint;

  /// Button: keep the changes made.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// Button: keep a new customer.
  ///
  /// In en, this message translates to:
  /// **'Save customer'**
  String get saveCustomer;

  /// The design name field and its heading.
  ///
  /// In en, this message translates to:
  /// **'Design name'**
  String get designName;

  /// Under the design name heading.
  ///
  /// In en, this message translates to:
  /// **'What is this design called?'**
  String get designNameQuestion;

  /// Example in the design name field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Basement Door'**
  String get designNameHint;

  /// Under the design name field.
  ///
  /// In en, this message translates to:
  /// **'The customer is who it is for; this is the name of the design itself.'**
  String get designNameNote;

  /// [domain] A design's name left empty.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for this design, such as the room or the place it is for.'**
  String get nameProblem;

  /// Choose your design: the door card.
  ///
  /// In en, this message translates to:
  /// **'Create a custom door design'**
  String get blurbDoor;

  /// Choose your design: the window card.
  ///
  /// In en, this message translates to:
  /// **'Create a custom window design'**
  String get blurbWindow;

  /// Choose your design: the sliding card.
  ///
  /// In en, this message translates to:
  /// **'Panels that slide past each other'**
  String get blurbSliding;

  /// Choose your design: the door and window card.
  ///
  /// In en, this message translates to:
  /// **'Doors and windows in one frame'**
  String get blurbBoth;

  /// Choose your design: the angled card.
  ///
  /// In en, this message translates to:
  /// **'Sloped, under-stair & custom shapes'**
  String get blurbAngled;

  /// Under the category cards: what separates the standard categories from the angled one.
  ///
  /// In en, this message translates to:
  /// **'Door, Window, Sliding and Door & window straighten lines drawn a little out of square. Angled / Asymmetrical keeps every slope exactly as you draw it.'**
  String get straighteningNote;

  /// Button: begin the design and go to the drawing.
  ///
  /// In en, this message translates to:
  /// **'Start drawing'**
  String get startDrawing;

  /// Title of the category choice.
  ///
  /// In en, this message translates to:
  /// **'Choose your design'**
  String get chooseYourDesign;

  /// Under the category choice's title.
  ///
  /// In en, this message translates to:
  /// **'Select the type of product you want to create.'**
  String get chooseYourDesignLine;

  /// Note under the category cards.
  ///
  /// In en, this message translates to:
  /// **'This is where the design starts, not a limit on it: any opening you mark can still be made a door or a window, and fixed areas sit beside them in the same frame.'**
  String get stillMixed;

  /// Foot bar before a category is chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose a type to continue'**
  String get chooseTypeToContinue;

  /// Foot bar once a category is chosen.
  ///
  /// In en, this message translates to:
  /// **'{kind} selected'**
  String kindSelected(String kind);

  /// A design's category label.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// Under the title of Edit information.
  ///
  /// In en, this message translates to:
  /// **'Change what this design is called. The drawing, its sizes and everything in it stay exactly as they are.'**
  String get editInformationLine;

  /// Why a design's category cannot be changed.
  ///
  /// In en, this message translates to:
  /// **'The category stays with the design.'**
  String get categoryStays;

  /// New design from the first screen: who it is for.
  ///
  /// In en, this message translates to:
  /// **'Who is this design for?'**
  String get whoIsThisFor;

  /// The field for who a new design is for.
  ///
  /// In en, this message translates to:
  /// **'Person / Customer'**
  String get personCustomer;

  /// Example in the person field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ahmed'**
  String get personHint;

  /// A design's short number.
  ///
  /// In en, this message translates to:
  /// **'#{number}'**
  String designNumber(String number);

  /// Design actions sheet: Open.
  ///
  /// In en, this message translates to:
  /// **'Carry on with this design.'**
  String get actionOpenLine;

  /// Design actions sheet: Edit information.
  ///
  /// In en, this message translates to:
  /// **'Change the name of this design.'**
  String get actionEditLine;

  /// Design actions sheet: make a copy.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// Design actions sheet: Duplicate.
  ///
  /// In en, this message translates to:
  /// **'A copy to change without touching this one.'**
  String get actionDuplicateLine;

  /// Design actions sheet: Delete.
  ///
  /// In en, this message translates to:
  /// **'Remove it from this device.'**
  String get actionDeleteLine;

  /// A design that could not be opened.
  ///
  /// In en, this message translates to:
  /// **'{name} could not be opened.'**
  String couldNotOpen(String name);

  /// Notice after a design is deleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted'**
  String designDeleted(String name);

  /// Asked before a design is deleted.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteDesignTitle(String name);

  /// Deleting a design with no customer named.
  ///
  /// In en, this message translates to:
  /// **'This design will be removed from this device. No other design is touched.'**
  String get deleteDesignAlone;

  /// Deleting a customer's design.
  ///
  /// In en, this message translates to:
  /// **'This design will be removed from this device. {who}, their phone, address and notes, and their other designs stay exactly as they are.'**
  String deleteDesignOf(String who);

  /// Under the delete question.
  ///
  /// In en, this message translates to:
  /// **'You can undo it straight afterwards.'**
  String get undoAfterwards;

  /// Button: delete the design.
  ///
  /// In en, this message translates to:
  /// **'Delete design'**
  String get deleteDesign;

  /// The button that completes and saves the design.
  ///
  /// In en, this message translates to:
  /// **'Complete!'**
  String get completeButton;

  /// Heading when completing failed.
  ///
  /// In en, this message translates to:
  /// **'Not completed'**
  String get notCompleted;

  /// Beside Complete!, once the design is completed.
  ///
  /// In en, this message translates to:
  /// **'Completed and saved'**
  String get completedAndSaved;

  /// Beside Complete!, while the design is a draft.
  ///
  /// In en, this message translates to:
  /// **'Draft — press Complete! when the design is finished'**
  String get draftHint;

  /// Heading when the design is incomplete.
  ///
  /// In en, this message translates to:
  /// **'Not complete yet'**
  String get notCompleteYet;

  /// After Complete! saved the design.
  ///
  /// In en, this message translates to:
  /// **'Design completed and saved successfully.'**
  String get completedSuccess;

  /// Who a design is for.
  ///
  /// In en, this message translates to:
  /// **'for {customer}'**
  String forCustomer(String customer);

  /// How many openings a design has.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 opening} other{{count} openings}}'**
  String openingsCount(int count);

  /// After completing: stay on the design.
  ///
  /// In en, this message translates to:
  /// **'View Completed Design'**
  String get viewCompletedDesign;

  /// After completing: go to the customer's page.
  ///
  /// In en, this message translates to:
  /// **'Back to Customer'**
  String get backToCustomer;

  /// Completing a design of an unknown category.
  ///
  /// In en, this message translates to:
  /// **'This design was made by a newer ProFrame or with a category this version does not recognise, so it cannot be completed here.'**
  String get completeUnsupported;

  /// Completing a design that is not finished.
  ///
  /// In en, this message translates to:
  /// **'This design is not complete yet. Please finish the required parts before completing it.'**
  String get completeIncomplete;

  /// Completing without permission.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to complete designs.'**
  String get completeNoPermission;

  /// Completing when the save failed; the error is technical text.
  ///
  /// In en, this message translates to:
  /// **'The design could not be saved, so it was not completed. Your work is still here — try again. ({error})'**
  String completeSaveFailed(String error);

  /// An item in a list, with a bullet.
  ///
  /// In en, this message translates to:
  /// **'• {item}'**
  String bulleted(String item);

  /// Screen reader: a design's picture.
  ///
  /// In en, this message translates to:
  /// **'Drawing of {name}'**
  String drawingOf(String name);

  /// A design card with nothing drawn.
  ///
  /// In en, this message translates to:
  /// **'Nothing drawn yet'**
  String get nothingDrawnYet;

  /// A design card whose record cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable'**
  String get previewUnavailable;

  /// Note on a design of an unknown category.
  ///
  /// In en, this message translates to:
  /// **'Unsupported design category'**
  String get unsupportedTitle;

  /// Note on a design of an unknown category.
  ///
  /// In en, this message translates to:
  /// **'This design was made with a newer version of ProFrame, or has a category this version does not recognise. It is shown exactly as it was saved and cannot be changed here, so nothing in it is lost. Its original category is kept.'**
  String get unsupportedMessage;

  /// Note under the drawing for somebody who may not edit.
  ///
  /// In en, this message translates to:
  /// **'View only. You do not have permission to edit designs, so nothing you change here is kept. Sign in as somebody who may.'**
  String get viewOnlyMessage;

  /// Brief note after lines drawn a little out of square were straightened.
  ///
  /// In en, this message translates to:
  /// **'Geometry normalized for standard design.'**
  String get normalizedMessage;

  /// [domain] Question: a mark drawn outside the design.
  ///
  /// In en, this message translates to:
  /// **'Which section does this {glyph} belong to?'**
  String qSymbolPrompt(String glyph);

  /// [domain] Question: a mark drawn outside the design.
  ///
  /// In en, this message translates to:
  /// **'The mark is outside the design, so there is no section it could be in. Say which one you meant.'**
  String get qSymbolDetail;

  /// [domain] Answer: open this section, and how.
  ///
  /// In en, this message translates to:
  /// **'Open this one, {meaning}.'**
  String qSymbolOpen(String meaning);

  /// [domain] Answer: the mark is not an opening mark.
  ///
  /// In en, this message translates to:
  /// **'It is not an opening mark'**
  String get qNotASymbol;

  /// [domain] Explains the answer.
  ///
  /// In en, this message translates to:
  /// **'Build it as lines, exactly where it was drawn.'**
  String get qNotASymbolDetail;

  /// [domain] What a < mark says.
  ///
  /// In en, this message translates to:
  /// **'hinged on the right, opening from the left'**
  String get meanPointsLeft;

  /// [domain] What a > mark says.
  ///
  /// In en, this message translates to:
  /// **'hinged on the left, opening from the right'**
  String get meanPointsRight;

  /// [domain] What a ^ mark says.
  ///
  /// In en, this message translates to:
  /// **'hinged at the bottom, opening at the top'**
  String get meanPointsUp;

  /// [domain] What a v mark says.
  ///
  /// In en, this message translates to:
  /// **'hinged at the top, opening at the bottom'**
  String get meanPointsDown;

  /// [domain] Where a section is: upper.
  ///
  /// In en, this message translates to:
  /// **'upper'**
  String get whereUpper;

  /// [domain] Where a section is: lower.
  ///
  /// In en, this message translates to:
  /// **'lower'**
  String get whereLower;

  /// [domain] Where a section is: left.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get whereLeft;

  /// [domain] Where a section is: right.
  ///
  /// In en, this message translates to:
  /// **'right'**
  String get whereRight;

  /// [domain] Where a section is: e.g. upper left.
  ///
  /// In en, this message translates to:
  /// **'{vertical} {horizontal}'**
  String whereBoth(String vertical, String horizontal);

  /// [domain] A section named by where it is and its size.
  ///
  /// In en, this message translates to:
  /// **'The {place} section — {size}'**
  String sectionDescribed(String place, String size);

  /// [domain] The side of an outline left open: the bottom.
  ///
  /// In en, this message translates to:
  /// **'the bottom'**
  String get gapBottom;

  /// [domain] The side of an outline left open: the top.
  ///
  /// In en, this message translates to:
  /// **'the top'**
  String get gapTop;

  /// [domain] The side of an outline left open: the left.
  ///
  /// In en, this message translates to:
  /// **'the left side'**
  String get gapLeft;

  /// [domain] The side of an outline left open: the right.
  ///
  /// In en, this message translates to:
  /// **'the right side'**
  String get gapRight;

  /// [domain] The side of an outline left open: unnamed.
  ///
  /// In en, this message translates to:
  /// **'one side'**
  String get gapOne;

  /// [domain] Question: one side of the outline left open.
  ///
  /// In en, this message translates to:
  /// **'Your design is not closed — {side} is open.'**
  String qGapPrompt(String side);

  /// [domain] Question: one side of the outline left open.
  ///
  /// In en, this message translates to:
  /// **'Do you want it this way, or are you going to change it? Nothing has been added or taken away.'**
  String get qGapDetail;

  /// [domain] Answer: keep the side open.
  ///
  /// In en, this message translates to:
  /// **'Keep it open'**
  String get qKeepOpen;

  /// [domain] Explains Keep it open.
  ///
  /// In en, this message translates to:
  /// **'Build it as drawn, with no frame across {side}.'**
  String qKeepOpenDetail(String side);

  /// [domain] Explains Keep it open, for the bottom.
  ///
  /// In en, this message translates to:
  /// **'Build it as drawn, with no frame across {side} — a door runs down to the floor.'**
  String qKeepOpenFootDetail(String side);

  /// [domain] Answer: close the side.
  ///
  /// In en, this message translates to:
  /// **'Close it'**
  String get qCloseIt;

  /// [domain] Explains Close it.
  ///
  /// In en, this message translates to:
  /// **'Put the frame across {side}, straight between the two ends you drew.'**
  String qCloseItDetail(String side);

  /// [domain] Answer: the user will change the drawing.
  ///
  /// In en, this message translates to:
  /// **'I will change it'**
  String get qChangeIt;

  /// [domain] Explains I will change it.
  ///
  /// In en, this message translates to:
  /// **'Go back to the drawing and draw it as you want it.'**
  String get qChangeItDetail;

  /// [domain] Question: lines that do not close into a shape.
  ///
  /// In en, this message translates to:
  /// **'The outline does not close. What would you like to do?'**
  String get qNotClosedPrompt;

  /// [domain] Question: lines that do not close into a shape.
  ///
  /// In en, this message translates to:
  /// **'Your lines do not join up into a shape, so there is no outer frame yet. Nothing has been changed or added.'**
  String get qNotClosedDetail;

  /// [domain] Answer: the user will finish the outline.
  ///
  /// In en, this message translates to:
  /// **'Let me draw the rest'**
  String get qDrawRest;

  /// [domain] Explains Let me draw the rest.
  ///
  /// In en, this message translates to:
  /// **'Go back to the drawing and close the outline yourself.'**
  String get qDrawRestDetail;

  /// Button: put a question away without answering.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get actNotNow;

  /// Button: light the part a message is about on the drawing.
  ///
  /// In en, this message translates to:
  /// **'Show me'**
  String get actShowMe;

  /// Button: stop showing a highlighted part.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get actHide;

  /// Button: answer later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get actLater;

  /// Button: finished choosing.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actDone;

  /// Button: go back a step.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actBack;

  /// Button: go on to the next step.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actContinue;

  /// Button: close a dialog without doing anything.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actCancel;

  /// Button: save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actSave;

  /// Button: delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actDelete;

  /// Button: close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actClose;

  /// Button: apply a typed value.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get actApply;

  /// Button: remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actRemove;

  /// Button: add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actAdd;

  /// Heading over the questions the reading raised: one question.
  ///
  /// In en, this message translates to:
  /// **'One thing to check'**
  String get checkOne;

  /// Heading over the questions the reading raised.
  ///
  /// In en, this message translates to:
  /// **'{count} things to check'**
  String checkMany(int count);

  /// Under the questions the reading raised.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been decided for you. Your drawing is unchanged until you answer.'**
  String get checkNothingDecided;

  /// Title of the alert asking whether an opening is a door or a window.
  ///
  /// In en, this message translates to:
  /// **'Opening type'**
  String get openingTypeTitle;

  /// How many questions are left, the one shown being the first.
  ///
  /// In en, this message translates to:
  /// **'1 of {count}'**
  String oneOfMany(int count);

  /// Title of the alert: the outline has a side missing.
  ///
  /// In en, this message translates to:
  /// **'Design not closed'**
  String get designNotClosedTitle;

  /// Screen reader: fold the geometry check.
  ///
  /// In en, this message translates to:
  /// **'Fewer details'**
  String get gcFewerDetails;

  /// Screen reader: unfold the geometry check.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get gcMoreDetails;

  /// Severity of a geometry problem: it cannot be built as drawn.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get gcError;

  /// Severity of a geometry problem: it may not be what was meant.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get gcWarning;

  /// [domain] Question: is this opening a door or a window.
  ///
  /// In en, this message translates to:
  /// **'What is {opening}?'**
  String qKindPrompt(String opening);

  /// [domain] Question detail: door or window.
  ///
  /// In en, this message translates to:
  /// **'A mark says this section opens. It does not say whether it is a door or a window, and the two are not made the same. This is about this one opening; every other section is untouched.'**
  String get qKindDetail;

  /// [domain] Answer detail: a door.
  ///
  /// In en, this message translates to:
  /// **'A leaf you walk through.'**
  String get qKindDoorDetail;

  /// [domain] Answer detail: a window.
  ///
  /// In en, this message translates to:
  /// **'A leaf you open from indoors.'**
  String get qKindWindowDetail;

  /// [domain] Question as a door design starts: panel, glass or both.
  ///
  /// In en, this message translates to:
  /// **'How should this door be constructed?'**
  String get qConstructionDoor;

  /// [domain] Question as a door & window design starts: panel, glass or both.
  ///
  /// In en, this message translates to:
  /// **'How should this design be constructed?'**
  String get qConstructionDesign;

  /// [domain] Question detail: what a door is built of.
  ///
  /// In en, this message translates to:
  /// **'You decide what fills the parts you draw. Nothing is divided or moved for you, and every part can be changed later.'**
  String get qConstructionDetail;

  /// [domain] Said where a design to be both glass and panel has only one part.
  ///
  /// In en, this message translates to:
  /// **'Your design has no internal division yet'**
  String get qOnePart;

  /// [domain] Detail for the one-part case.
  ///
  /// In en, this message translates to:
  /// **'Draw a divider first to create separate panel and glass parts. Nothing is divided for you.'**
  String get qOnePartDetail;

  /// [domain] Question: glass or panel, part by part.
  ///
  /// In en, this message translates to:
  /// **'Which parts should be glass and which should be panel?'**
  String get qParts;

  /// [domain] Detail of the glass-or-panel question.
  ///
  /// In en, this message translates to:
  /// **'Choose for each part you drew. The lines stay exactly where you drew them.'**
  String get qPartsDetail;

  /// Title of the alert asking what a door is built of.
  ///
  /// In en, this message translates to:
  /// **'Glass or panel'**
  String get glassOrPanelTitle;

  /// Second step: the panel's colour.
  ///
  /// In en, this message translates to:
  /// **'What colour is the panel?'**
  String get whatPanelColour;

  /// Second step: the glass.
  ///
  /// In en, this message translates to:
  /// **'What glass is it?'**
  String get whatGlass;

  /// Under the second step.
  ///
  /// In en, this message translates to:
  /// **'Every part you draw starts as this. Any part can be changed later with Material.'**
  String get everyPartStartsAs;

  /// Choice: the whole design is panel.
  ///
  /// In en, this message translates to:
  /// **'Entire design = Panel'**
  String get wholePanel;

  /// Detail of the choice.
  ///
  /// In en, this message translates to:
  /// **'Every part is a solid panel.'**
  String get wholePanelDetail;

  /// Choice: the whole design is glass.
  ///
  /// In en, this message translates to:
  /// **'Entire design = Glass'**
  String get wholeGlass;

  /// Detail of the choice.
  ///
  /// In en, this message translates to:
  /// **'Every part is glazed.'**
  String get wholeGlassDetail;

  /// Choice: some parts glass, some panel.
  ///
  /// In en, this message translates to:
  /// **'Both Panel + Glass'**
  String get bothPanelGlass;

  /// Detail of the choice.
  ///
  /// In en, this message translates to:
  /// **'You choose which parts are glass and which are panel.'**
  String get bothPanelGlassDetail;

  /// Button: back to the drawing to draw a divider.
  ///
  /// In en, this message translates to:
  /// **'Draw divider'**
  String get drawDivider;

  /// Detail of the button.
  ///
  /// In en, this message translates to:
  /// **'Back to the drawing with a straight line.'**
  String get drawDividerDetail;

  /// All parts said glass or panel.
  ///
  /// In en, this message translates to:
  /// **'Every part is chosen.'**
  String get everyPartChosen;

  /// How many parts are still to be said glass or panel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 part still to choose.} other{{count} parts still to choose.}}'**
  String partsLeft(int count);

  /// What fills a part: glass.
  ///
  /// In en, this message translates to:
  /// **'Glass'**
  String get fillGlass;

  /// What fills a part: panel.
  ///
  /// In en, this message translates to:
  /// **'Panel'**
  String get fillPanel;

  /// Prompt in the material form.
  ///
  /// In en, this message translates to:
  /// **'Choose the panel colour'**
  String get chooseThePanelColour;

  /// Prompt in the material form.
  ///
  /// In en, this message translates to:
  /// **'Choose the glass'**
  String get chooseTheGlass;

  /// Label over the panel's colours.
  ///
  /// In en, this message translates to:
  /// **'Panel colour'**
  String get panelColour;

  /// A geometry problem, and how many more there are.
  ///
  /// In en, this message translates to:
  /// **'{message}  +{count} more'**
  String gcMore(String message, int count);

  /// How many errors the geometry check found.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 error} other{{count} errors}}'**
  String gcErrors(int count);

  /// How many warnings the geometry check found.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 warning} other{{count} warnings}}'**
  String gcWarnings(int count);

  /// [domain] A part of the design, by its place in reading order.
  ///
  /// In en, this message translates to:
  /// **'Part {number}'**
  String partNumbered(int number);

  /// [domain] Where a part is: a fixed part of the design, in no opening.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get partFixed;

  /// Heading of the design's own panel, when nothing is picked.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get inDesign;

  /// Under the design's own panel heading.
  ///
  /// In en, this message translates to:
  /// **'Tap any part of the drawing to change it.'**
  String get inTapAnyPart;

  /// Field: a width.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get inWidth;

  /// Field: a height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get inHeight;

  /// Field: the frame's border width.
  ///
  /// In en, this message translates to:
  /// **'Frame profile'**
  String get inFrameProfile;

  /// Field: the design's depth.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get inDepth;

  /// Help under a side's own size.
  ///
  /// In en, this message translates to:
  /// **'Moves this side\'s free end. The other sides keep their sizes, and the slope between them follows.'**
  String get inSideHelp;

  /// Field: a length.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get inLength;

  /// Field: an angle.
  ///
  /// In en, this message translates to:
  /// **'Angle'**
  String get inAngle;

  /// Readout: how far a slope climbs.
  ///
  /// In en, this message translates to:
  /// **'Rise'**
  String get inRise;

  /// Readout: how far across a slope goes.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get inRun;

  /// Readout: where a side starts.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get inFrom;

  /// Readout: where a side ends.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get inTo;

  /// Help on a frame member's panel.
  ///
  /// In en, this message translates to:
  /// **'Drag its handle to move this side of the frame square to itself. The other sides stay where they are.'**
  String get inDragSide;

  /// Help under the frame profile.
  ///
  /// In en, this message translates to:
  /// **'One figure for the whole frame, as it is cut from one section of material.'**
  String get inProfileHelp;

  /// Field: a bar's width.
  ///
  /// In en, this message translates to:
  /// **'Bar width'**
  String get inBarWidth;

  /// Button on a bar's panel.
  ///
  /// In en, this message translates to:
  /// **'Delete this bar'**
  String get inDeleteBar;

  /// Field: where something is.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get inPosition;

  /// Button on a piece of hardware's panel.
  ///
  /// In en, this message translates to:
  /// **'Remove this {piece}'**
  String inRemovePiece(String piece);

  /// Readout: a dimension as drawn.
  ///
  /// In en, this message translates to:
  /// **'As drawn'**
  String get inAsDrawn;

  /// Field: a dimension's true measurement.
  ///
  /// In en, this message translates to:
  /// **'Real size'**
  String get inRealSize;

  /// Help under a dimension's real size.
  ///
  /// In en, this message translates to:
  /// **'Type the true measurement. The whole design is scaled to match it, in proportion — nothing moves relative to anything else.'**
  String get inRealSizeHelp;

  /// Button on a dimension's panel.
  ///
  /// In en, this message translates to:
  /// **'Delete this dimension'**
  String get inDeleteDimension;

  /// Readout: a note's text.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get inNote;

  /// Button on a note's panel.
  ///
  /// In en, this message translates to:
  /// **'Delete this note'**
  String get inDeleteNote;

  /// Readout heading for an arrow.
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get inArrow;

  /// Readout for an arrow.
  ///
  /// In en, this message translates to:
  /// **'Drag it to move it.'**
  String get inDragToMove;

  /// Button on an arrow's panel.
  ///
  /// In en, this message translates to:
  /// **'Delete this arrow'**
  String get inDeleteArrow;

  /// Design panel before anything is read.
  ///
  /// In en, this message translates to:
  /// **'Draw the outline of your {noun}, then read the drawing. Whatever you draw is what gets built — nothing is assumed and nothing is filled in for you.'**
  String inDrawOutline(String noun);

  /// Field: the design's overall width.
  ///
  /// In en, this message translates to:
  /// **'Overall width'**
  String get inOverallWidth;

  /// Help under the overall width.
  ///
  /// In en, this message translates to:
  /// **'The width alone: the height stays as it is.'**
  String get inOverallWidthHelp;

  /// Field: the design's overall height.
  ///
  /// In en, this message translates to:
  /// **'Overall height'**
  String get inOverallHeight;

  /// Button: open the sizes form, every size given.
  ///
  /// In en, this message translates to:
  /// **'All sizes'**
  String get inAllSizes;

  /// Button: open the sizes form.
  ///
  /// In en, this message translates to:
  /// **'Enter the sizes'**
  String get inEnterSizes;

  /// Readout: how many sections.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get inSections;

  /// Readout: how many bars.
  ///
  /// In en, this message translates to:
  /// **'Bars'**
  String get inBars;

  /// Readout: how many openings.
  ///
  /// In en, this message translates to:
  /// **'Openings'**
  String get inOpenings;

  /// Heading over each opening's door or window switch.
  ///
  /// In en, this message translates to:
  /// **'Opening types'**
  String get inOpeningTypes;

  /// Under the opening types.
  ///
  /// In en, this message translates to:
  /// **'Picked the wrong one? Change it here.'**
  String get inPickedWrong;

  /// On a hinge's or handle's panel.
  ///
  /// In en, this message translates to:
  /// **'On {mechanism} — {description}. This is the opening\'s, so it moves with it.'**
  String inOnLeaf(String mechanism, String description);

  /// Field: where the first hinge is.
  ///
  /// In en, this message translates to:
  /// **'First hinge from the top'**
  String get inFirstHinge;

  /// Field: a distance from the left.
  ///
  /// In en, this message translates to:
  /// **'From the left'**
  String get inFromLeft;

  /// Field: where the last hinge is.
  ///
  /// In en, this message translates to:
  /// **'Last hinge from the bottom'**
  String get inLastHinge;

  /// Field: a distance from the right.
  ///
  /// In en, this message translates to:
  /// **'From the right'**
  String get inFromRight;

  /// Label over the hinge count.
  ///
  /// In en, this message translates to:
  /// **'Number of hinges'**
  String get inHingeCount;

  /// Under the hinge count.
  ///
  /// In en, this message translates to:
  /// **'Evenly spaced between the two ends, because evenly is the only spacing that is not a decision about where they look best.'**
  String get inEvenly;

  /// Label over the handle's form.
  ///
  /// In en, this message translates to:
  /// **'Handle type'**
  String get inHandleType;

  /// Handle form: a long pull bar for a sliding panel.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get inHandleBar;

  /// Handle form: a lever.
  ///
  /// In en, this message translates to:
  /// **'Lever'**
  String get inHandleLever;

  /// Handle form: a knob.
  ///
  /// In en, this message translates to:
  /// **'Knob'**
  String get inHandleKnob;

  /// Handle form: a pull handle.
  ///
  /// In en, this message translates to:
  /// **'Pull'**
  String get inHandlePull;

  /// Field: the handle's height.
  ///
  /// In en, this message translates to:
  /// **'Height from the bottom'**
  String get inHeightFromBottom;

  /// Help under the handle's height.
  ///
  /// In en, this message translates to:
  /// **'Measured on the leaf, not on the frame, so it stays where you put it when the opening moves.'**
  String get inHandleHelp;

  /// Heading on a diagonal bar's panel.
  ///
  /// In en, this message translates to:
  /// **'This diagonal'**
  String get inThisDiagonal;

  /// Help on a diagonal bar's panel.
  ///
  /// In en, this message translates to:
  /// **'It is built as a bar, exactly where you drew it. On a drawing a diagonal often means the pane opens instead — if that is what you meant, say so and the line becomes the opening.'**
  String get inDiagonalHelp;

  /// Button: the diagonal's pane opens this way.
  ///
  /// In en, this message translates to:
  /// **'Opens {how}'**
  String inOpensAs(String how);

  /// Field: a bar's place inside an opening.
  ///
  /// In en, this message translates to:
  /// **'From the top of the opening'**
  String get inFromTopOfOpening;

  /// Field: a bar's place inside an opening.
  ///
  /// In en, this message translates to:
  /// **'From the left of the opening'**
  String get inFromLeftOfOpening;

  /// Field: a diagonal bar's place inside an opening.
  ///
  /// In en, this message translates to:
  /// **'Into the opening, square to this bar'**
  String get inIntoOpening;

  /// Help under a bar's place.
  ///
  /// In en, this message translates to:
  /// **'Measured inside the section this bar divides.'**
  String get inMeasuredInSection;

  /// Help under a bar's place.
  ///
  /// In en, this message translates to:
  /// **'Measured inside the opening, so it stays where you put it when the opening moves.'**
  String get inMeasuredInOpening;

  /// Readout: the opening's size.
  ///
  /// In en, this message translates to:
  /// **'The opening is'**
  String get inTheOpeningIs;

  /// Under a pane's place inside an opening.
  ///
  /// In en, this message translates to:
  /// **'This pane is inside the opening, so it moves and swings with it.'**
  String get inPaneInside;

  /// Label: what a bar divides.
  ///
  /// In en, this message translates to:
  /// **'Divides'**
  String get inDivides;

  /// Choice: the bar divides the whole design.
  ///
  /// In en, this message translates to:
  /// **'The whole design'**
  String get inWholeDesign;

  /// Choice: the bar divides an opening.
  ///
  /// In en, this message translates to:
  /// **'Inside the opening — {section}'**
  String inInsideOpening(String section);

  /// Choice: the bar divides a section.
  ///
  /// In en, this message translates to:
  /// **'Inside {section}'**
  String inInsideSection(String section);

  /// Under the Divides choice.
  ///
  /// In en, this message translates to:
  /// **'This line is inside that section. It divides that section only, and travels with it.'**
  String get inLineInside;

  /// Under the Divides choice.
  ///
  /// In en, this message translates to:
  /// **'This line divides the design itself.'**
  String get inLineDividesDesign;

  /// Label: door or window.
  ///
  /// In en, this message translates to:
  /// **'Opening type'**
  String get inOpeningType;

  /// Under the opening type, in an angled design.
  ///
  /// In en, this message translates to:
  /// **'Nobody has said what this leaf is. An angled design can hold doors or windows, so it does not say which — until you choose, it hangs on its hinges and carries no handle.'**
  String get inNobodyAngled;

  /// Under the opening type, in a door & window design.
  ///
  /// In en, this message translates to:
  /// **'Nobody has said what this leaf is. This design holds doors and windows, so it does not say either — until you choose, it hangs on its hinges and carries no handle.'**
  String get inNobodyBoth;

  /// Under the opening type, where the leaf follows the design.
  ///
  /// In en, this message translates to:
  /// **'Nobody has said yet, so this leaf follows the design — a {kind}. Choose to say.'**
  String inFollowsDesign(String kind);

  /// Label: which way the leaf opens.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get inDirection;

  /// Under the direction: the mark drawn and the one now.
  ///
  /// In en, this message translates to:
  /// **'You drew {drawn} here. You have since changed it to {now}.'**
  String inDrewChanged(String drawn, String now);

  /// Under the direction: the mark drawn.
  ///
  /// In en, this message translates to:
  /// **'You marked this section with a {drawn}.'**
  String inMarkedWith(String drawn);

  /// Switch: a pleated insect screen on a sliding panel.
  ///
  /// In en, this message translates to:
  /// **'Pleated screen'**
  String get inPleated;

  /// Help under the pleated screen.
  ///
  /// In en, this message translates to:
  /// **'An insect screen that fans out of a cassette at the jamb across the passage as the panel opens.'**
  String get inPleatedHelp;

  /// Switch: an automatic sliding panel.
  ///
  /// In en, this message translates to:
  /// **'Automatic, by sensor'**
  String get inAutomatic;

  /// Help under the automatic switch.
  ///
  /// In en, this message translates to:
  /// **'Opened by a drive when the sensor on the head sees somebody coming.'**
  String get inAutomaticHelp;

  /// Label: the opening's mechanism.
  ///
  /// In en, this message translates to:
  /// **'How it opens'**
  String get inHowItOpens;

  /// The leaf opens inward.
  ///
  /// In en, this message translates to:
  /// **'Inward'**
  String get inInward;

  /// The leaf opens outward.
  ///
  /// In en, this message translates to:
  /// **'Outward'**
  String get inOutward;

  /// Under the opening's position.
  ///
  /// In en, this message translates to:
  /// **'Moving the opening changes which section opens. Neither section changes shape, and whatever you have drawn inside the opening goes with it.'**
  String get inMovingOpening;

  /// Button: make the opening fixed.
  ///
  /// In en, this message translates to:
  /// **'This section does not open'**
  String get inDoesNotOpen;

  /// Where a section is: the upper row.
  ///
  /// In en, this message translates to:
  /// **'Upper'**
  String get secUpper;

  /// Where a section is: the lower row.
  ///
  /// In en, this message translates to:
  /// **'Lower'**
  String get secLower;

  /// Where a section is: the left column.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get secLeft;

  /// Where a section is: the right column.
  ///
  /// In en, this message translates to:
  /// **'right'**
  String get secRight;

  /// A section, named by where it is and its size.
  ///
  /// In en, this message translates to:
  /// **'{place} section — {size}'**
  String secPlaced(String place, String size);

  /// Label: whether a section opens.
  ///
  /// In en, this message translates to:
  /// **'Opens'**
  String get inOpens;

  /// Button on a section's panel.
  ///
  /// In en, this message translates to:
  /// **'Edit this opening'**
  String get inEditOpening;

  /// On a marked section's panel.
  ///
  /// In en, this message translates to:
  /// **'You marked this section with a {drawn}. Nothing else opens.'**
  String inMarkedNothingElse(String drawn);

  /// Label on a section's panel.
  ///
  /// In en, this message translates to:
  /// **'Add hardware here'**
  String get inAddHardware;

  /// Help on a section's panel.
  ///
  /// In en, this message translates to:
  /// **'Nothing is added on its own. What you add goes in the middle of this section, and you can drag it where you want it.'**
  String get inAddHardwareHelp;

  /// Label: a part's material.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get inMaterial;

  /// Label: a part's colour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get inColour;

  /// [domain] Note on the one payment carried over from an older customer record.
  ///
  /// In en, this message translates to:
  /// **'Migrated from the previous customer payment balance.'**
  String get payLegacyNote;

  /// [domain] Amount check.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount.'**
  String get amtEnter;

  /// [domain] Amount check.
  ///
  /// In en, this message translates to:
  /// **'The amount must be more than nothing.'**
  String get amtMoreThanNothing;

  /// [domain] Amount check.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount to the cent — two decimal places at most.'**
  String get amtToTheCent;

  /// [domain] Amount check.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount as a number, such as 500.00.'**
  String get amtAsNumber;

  /// [domain] Amount check.
  ///
  /// In en, this message translates to:
  /// **'Enter a smaller amount.'**
  String get amtSmaller;

  /// [domain] Refund check.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been paid, so nothing can be refunded.'**
  String get refundNothingPaid;

  /// [domain] Refund check, in another currency.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been paid in {currency}, so nothing can be refunded.'**
  String refundNothingPaidIn(String currency);

  /// [domain] Refund check.
  ///
  /// In en, this message translates to:
  /// **'A refund cannot be more than the net paid, {amount}.'**
  String refundTooMuch(String amount);

  /// [domain] Date check for a payment.
  ///
  /// In en, this message translates to:
  /// **'Payments cannot be dated in the future.'**
  String get paymentNotFuture;

  /// [domain] Date check for a refund.
  ///
  /// In en, this message translates to:
  /// **'Refunds cannot be dated in the future.'**
  String get refundNotFuture;

  /// [domain] Exchange rate check.
  ///
  /// In en, this message translates to:
  /// **'Enter the rate as a number, such as 1.10.'**
  String get rateAsNumber;

  /// [domain] Exchange rate check.
  ///
  /// In en, this message translates to:
  /// **'The rate must be more than nothing.'**
  String get rateMoreThanNothing;

  /// [domain] No discount in force.
  ///
  /// In en, this message translates to:
  /// **'No discount'**
  String get discountNone;

  /// [domain] Discount check.
  ///
  /// In en, this message translates to:
  /// **'Enter the discount.'**
  String get discountEnter;

  /// [domain] Discount check.
  ///
  /// In en, this message translates to:
  /// **'A discount must be more than nothing.'**
  String get discountMoreThanNothing;

  /// [domain] Discount check.
  ///
  /// In en, this message translates to:
  /// **'A percentage cannot be more than 100%.'**
  String get discountOver100;

  /// [domain] Discount check.
  ///
  /// In en, this message translates to:
  /// **'The total is not final yet. A fixed discount can be given once every design is priced.'**
  String get discountNotFinal;

  /// [domain] Discount check.
  ///
  /// In en, this message translates to:
  /// **'The discount cannot be more than the subtotal, {amount}.'**
  String discountOverSubtotal(String amount);

  /// [domain] Discount check.
  ///
  /// In en, this message translates to:
  /// **'Enter the percentage as a number, such as 10 or 12.5.'**
  String get discountPercentNumber;

  /// Customer's finances, without permission.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to view this customer\'s finances.'**
  String get finNoAccess;

  /// Heading of the customer's money.
  ///
  /// In en, this message translates to:
  /// **'FINANCIAL SUMMARY'**
  String get finSummary;

  /// Row: how many designs.
  ///
  /// In en, this message translates to:
  /// **'Designs'**
  String get finDesigns;

  /// How many designs, and how many have a price.
  ///
  /// In en, this message translates to:
  /// **'{count} · {priced} priced'**
  String finDesignsPriced(int count, int priced);

  /// Row: the designs' prices summed.
  ///
  /// In en, this message translates to:
  /// **'Designs total'**
  String get finDesignsTotal;

  /// A total that is not final.
  ///
  /// In en, this message translates to:
  /// **'Not final'**
  String get finNotFinal;

  /// Row: the customer's own extras.
  ///
  /// In en, this message translates to:
  /// **'Extra charges (whole job)'**
  String get finExtrasWholeJob;

  /// Row: before the discount.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get finSubtotal;

  /// Row: the discount in force.
  ///
  /// In en, this message translates to:
  /// **'Discount ({amount})'**
  String finDiscountOf(String amount);

  /// A discount that cannot be worked out yet.
  ///
  /// In en, this message translates to:
  /// **'when the total is final'**
  String get finWhenFinal;

  /// Row: the total price.
  ///
  /// In en, this message translates to:
  /// **'Total price'**
  String get finTotalPrice;

  /// Row: the total after discount and extras.
  ///
  /// In en, this message translates to:
  /// **'Final total'**
  String get finFinalTotal;

  /// Warning under the total.
  ///
  /// In en, this message translates to:
  /// **'The discount of {amount} is more than the subtotal now, so it takes the whole subtotal and no more.'**
  String finDiscountExceeds(String amount);

  /// Why the customer's total is not final.
  ///
  /// In en, this message translates to:
  /// **'Customer price is not final. {reason}'**
  String finCustomerNotFinal(String reason);

  /// Row: what is priced so far.
  ///
  /// In en, this message translates to:
  /// **'Priced so far (not the total)'**
  String get finPricedSoFar;

  /// Row: every payment.
  ///
  /// In en, this message translates to:
  /// **'Total payments'**
  String get finTotalPayments;

  /// Row: every refund.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get finRefunds;

  /// Row: payments less refunds.
  ///
  /// In en, this message translates to:
  /// **'Net paid'**
  String get finNetPaid;

  /// Row: what is still owed.
  ///
  /// In en, this message translates to:
  /// **'Amount due'**
  String get finAmountDue;

  /// Row: paid more than the total.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get finCredit;

  /// Under the credit.
  ///
  /// In en, this message translates to:
  /// **'The customer has paid {amount} more than their designs now come to. It is theirs: it can be refunded, or stand against a later design.'**
  String finCreditNote(String amount);

  /// Button: give a discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get finDiscount;

  /// Button: record a payment.
  ///
  /// In en, this message translates to:
  /// **'Add payment'**
  String get finAddPayment;

  /// Button: record a refund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get finRefund;

  /// Heading of the payment history.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT HISTORY'**
  String get finHistory;

  /// The history is empty.
  ///
  /// In en, this message translates to:
  /// **'No payment history yet.'**
  String get finNoHistory;

  /// Button: show the next page.
  ///
  /// In en, this message translates to:
  /// **'Load more ({count} more)'**
  String finLoadMore(int count);

  /// Unfold the summary.
  ///
  /// In en, this message translates to:
  /// **'Show each design and the materials'**
  String get finShowDesigns;

  /// Fold the summary.
  ///
  /// In en, this message translates to:
  /// **'Hide each design and the materials'**
  String get finHideDesigns;

  /// Heading over each design's price.
  ///
  /// In en, this message translates to:
  /// **'DESIGNS'**
  String get finDesignsHeading;

  /// What a design is and is made of.
  ///
  /// In en, this message translates to:
  /// **'Category: {category} · Material: {material} · Colour: {colour}'**
  String finDesignFacts(String category, String material, String colour);

  /// Heading over the customer's measurements.
  ///
  /// In en, this message translates to:
  /// **'CUSTOMER MATERIAL SUMMARY'**
  String get finMaterialSummary;

  /// Under the material summary.
  ///
  /// In en, this message translates to:
  /// **'Of the {priced} of {count} designs with a current price.'**
  String finOfPriced(int priced, int count);

  /// Where a customer's extra charge belongs.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s whole job — no one design\'s'**
  String finWholeJobOf(String name);

  /// Where a customer's extra charge belongs.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s whole job'**
  String finWholeJob(String name);

  /// Heading over the customer's own extras.
  ///
  /// In en, this message translates to:
  /// **'EXTRA CHARGES — WHOLE JOB'**
  String get finExtrasHeading;

  /// Button: add an extra charge.
  ///
  /// In en, this message translates to:
  /// **'Add extra'**
  String get finAddExtra;

  /// The customer has no extras.
  ///
  /// In en, this message translates to:
  /// **'No extra charges for the whole job. A design\'s own extras are on its price.'**
  String get finNoExtras;

  /// Heading over money in other currencies.
  ///
  /// In en, this message translates to:
  /// **'OTHER CURRENCIES — not included in the {currency} total'**
  String finOtherCurrencies(String currency);

  /// Row: payments in another currency.
  ///
  /// In en, this message translates to:
  /// **'{currency} payments'**
  String finCurrencyPayments(String currency);

  /// Row: refunds in another currency.
  ///
  /// In en, this message translates to:
  /// **'{currency} refunds'**
  String finCurrencyRefunds(String currency);

  /// Under money in other currencies.
  ///
  /// In en, this message translates to:
  /// **'No exchange rate was recorded with these, so they are kept in their own currency and not added to the {currency} figures above.'**
  String finNoRate(String currency);

  /// Heading over the quotations.
  ///
  /// In en, this message translates to:
  /// **'QUOTATIONS'**
  String get finQuotations;

  /// Button: make a quotation.
  ///
  /// In en, this message translates to:
  /// **'New quotation'**
  String get finNewQuotation;

  /// There are no quotations.
  ///
  /// In en, this message translates to:
  /// **'No quotations yet.'**
  String get finNoQuotations;

  /// A quotation's day and how many designs.
  ///
  /// In en, this message translates to:
  /// **'{day} · {count, plural, =1{1 design} other{{count} designs}}'**
  String finQuoteLine(String day, int count);

  /// Glance: what is due.
  ///
  /// In en, this message translates to:
  /// **'Due {amount}'**
  String finDue(String amount);

  /// Glance: the credit.
  ///
  /// In en, this message translates to:
  /// **'Credit {amount}'**
  String finCreditOf(String amount);

  /// A payment converted at its rate.
  ///
  /// In en, this message translates to:
  /// **'At 1 {from} = {rate} {to}: {amount}'**
  String finAtRate(String from, String rate, String to, String amount);

  /// Button: issue a payment's receipt.
  ///
  /// In en, this message translates to:
  /// **'Issue receipt'**
  String get finIssueReceipt;

  /// A date: day, short month, year.
  ///
  /// In en, this message translates to:
  /// **'{day} {month} {year}'**
  String finDay(String day, String month, String year);

  /// Title of the refund dialog.
  ///
  /// In en, this message translates to:
  /// **'Refund to {name}'**
  String finRefundTo(String name);

  /// Title of the payment dialog.
  ///
  /// In en, this message translates to:
  /// **'Payment from {name}'**
  String finPaymentFrom(String name);

  /// In the refund dialog.
  ///
  /// In en, this message translates to:
  /// **'Net paid: {amount}. A refund is money returned; it cannot be more than that.'**
  String finRefundNote(String amount);

  /// In the payment dialog.
  ///
  /// In en, this message translates to:
  /// **'The total is not final yet: {reason}'**
  String finNotFinalYet(String reason);

  /// In the payment dialog.
  ///
  /// In en, this message translates to:
  /// **'{label}: {total} · due {due}'**
  String finTotalDue(String label, String total, String due);

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Refund amount'**
  String get finRefundAmount;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get finAmount;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get finCurrency;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate (optional)'**
  String get finRateOptional;

  /// Help under the exchange rate.
  ///
  /// In en, this message translates to:
  /// **'With a rate it counts towards the {base} total, at this rate for good. Without one it is kept in {currency} and not added to the {base} total.'**
  String finRateHelp(String base, String currency);

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Refund method'**
  String get finRefundMethod;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get finPaymentMethod;

  /// Field: describe another payment method.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get finDescriptionOptional;

  /// Example description of another payment method.
  ///
  /// In en, this message translates to:
  /// **'Company cheque'**
  String get finDescriptionHint;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get finDate;

  /// Field: a refund's note.
  ///
  /// In en, this message translates to:
  /// **'Reason / note'**
  String get finReasonNote;

  /// Field: a payment's note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get finNote;

  /// Tick: issue a receipt with the payment.
  ///
  /// In en, this message translates to:
  /// **'Issue a receipt'**
  String get finIssueAReceipt;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Save refund'**
  String get finSaveRefund;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Save payment'**
  String get finSavePayment;

  /// [domain] Quotation status.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get qsDraft;

  /// [domain] Quotation status.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get qsIssued;

  /// [domain] Quotation status.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get qsAccepted;

  /// [domain] Quotation status.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get qsRejected;

  /// [domain] Quotation status.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get qsExpired;

  /// [domain] Quotation check.
  ///
  /// In en, this message translates to:
  /// **'Please complete all selected designs before creating the quotation.'**
  String get quoteIncomplete;

  /// [domain] Quotation check.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one design.'**
  String get quoteChooseOne;

  /// [domain] Quotation check, naming the designs.
  ///
  /// In en, this message translates to:
  /// **'{message} Not ready: {names}.'**
  String quoteNotReady(String message, String names);

  /// [domain] Quotation check.
  ///
  /// In en, this message translates to:
  /// **'The extra charge \"{name}\" is in {currency}, not {base}. Write it in {base} first.'**
  String quoteExtraCurrency(String name, String currency, String base);

  /// [domain] Quotation check.
  ///
  /// In en, this message translates to:
  /// **'The discount of {discount} is more than this quotation\'s subtotal, {subtotal}.'**
  String quoteDiscountExceeds(String discount, String subtotal);

  /// [domain] Quotation status check.
  ///
  /// In en, this message translates to:
  /// **'A quotation that is {status} cannot become {next}.'**
  String quoteCannotBecome(String status, String next);

  /// Title of the discount dialog.
  ///
  /// In en, this message translates to:
  /// **'Discount for {name}'**
  String discountFor(String name);

  /// Label in the discount dialog.
  ///
  /// In en, this message translates to:
  /// **'Discount type'**
  String get discountType;

  /// Choice: no discount.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get discountNoneChoice;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get discountReason;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Remove discount'**
  String get discountRemove;

  /// Title.
  ///
  /// In en, this message translates to:
  /// **'New quotation for {name}'**
  String quoteNewFor(String name);

  /// In the new quotation dialog.
  ///
  /// In en, this message translates to:
  /// **'The quotation keeps every price as it is now. A complete design is priced first; an incomplete one cannot be quoted.'**
  String get quoteKeepsPrices;

  /// In the new quotation dialog.
  ///
  /// In en, this message translates to:
  /// **'This customer has no designs yet.'**
  String get quoteNoDesigns;

  /// A design not yet priced.
  ///
  /// In en, this message translates to:
  /// **'Complete — priced when quoted'**
  String get quotePricedWhenQuoted;

  /// In the new quotation dialog.
  ///
  /// In en, this message translates to:
  /// **'Discount: {discount}'**
  String quoteDiscountLine(String discount);

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get quoteNotes;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Create quotation'**
  String get quoteCreate;

  /// Heading of a quotation.
  ///
  /// In en, this message translates to:
  /// **'QUOTATION'**
  String get quoteHeading;

  /// Under a quotation's number.
  ///
  /// In en, this message translates to:
  /// **'For {name} · made {day}'**
  String quoteFor(String name, String day);

  /// Added after a date: who did it.
  ///
  /// In en, this message translates to:
  /// **' by {who}'**
  String quoteBy(String who);

  /// Which price list a quotation used.
  ///
  /// In en, this message translates to:
  /// **'prices of list version {version}'**
  String quoteListVersion(int version);

  /// Warning on a quotation.
  ///
  /// In en, this message translates to:
  /// **'Design changed after quotation: {names}.'**
  String quoteDesignChanged(String names);

  /// Warning on a quotation.
  ///
  /// In en, this message translates to:
  /// **'The factory prices have changed since.'**
  String get quotePricesChanged;

  /// Warning on a quotation.
  ///
  /// In en, this message translates to:
  /// **'This quotation stays as it was offered; make a new one for the current figures.'**
  String get quoteStaysAsOffered;

  /// A design's own discount on a quotation.
  ///
  /// In en, this message translates to:
  /// **'Design discount ({discount})'**
  String quoteDesignDiscount(String discount);

  /// A status change and its day.
  ///
  /// In en, this message translates to:
  /// **'{status} — {day}'**
  String quoteStatusOn(String status, String day);

  /// Button: issue a quotation.
  ///
  /// In en, this message translates to:
  /// **'Issue'**
  String get quoteIssue;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Mark accepted'**
  String get quoteMarkAccepted;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Mark rejected'**
  String get quoteMarkRejected;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Mark expired'**
  String get quoteMarkExpired;

  /// Heading of a receipt.
  ///
  /// In en, this message translates to:
  /// **'RECEIPT'**
  String get rcpHeading;

  /// On a receipt.
  ///
  /// In en, this message translates to:
  /// **'Received from {name}'**
  String rcpReceivedFrom(String name);

  /// On a receipt.
  ///
  /// In en, this message translates to:
  /// **'Amount received'**
  String get rcpAmount;

  /// On a receipt.
  ///
  /// In en, this message translates to:
  /// **'At 1 {from} = {rate} {to}'**
  String rcpAtRate(String from, String rate, String to);

  /// On a receipt.
  ///
  /// In en, this message translates to:
  /// **'Date received'**
  String get rcpDate;

  /// On a receipt.
  ///
  /// In en, this message translates to:
  /// **'Balance after this payment'**
  String get rcpBalance;

  /// On a receipt.
  ///
  /// In en, this message translates to:
  /// **'Total not final when issued'**
  String get rcpNotFinal;

  /// On a receipt.
  ///
  /// In en, this message translates to:
  /// **'{amount} due'**
  String rcpDue(String amount);

  /// On a receipt.
  ///
  /// In en, this message translates to:
  /// **'{amount} credit'**
  String rcpCredit(String amount);

  /// On a receipt.
  ///
  /// In en, this message translates to:
  /// **'Paid in full'**
  String get rcpPaidInFull;

  /// On a receipt.
  ///
  /// In en, this message translates to:
  /// **'Issued {day}'**
  String rcpIssued(String day);

  /// On a receipt.
  ///
  /// In en, this message translates to:
  /// **' · for payment {id}'**
  String rcpForPayment(String id);

  /// [domain] Category of an extra charge.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get xcMaterial;

  /// [domain] Category of an extra charge.
  ///
  /// In en, this message translates to:
  /// **'Labour'**
  String get xcLabour;

  /// [domain] Category of an extra charge.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get xcService;

  /// [domain] Category of an extra charge.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get xcTransport;

  /// [domain] Category of an extra charge.
  ///
  /// In en, this message translates to:
  /// **'Installation'**
  String get xcInstallation;

  /// [domain] Category of an extra charge.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get xcOther;

  /// [domain] Unit of an extra charge, one.
  ///
  /// In en, this message translates to:
  /// **'piece'**
  String get xuPiece;

  /// [domain] Unit of an extra charge, more than one.
  ///
  /// In en, this message translates to:
  /// **'pieces'**
  String get xuPieces;

  /// [domain] Unit of an extra charge, one.
  ///
  /// In en, this message translates to:
  /// **'bottle'**
  String get xuBottle;

  /// [domain] Unit of an extra charge, more than one.
  ///
  /// In en, this message translates to:
  /// **'bottles'**
  String get xuBottles;

  /// [domain] Unit of an extra charge, one.
  ///
  /// In en, this message translates to:
  /// **'hour'**
  String get xuHour;

  /// [domain] Unit of an extra charge, more than one.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get xuHours;

  /// [domain] Unit of an extra charge, one.
  ///
  /// In en, this message translates to:
  /// **'metre'**
  String get xuMetre;

  /// [domain] Unit of an extra charge, more than one.
  ///
  /// In en, this message translates to:
  /// **'metres'**
  String get xuMetres;

  /// [domain] Unit of an extra charge, one.
  ///
  /// In en, this message translates to:
  /// **'square metre'**
  String get xuSquareMetre;

  /// [domain] Unit of an extra charge, more than one.
  ///
  /// In en, this message translates to:
  /// **'square metres'**
  String get xuSquareMetres;

  /// [domain] Unit of an extra charge, one.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get xuKg;

  /// [domain] Unit of an extra charge, more than one.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get xuKgs;

  /// [domain] Unit of an extra charge, one.
  ///
  /// In en, this message translates to:
  /// **'set'**
  String get xuSet;

  /// [domain] Unit of an extra charge, more than one.
  ///
  /// In en, this message translates to:
  /// **'sets'**
  String get xuSets;

  /// [domain] Unit of an extra charge, one.
  ///
  /// In en, this message translates to:
  /// **'roll'**
  String get xuRoll;

  /// [domain] Unit of an extra charge, more than one.
  ///
  /// In en, this message translates to:
  /// **'rolls'**
  String get xuRolls;

  /// [domain] Unit of an extra charge, one.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get xuDay;

  /// [domain] Unit of an extra charge, more than one.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get xuDays;

  /// [domain] Unit of an extra charge, one.
  ///
  /// In en, this message translates to:
  /// **'trip'**
  String get xuTrip;

  /// [domain] Unit of an extra charge, more than one.
  ///
  /// In en, this message translates to:
  /// **'trips'**
  String get xuTrips;

  /// [domain] Extra charge check.
  ///
  /// In en, this message translates to:
  /// **'Enter what the extra is.'**
  String get xNameNeeded;

  /// [domain] Extra charge check.
  ///
  /// In en, this message translates to:
  /// **'Enter the quantity.'**
  String get xQtyEnter;

  /// [domain] Extra charge check.
  ///
  /// In en, this message translates to:
  /// **'The quantity must be more than nothing.'**
  String get xQtyMore;

  /// [domain] Extra charge check.
  ///
  /// In en, this message translates to:
  /// **'Choose or type the unit.'**
  String get xUnitNeeded;

  /// [domain] Extra charge check.
  ///
  /// In en, this message translates to:
  /// **'Enter the unit price.'**
  String get xPriceEnter;

  /// [domain] Extra charge check.
  ///
  /// In en, this message translates to:
  /// **'A unit price cannot be below nothing.'**
  String get xPriceNotBelow;

  /// [domain] Extra charge check.
  ///
  /// In en, this message translates to:
  /// **'Enter the quantity as a number, such as 5 or 2.5.'**
  String get xQtyNumber;

  /// [domain] Extra charge check.
  ///
  /// In en, this message translates to:
  /// **'Enter the quantity to three decimal places at most.'**
  String get xQtyPlaces;

  /// [domain] Extra charge check.
  ///
  /// In en, this message translates to:
  /// **'Enter the unit price as a number, such as 3.25.'**
  String get xPriceNumber;

  /// [domain] Extra charge check.
  ///
  /// In en, this message translates to:
  /// **'Enter the unit price to the cent — two decimal places at most.'**
  String get xPricePlaces;

  /// [domain] An extra that may charge twice for one thing.
  ///
  /// In en, this message translates to:
  /// **'{what} is already calculated from the design. Add this only if it is an additional charge.'**
  String xAlreadyOne(String what);

  /// [domain] An extra that may charge twice for some things.
  ///
  /// In en, this message translates to:
  /// **'{what} are already calculated from the design. Add this only if it is an additional charge.'**
  String xAlreadyMany(String what);

  /// [domain] A group already priced and what it comes to.
  ///
  /// In en, this message translates to:
  /// **'{what} ({amount})'**
  String xAlreadyItem(String what, String amount);

  /// Extra dialog check.
  ///
  /// In en, this message translates to:
  /// **'Tick \"This is an additional charge\" to add it on top.'**
  String get xTickAdditional;

  /// Title of the extra dialog.
  ///
  /// In en, this message translates to:
  /// **'Add extra'**
  String get xAddTitle;

  /// Title of the extra dialog.
  ///
  /// In en, this message translates to:
  /// **'Edit extra'**
  String get xEditTitle;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get xName;

  /// Example extras.
  ///
  /// In en, this message translates to:
  /// **'Silicone, labour, transport…'**
  String get xNameHint;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get xCategory;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get xQuantity;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get xUnit;

  /// Choice: type a unit.
  ///
  /// In en, this message translates to:
  /// **'Other unit…'**
  String get xOtherUnit;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Unit, in words'**
  String get xUnitInWords;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get xUnitPrice;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get xNoteOptional;

  /// Row.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get xTotal;

  /// Tick.
  ///
  /// In en, this message translates to:
  /// **'This is an additional charge'**
  String get xIsAdditional;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Save extra'**
  String get xSave;

  /// Title.
  ///
  /// In en, this message translates to:
  /// **'Remove extra'**
  String get xRemoveTitle;

  /// Confirmation.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" ({amount}) from {from}?'**
  String xRemoveAsk(String name, String amount, String from);

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String xEditOf(String name);

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String xRemoveOf(String name);

  /// Heading of the breakdown.
  ///
  /// In en, this message translates to:
  /// **'AUTOMATIC DESIGN COSTS'**
  String get pbAutomatic;

  /// Row.
  ///
  /// In en, this message translates to:
  /// **'Combined profile cost'**
  String get pbCombinedProfile;

  /// Glass or panel that the design does not have.
  ///
  /// In en, this message translates to:
  /// **'Not used'**
  String get pbNotUsed;

  /// Row.
  ///
  /// In en, this message translates to:
  /// **'Design cost'**
  String get pbDesignCost;

  /// Heading.
  ///
  /// In en, this message translates to:
  /// **'EXTRA CHARGES'**
  String get pbExtras;

  /// No extras.
  ///
  /// In en, this message translates to:
  /// **'No extra charges.'**
  String get pbNoExtras;

  /// Row.
  ///
  /// In en, this message translates to:
  /// **'Extras cost'**
  String get pbExtrasCost;

  /// Button: give a discount.
  ///
  /// In en, this message translates to:
  /// **'Give'**
  String get pbGive;

  /// Button: change the discount.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get pbChange;

  /// [domain] A percentage line: so much per cent of an amount.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of {amount}'**
  String ppPercentOf(String percent, String amount);

  /// [domain] A fixed price line.
  ///
  /// In en, this message translates to:
  /// **'fixed'**
  String get ppFixed;

  /// Heading of the price panel.
  ///
  /// In en, this message translates to:
  /// **'PRICE'**
  String get ppPrice;

  /// While the price list loads.
  ///
  /// In en, this message translates to:
  /// **'Reading the price list…'**
  String get ppReadingList;

  /// Row: the design's total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get ppTotal;

  /// Points to the geometry check.
  ///
  /// In en, this message translates to:
  /// **'Please correct the geometry shown under the drawing to calculate the price.'**
  String get ppCorrectGeometry;

  /// A stale price.
  ///
  /// In en, this message translates to:
  /// **'Previous calculation: {amount} — not current'**
  String ppPrevious(String amount);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Show the breakdown'**
  String get ppShowBreakdown;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Hide the breakdown'**
  String get ppHideBreakdown;

  /// Under a price from the example list.
  ///
  /// In en, this message translates to:
  /// **'Example prices — the workshop owner sets the real ones.'**
  String get ppExamplePrices;

  /// Under a price from a migrated list.
  ///
  /// In en, this message translates to:
  /// **'Prices carried over from an older price list.'**
  String get ppCarriedOver;

  /// Switch.
  ///
  /// In en, this message translates to:
  /// **'Include installation'**
  String get ppInstallation;

  /// Measurement.
  ///
  /// In en, this message translates to:
  /// **'Border length'**
  String get ppBorderLength;

  /// Measurement.
  ///
  /// In en, this message translates to:
  /// **'Internal line length'**
  String get ppLineLength;

  /// Measurement.
  ///
  /// In en, this message translates to:
  /// **'Combined profile length'**
  String get ppCombinedLength;

  /// Measurement.
  ///
  /// In en, this message translates to:
  /// **'Border and internal lines'**
  String get ppBorderAndLines;

  /// Measurement.
  ///
  /// In en, this message translates to:
  /// **'Opening profile'**
  String get ppOpeningProfile;

  /// Measurement.
  ///
  /// In en, this message translates to:
  /// **'Other profile'**
  String get ppOtherProfile;

  /// Measurement.
  ///
  /// In en, this message translates to:
  /// **'Total profile'**
  String get ppTotalProfile;

  /// Tool.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get toolSelect;

  /// Tool hint.
  ///
  /// In en, this message translates to:
  /// **'Tap a part to pick it. Drag to move it.'**
  String get toolSelectHint;

  /// Tool: draw freehand.
  ///
  /// In en, this message translates to:
  /// **'Freehand'**
  String get toolPen;

  /// Tool hint.
  ///
  /// In en, this message translates to:
  /// **'Draw as you would on paper. Pause with the pen down to straighten.'**
  String get toolPenHint;

  /// Tool.
  ///
  /// In en, this message translates to:
  /// **'Straight line'**
  String get toolLine;

  /// Tool hint.
  ///
  /// In en, this message translates to:
  /// **'Two taps, or drag from one end to the other.'**
  String get toolLineHint;

  /// Tool.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get toolRectangle;

  /// Tool hint.
  ///
  /// In en, this message translates to:
  /// **'Drag a corner to the opposite corner.'**
  String get toolRectangleHint;

  /// Tool: a chain of lines.
  ///
  /// In en, this message translates to:
  /// **'Polyline'**
  String get toolPolyline;

  /// Tool hint.
  ///
  /// In en, this message translates to:
  /// **'Tap each corner. Tap the first one again to close.'**
  String get toolPolylineHint;

  /// Tool.
  ///
  /// In en, this message translates to:
  /// **'Dimension'**
  String get toolDimension;

  /// Tool hint.
  ///
  /// In en, this message translates to:
  /// **'Drag between the two points you are measuring.'**
  String get toolDimensionHint;

  /// Tool.
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get toolArrow;

  /// Tool hint.
  ///
  /// In en, this message translates to:
  /// **'Drag from the tail to the point.'**
  String get toolArrowHint;

  /// Tool.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get toolNote;

  /// Tool hint.
  ///
  /// In en, this message translates to:
  /// **'Tap where the note goes, then type it.'**
  String get toolNoteHint;

  /// Tool.
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get toolEraser;

  /// Tool hint.
  ///
  /// In en, this message translates to:
  /// **'Tap a stroke to rub it out.'**
  String get toolEraserHint;

  /// Tooltip on a drawing tool away from the drawing.
  ///
  /// In en, this message translates to:
  /// **'{tool}\nTap to go back to the drawing and use it.'**
  String toolGoBack(String tool);

  /// View: the drawing.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get viewDraw;

  /// View: the technical drawing.
  ///
  /// In en, this message translates to:
  /// **'CAD drawing'**
  String get viewCad;

  /// View, short.
  ///
  /// In en, this message translates to:
  /// **'CAD'**
  String get viewCadShort;

  /// View: the model.
  ///
  /// In en, this message translates to:
  /// **'3D model'**
  String get view3d;

  /// View, short.
  ///
  /// In en, this message translates to:
  /// **'3D'**
  String get view3dShort;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Fit the drawing to the view'**
  String get cadFit;

  /// Title of the note dialog.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get cadNoteTitle;

  /// Hint.
  ///
  /// In en, this message translates to:
  /// **'Type your note'**
  String get cadNoteHint;

  /// Tool inside an opening.
  ///
  /// In en, this message translates to:
  /// **'Horizontal line'**
  String get inHorizontalLine;

  /// Tool inside an opening.
  ///
  /// In en, this message translates to:
  /// **'Vertical line'**
  String get inVerticalLine;

  /// Tool inside an opening.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get inErase;

  /// Caption of the tools inside an opening.
  ///
  /// In en, this message translates to:
  /// **'Inside {what} — {size}'**
  String cadInside(String what, String size);

  /// Caption: an opening with no mechanism.
  ///
  /// In en, this message translates to:
  /// **'this opening'**
  String get cadThisOpening;

  /// Layer.
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get layDimensions;

  /// Layer.
  ///
  /// In en, this message translates to:
  /// **'Hatching'**
  String get layHatching;

  /// Layer.
  ///
  /// In en, this message translates to:
  /// **'Openings'**
  String get layOpenings;

  /// Layer.
  ///
  /// In en, this message translates to:
  /// **'Centre lines'**
  String get layCentreLines;

  /// Layer.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get layNotes;

  /// Layer.
  ///
  /// In en, this message translates to:
  /// **'My drawing'**
  String get layMyDrawing;

  /// Layer: hidden detail.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get layHidden;

  /// Layer.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get layGrid;

  /// Layer: the grips to drag.
  ///
  /// In en, this message translates to:
  /// **'Handles'**
  String get layHandles;

  /// Layer: snap to geometry.
  ///
  /// In en, this message translates to:
  /// **'Snap'**
  String get laySnap;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get layFit;

  /// Status bar.
  ///
  /// In en, this message translates to:
  /// **'{sections} sections · {bars} bars · {openings} openings'**
  String cadCounts(int sections, int bars, int openings);

  /// Status bar.
  ///
  /// In en, this message translates to:
  /// **'Tap a line, a bar or a pane'**
  String get cadTapSomething;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Fit the model to the view'**
  String get mdFit;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get mdDepth;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get mdProfile;

  /// Under depth and profile.
  ///
  /// In en, this message translates to:
  /// **'Both are the design. The drawing changes with them.'**
  String get mdBothDesign;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'How far the leaves are swung. A way of looking at the model; it changes nothing.'**
  String get mdOpenHelp;

  /// Slider: how open the leaves are.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get mdOpen;

  /// Named view.
  ///
  /// In en, this message translates to:
  /// **'Iso'**
  String get mdIso;

  /// Named view.
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get mdFront;

  /// Named view.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get mdBack;

  /// Named view.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get mdLeft;

  /// Named view.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get mdRight;

  /// Named view.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get mdTop;

  /// Named view.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get mdBottom;

  /// Tooltip of a named view.
  ///
  /// In en, this message translates to:
  /// **'{name} view'**
  String mdViewOf(String name);

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Ground plane'**
  String get mdGround;

  /// Readout.
  ///
  /// In en, this message translates to:
  /// **'{sections} sections · {bars} bars'**
  String mdCounts(int sections, int bars);

  /// Camera readout.
  ///
  /// In en, this message translates to:
  /// **'yaw {yaw}°  pitch {pitch}°  ×{zoom}'**
  String mdCamera(int yaw, int pitch, String zoom);

  /// Model with nothing drawn.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show yet'**
  String get mdNothing;

  /// Model with nothing drawn.
  ///
  /// In en, this message translates to:
  /// **'Draw an outline and read the drawing. The model is built from your lines — there is no stock model to show in the meantime.'**
  String get mdNothingHelp;

  /// Tooltip: play the leaves.
  ///
  /// In en, this message translates to:
  /// **'Open, pause and close'**
  String get mdPlay;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Sizes'**
  String get wsSizes;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get wsMaterial;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get wsUndo;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get wsRedo;

  /// Notice.
  ///
  /// In en, this message translates to:
  /// **'Design saved.'**
  String get wsSaved;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide my drawing'**
  String get wsHideDrawing;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Show my drawing'**
  String get wsShowDrawing;

  /// Button: read the drawing again.
  ///
  /// In en, this message translates to:
  /// **'Read again'**
  String get wsReadAgain;

  /// Button: the list of parts.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get wsParts;

  /// Button: the panel of details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get wsDetails;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Glass or panel'**
  String get wsGlassOrPanel;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get wsEdit;

  /// Tooltip: unpick.
  ///
  /// In en, this message translates to:
  /// **'Let it go'**
  String get wsLetGo;

  /// Notice.
  ///
  /// In en, this message translates to:
  /// **'Your drawing has changed.'**
  String get wsChanged;

  /// Notice.
  ///
  /// In en, this message translates to:
  /// **'Your drawing has changes that have not been read yet.'**
  String get wsChangesNotRead;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Read it'**
  String get wsReadIt;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Read my drawing'**
  String get wsReadMyDrawing;

  /// [domain] Rate check.
  ///
  /// In en, this message translates to:
  /// **'Enter a figure.'**
  String get ccEnterFigure;

  /// [domain] Rate check.
  ///
  /// In en, this message translates to:
  /// **'A rate cannot be below nothing.'**
  String get ccRateNotBelow;

  /// [domain] Colour check.
  ///
  /// In en, this message translates to:
  /// **'Colour name is required.'**
  String get ccNameRequired;

  /// [domain] Colour check.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one material.'**
  String get ccChooseMaterial;

  /// [domain] Colour check.
  ///
  /// In en, this message translates to:
  /// **'The price list has no {material} profile to sell a colour in.'**
  String ccNoProfile(String material);

  /// [domain] Colour check.
  ///
  /// In en, this message translates to:
  /// **'{material} colour rate is required for a colour that applies to {material}.'**
  String ccRateRequired(String material);

  /// [domain] Colour check.
  ///
  /// In en, this message translates to:
  /// **'An active colour is already called {name} for {material}.'**
  String ccNameTaken(String name, String material);

  /// [domain] Colour check.
  ///
  /// In en, this message translates to:
  /// **'This colour is not in the price list.'**
  String get ccNotInList;

  /// A colour's rate on a material, none set.
  ///
  /// In en, this message translates to:
  /// **'{material} not priced'**
  String fcNotPriced(String material);

  /// A colour's rate a metre on a material.
  ///
  /// In en, this message translates to:
  /// **'{material} {amount}/m'**
  String fcPerMetre(String material, String amount);

  /// Notice.
  ///
  /// In en, this message translates to:
  /// **'Colour added.'**
  String get fcAdded;

  /// Notice.
  ///
  /// In en, this message translates to:
  /// **'Colour saved.'**
  String get fcSaved;

  /// Confirmation title: stop offering a colour.
  ///
  /// In en, this message translates to:
  /// **'Retire {name}?'**
  String fcRetireAsk(String name);

  /// Confirmation.
  ///
  /// In en, this message translates to:
  /// **'It will no longer be offered for new designs. Every design already in it keeps it, is still shown in it and is still priced at its rate. Nothing is deleted, and it can be brought back.'**
  String get fcRetireBody;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Retire colour'**
  String get fcRetire;

  /// Notice.
  ///
  /// In en, this message translates to:
  /// **'{name} retired.'**
  String fcRetired(String name);

  /// Notice.
  ///
  /// In en, this message translates to:
  /// **'{name} is offered again.'**
  String fcOfferedAgain(String name);

  /// Heading.
  ///
  /// In en, this message translates to:
  /// **'COLOURS'**
  String get fcColours;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Add colour'**
  String get fcAdd;

  /// Under the colours heading.
  ///
  /// In en, this message translates to:
  /// **'What each colour adds on each material it is sold in, by the metre of profile and as a share of the profile\'s price. A retired colour is not offered for new designs; designs already in it keep it.'**
  String get fcIntro;

  /// Empty catalog.
  ///
  /// In en, this message translates to:
  /// **'No colours yet. Every colour is priced as any other colour.'**
  String get fcNone;

  /// A colour's status.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get fcActive;

  /// A colour's status.
  ///
  /// In en, this message translates to:
  /// **'Retired'**
  String get fcRetiredStatus;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String fcEdit(String name);

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Retire {name}'**
  String fcRetireOf(String name);

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Offer {name} again'**
  String fcOfferAgain(String name);

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Colour name'**
  String get fcName;

  /// Under the name.
  ///
  /// In en, this message translates to:
  /// **'Renaming keeps it the same colour: every design in it shows the new name.'**
  String get fcRenaming;

  /// Label.
  ///
  /// In en, this message translates to:
  /// **'Swatch'**
  String get fcSwatch;

  /// Field: the colour's hex code.
  ///
  /// In en, this message translates to:
  /// **'Or its code'**
  String get fcCode;

  /// Switch.
  ///
  /// In en, this message translates to:
  /// **'Standard colour'**
  String get fcStandard;

  /// Label.
  ///
  /// In en, this message translates to:
  /// **'Sold in, and what it adds'**
  String get fcSoldIn;

  /// Field: the rate a metre.
  ///
  /// In en, this message translates to:
  /// **'A metre'**
  String get fcAMetre;

  /// Field: the share of the profile's price.
  ///
  /// In en, this message translates to:
  /// **'On the profile'**
  String get fcOnProfile;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Save colour'**
  String get fcSave;

  /// [domain] Factory price check.
  ///
  /// In en, this message translates to:
  /// **'A price is needed here.'**
  String get rfNeeded;

  /// [domain] Factory price check.
  ///
  /// In en, this message translates to:
  /// **'Enter a figure of 0 or more.'**
  String get rfZeroOrMore;

  /// [domain] Factory price check.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number.'**
  String get rfWhole;

  /// [domain] Price list section.
  ///
  /// In en, this message translates to:
  /// **'Glass (single sheet)'**
  String get rfGlassSingle;

  /// [domain] Price list section.
  ///
  /// In en, this message translates to:
  /// **'Sealed glass unit'**
  String get rfSealed;

  /// [domain] Price list section.
  ///
  /// In en, this message translates to:
  /// **'Panel'**
  String get rfPanel;

  /// [domain] Price list field: a colour not named.
  ///
  /// In en, this message translates to:
  /// **'Any other colour'**
  String get rfAnyOtherColour;

  /// [domain] Price list section.
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get rfHardware;

  /// [domain] Price list section.
  ///
  /// In en, this message translates to:
  /// **'Sliding'**
  String get rfSliding;

  /// [domain] Price list field: a sliding track.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get rfTrack;

  /// [domain] Price list field.
  ///
  /// In en, this message translates to:
  /// **'Roller'**
  String get rfRoller;

  /// [domain] Price list field.
  ///
  /// In en, this message translates to:
  /// **'Rollers on each sliding panel'**
  String get rfRollersPerPanel;

  /// [domain] Price list section.
  ///
  /// In en, this message translates to:
  /// **'Installation'**
  String get rfInstallation;

  /// [domain] Price list field: a fixed figure a design.
  ///
  /// In en, this message translates to:
  /// **'Each design'**
  String get rfEachDesign;

  /// [domain] Price list field: a figure a square metre.
  ///
  /// In en, this message translates to:
  /// **'By area'**
  String get rfByArea;

  /// [domain] Price list section.
  ///
  /// In en, this message translates to:
  /// **'Border and internal lines'**
  String get rfBorderLines;

  /// [domain] Price list section.
  ///
  /// In en, this message translates to:
  /// **'Opening profile'**
  String get rfOpeningProfile;

  /// [domain] Price list section.
  ///
  /// In en, this message translates to:
  /// **'Any other colour — {material}'**
  String rfAnyOtherColourOf(String material);

  /// [domain] Price list field.
  ///
  /// In en, this message translates to:
  /// **'A metre'**
  String get rfAMetre;

  /// [domain] Price list field.
  ///
  /// In en, this message translates to:
  /// **'On the profile'**
  String get rfOnProfile;

  /// [domain] Price list section.
  ///
  /// In en, this message translates to:
  /// **'Labour — {category}'**
  String rfLabourOf(String category);

  /// [domain] Price list field.
  ///
  /// In en, this message translates to:
  /// **'On the materials'**
  String get rfOnMaterials;

  /// [domain] Unit after a price field.
  ///
  /// In en, this message translates to:
  /// **'each'**
  String get rfUnitEach;

  /// [domain] Unit after a price field.
  ///
  /// In en, this message translates to:
  /// **'fixed'**
  String get rfUnitFixed;

  /// [domain] Unit after a price field.
  ///
  /// In en, this message translates to:
  /// **'rollers'**
  String get rfUnitRollers;

  /// Title.
  ///
  /// In en, this message translates to:
  /// **'Factory prices'**
  String get fpTitle;

  /// Notice.
  ///
  /// In en, this message translates to:
  /// **'{done} Prices kept as version {version}; every design priced before is now to be recalculated.'**
  String fpColoursKept(String done, int version);

  /// Notice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 figure needs correcting before the prices can be kept.} other{{count} figures need correcting before the prices can be kept.}}'**
  String fpNeedCorrecting(int count);

  /// Notice.
  ///
  /// In en, this message translates to:
  /// **'Prices kept. Every design priced before is now to be recalculated.'**
  String get fpKept;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get fpLock;

  /// Card.
  ///
  /// In en, this message translates to:
  /// **'Only the workshop owner can change prices.'**
  String get fpOnlyOwner;

  /// Card.
  ///
  /// In en, this message translates to:
  /// **'These are the rates every design is priced by. Staff can read them and price designs by them.'**
  String get fpRatesNote;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Unlock as owner'**
  String get fpUnlock;

  /// Note.
  ///
  /// In en, this message translates to:
  /// **'In {currency}. A figure left empty is not priced: a design using it says so rather than being priced at nothing.'**
  String fpInCurrency(String currency);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Keep prices'**
  String get fpKeep;

  /// Hint in an empty optional figure.
  ///
  /// In en, this message translates to:
  /// **'not priced'**
  String get fpNotPriced;

  /// PIN check.
  ///
  /// In en, this message translates to:
  /// **'The two PINs are not the same.'**
  String get pinNotSame;

  /// PIN check.
  ///
  /// In en, this message translates to:
  /// **'An owner PIN is already set.'**
  String get pinAlreadySet;

  /// PIN check.
  ///
  /// In en, this message translates to:
  /// **'That is not the owner PIN.'**
  String get pinWrong;

  /// Title.
  ///
  /// In en, this message translates to:
  /// **'Set the owner PIN'**
  String get pinSetTitle;

  /// Note.
  ///
  /// In en, this message translates to:
  /// **'No owner PIN is set on this device. The PIN you set now is what signs the owner in from here on — to change the factory prices, give discounts and manage staff.'**
  String get pinSetNote;

  /// Note.
  ///
  /// In en, this message translates to:
  /// **'Enter the owner PIN.'**
  String get pinEnterOwner;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Owner PIN'**
  String get pinOwner;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'The PIN again'**
  String get pinAgain;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get pinSet;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get pinUnlock;

  /// Who is at the device.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {who}'**
  String acSignedInAs(String who);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get acSignIn;

  /// Who is at the device.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet — working as staff'**
  String get acNoAccounts;

  /// Who is at the device.
  ///
  /// In en, this message translates to:
  /// **'Nobody signed in'**
  String get acNobody;

  /// Menu.
  ///
  /// In en, this message translates to:
  /// **'Sign in as owner'**
  String get acAsOwner;

  /// Menu.
  ///
  /// In en, this message translates to:
  /// **'Sign in as staff'**
  String get acAsStaff;

  /// Menu and title.
  ///
  /// In en, this message translates to:
  /// **'Staff & permissions'**
  String get acStaffPermissions;

  /// Menu.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get acSignOut;

  /// Sign-in check.
  ///
  /// In en, this message translates to:
  /// **'Choose who you are.'**
  String get acChooseWho;

  /// Sign-in check.
  ///
  /// In en, this message translates to:
  /// **'That is not their PIN.'**
  String get acWrongPin;

  /// Sign-in dialog.
  ///
  /// In en, this message translates to:
  /// **'No member of staff has been added yet. The owner adds them under Staff & permissions.'**
  String get acNoStaffYet;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Who'**
  String get acWho;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get acPin;

  /// Button and title.
  ///
  /// In en, this message translates to:
  /// **'Add staff member'**
  String get acAddStaff;

  /// Staff screen.
  ///
  /// In en, this message translates to:
  /// **'The owner may do everything. Each member of staff may do what is ticked here, and nothing else. With nobody signed in, the device may only look once any member of staff is active.'**
  String get acIntro;

  /// Staff screen.
  ///
  /// In en, this message translates to:
  /// **'No member of staff has been added yet.'**
  String get acNoStaff;

  /// A member of staff's status.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get acActive;

  /// A member of staff's status.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get acInactive;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get acName;

  /// Add staff dialog.
  ///
  /// In en, this message translates to:
  /// **'They start able to look and nothing more. Tick what else they may do on their card.'**
  String get acStartLooking;

  /// [domain] A design's own discount check.
  ///
  /// In en, this message translates to:
  /// **'The total is not final yet. A fixed discount can be given once it is priced.'**
  String get discountDesignNotFinal;

  /// Parts list, empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been read from your drawing yet.'**
  String get ctNothingRead;

  /// Parts list group.
  ///
  /// In en, this message translates to:
  /// **'Bars'**
  String get ctBars;

  /// Parts list group.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get ctSections;

  /// Parts list group.
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get ctHardware;

  /// Parts list group.
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get ctDimensions;

  /// Parts list group.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get ctNotes;

  /// A dimension the user stated.
  ///
  /// In en, this message translates to:
  /// **'you typed this'**
  String get ctTyped;

  /// A dimension as drawn.
  ///
  /// In en, this message translates to:
  /// **'as drawn'**
  String get ctAsDrawn;

  /// A section holding panes.
  ///
  /// In en, this message translates to:
  /// **'{size} · holds {count}'**
  String ctHolds(String size, int count);

  /// A bar inside a section.
  ///
  /// In en, this message translates to:
  /// **'{length} · inside'**
  String ctInside(String length);

  /// Where a hinge is.
  ///
  /// In en, this message translates to:
  /// **'{length} from the left'**
  String ctFromLeft(String length);

  /// Where a hinge is.
  ///
  /// In en, this message translates to:
  /// **'{length} up'**
  String ctUp(String length);

  /// Where a handle is.
  ///
  /// In en, this message translates to:
  /// **'{place} · on the opening'**
  String ctOnOpening(String place);

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'{material} profile'**
  String poProfileOf(String material);

  /// Helper.
  ///
  /// In en, this message translates to:
  /// **'Some parts are set on their own below.'**
  String get poSomeOwn;

  /// Helper.
  ///
  /// In en, this message translates to:
  /// **'Choose the profile the factory makes it in.'**
  String get poChooseProfile;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Hide the parts'**
  String get poHideParts;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Set each part'**
  String get poEachPart;

  /// A part following the design's profile.
  ///
  /// In en, this message translates to:
  /// **'As the design ({category})'**
  String poAsDesignOf(String category);

  /// A part following the design's profile.
  ///
  /// In en, this message translates to:
  /// **'As the design'**
  String get poAsDesign;

  /// Switch.
  ///
  /// In en, this message translates to:
  /// **'Include glass in price'**
  String get poIncludeGlass;

  /// Note.
  ///
  /// In en, this message translates to:
  /// **'Glass is not included: its area is measured and not charged.'**
  String get poGlassMeasured;

  /// Note.
  ///
  /// In en, this message translates to:
  /// **'Glass is not included.'**
  String get poGlassOff;

  /// Note.
  ///
  /// In en, this message translates to:
  /// **'Glass is charged by its measured area.'**
  String get poGlassCharged;

  /// Note.
  ///
  /// In en, this message translates to:
  /// **'There is no measurable glass to price.'**
  String get poNoGlass;

  /// Title of the sizes form.
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get mfTitle;

  /// Sizes form.
  ///
  /// In en, this message translates to:
  /// **'Enter the real size of each part in centimetres. Nothing is guessed from the sketch; a size that follows from the others is worked out for you.'**
  String get mfIntro;

  /// Sizes form.
  ///
  /// In en, this message translates to:
  /// **'Every size is given.'**
  String get mfAllGiven;

  /// Sizes form.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 size still to give.} other{{count} sizes still to give.}}'**
  String mfLeft(int count);

  /// A size worked out from the rest.
  ///
  /// In en, this message translates to:
  /// **'from the others'**
  String get mfFromOthers;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Calculate price'**
  String get paCalculate;

  /// Price button, no permission.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to view prices.'**
  String get paNotAllowed;

  /// Price button.
  ///
  /// In en, this message translates to:
  /// **'The price is still being worked out.'**
  String get paWorkingOut;

  /// Price button.
  ///
  /// In en, this message translates to:
  /// **'Please complete the incomplete part of the design to calculate the price.'**
  String get paCompleteDesign;

  /// Where an extra is removed from.
  ///
  /// In en, this message translates to:
  /// **'this design'**
  String get paThisDesign;

  /// Title.
  ///
  /// In en, this message translates to:
  /// **'Discount on {name}'**
  String paDiscountOn(String name);

  /// Caption.
  ///
  /// In en, this message translates to:
  /// **'Off this design alone: its cost and its extras together.'**
  String get paDesignAlone;

  /// Heading.
  ///
  /// In en, this message translates to:
  /// **'DESIGN PRICE'**
  String get paDesignPrice;

  /// On the price sheet.
  ///
  /// In en, this message translates to:
  /// **'Category: {category}'**
  String paCategory(String category);

  /// Price sheet.
  ///
  /// In en, this message translates to:
  /// **'This design cannot be priced as it is.'**
  String get paCannot;

  /// Heading.
  ///
  /// In en, this message translates to:
  /// **'MATERIAL MEASUREMENTS'**
  String get paMeasurements;

  /// Heading.
  ///
  /// In en, this message translates to:
  /// **'COST BREAKDOWN'**
  String get paBreakdown;

  /// Heading.
  ///
  /// In en, this message translates to:
  /// **'FINAL TOTAL'**
  String get paFinalTotal;

  /// View mode.
  ///
  /// In en, this message translates to:
  /// **'Technical'**
  String get vmTechnical;

  /// View mode hint.
  ///
  /// In en, this message translates to:
  /// **'A line drawing with the overall sizes.'**
  String get vmTechnicalHint;

  /// View mode.
  ///
  /// In en, this message translates to:
  /// **'Shaded'**
  String get vmShaded;

  /// View mode hint.
  ///
  /// In en, this message translates to:
  /// **'One colour, lit, so the form reads on its own.'**
  String get vmShadedHint;

  /// View mode.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get vmMaterial;

  /// View mode hint.
  ///
  /// In en, this message translates to:
  /// **'Glass, panel, frame and metal as they are made.'**
  String get vmMaterialHint;

  /// View mode.
  ///
  /// In en, this message translates to:
  /// **'Realistic'**
  String get vmRealistic;

  /// View mode hint.
  ///
  /// In en, this message translates to:
  /// **'Materials, light and shadow, as it will look.'**
  String get vmRealisticHint;

  /// View mode.
  ///
  /// In en, this message translates to:
  /// **'Wireframe'**
  String get vmWireframe;

  /// View mode hint.
  ///
  /// In en, this message translates to:
  /// **'Every edge, including the ones behind.'**
  String get vmWireframeHint;

  /// [domain] Name of a row of figures on the technical drawing: the overall size.
  ///
  /// In en, this message translates to:
  /// **'Overall'**
  String get dimOverall;

  /// [domain] Name of a row of figures: the main divisions' clear openings.
  ///
  /// In en, this message translates to:
  /// **'Daylight'**
  String get dimDaylight;

  /// [domain] Name of a row of figures: each opening's size.
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get dimOpening;

  /// [domain] Name of a row of figures: the divisions inside a part.
  ///
  /// In en, this message translates to:
  /// **'Division'**
  String get dimDivision;

  /// [domain] Name of a row of figures: a side of an angled frame.
  ///
  /// In en, this message translates to:
  /// **'Side'**
  String get dimSide;

  /// [domain] A figure being typed over.
  ///
  /// In en, this message translates to:
  /// **'Overall width'**
  String get dimOverallWidth;

  /// [domain] A figure being typed over.
  ///
  /// In en, this message translates to:
  /// **'Overall height'**
  String get dimOverallHeight;

  /// [domain] A figure being typed over: the width of a kind of part.
  ///
  /// In en, this message translates to:
  /// **'{what} width'**
  String dimKindWidth(String what);

  /// [domain] A figure being typed over: the height of a kind of part.
  ///
  /// In en, this message translates to:
  /// **'{what} height'**
  String dimKindHeight(String what);

  /// [domain] A figure being typed over.
  ///
  /// In en, this message translates to:
  /// **'Section width'**
  String get dimSectionWidth;

  /// [domain] A figure being typed over.
  ///
  /// In en, this message translates to:
  /// **'Section height'**
  String get dimSectionHeight;

  /// [domain] A drawn dimension being typed over.
  ///
  /// In en, this message translates to:
  /// **'Real size'**
  String get dimRealSize;

  /// [domain] Written on a pane of glass on the technical drawing.
  ///
  /// In en, this message translates to:
  /// **'GLASS'**
  String get cadGlass;

  /// [domain] Written on a pane of tinted or frosted glass.
  ///
  /// In en, this message translates to:
  /// **'{look} GLASS'**
  String cadLookGlass(String look);

  /// [domain] Written by a leaf that opens inward.
  ///
  /// In en, this message translates to:
  /// **'IN'**
  String get cadIn;

  /// [domain] Written by a leaf that opens outward.
  ///
  /// In en, this message translates to:
  /// **'OUT'**
  String get cadOut;

  /// Title of the material form.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get mtTitle;

  /// Material form.
  ///
  /// In en, this message translates to:
  /// **'Read your drawing first: its parts are what glass or panel goes into.'**
  String get mtReadFirst;

  /// Material form.
  ///
  /// In en, this message translates to:
  /// **'Choose glass or panel for any part. Only what fills the part changes — every line stays where you drew it.'**
  String get mtChoose;

  /// A colour the catalog does not name.
  ///
  /// In en, this message translates to:
  /// **'{name} (special)'**
  String pcSpecial(String name);

  /// Under the colour.
  ///
  /// In en, this message translates to:
  /// **'Retired: no longer offered for new designs.'**
  String get pcRetired;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get pcMaterial;

  /// Field.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get pcColour;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get wbSave;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Show fewer tools'**
  String get wbFewerTools;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Show every tool'**
  String get wbEveryTool;

  /// Button: show fewer controls.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get wbLess;

  /// Button: show every control.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get wbMore;

  /// Tooltip and title.
  ///
  /// In en, this message translates to:
  /// **'Pen colour'**
  String get tbPenColour;

  /// Pen colour dialog in the dark appearance.
  ///
  /// In en, this message translates to:
  /// **'On the dark sheet a dark ink is shown light, so it can be seen. The drawing keeps the colour you choose.'**
  String get tbDarkInk;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Fit to the view'**
  String get vcFit;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get vcZoomIn;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get vcZoomOut;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset the view'**
  String get vcReset;

  /// [domain] Size check.
  ///
  /// In en, this message translates to:
  /// **'Too wide for the frame.'**
  String get msTooWide;

  /// [domain] Size check.
  ///
  /// In en, this message translates to:
  /// **'A bar has to have some thickness.'**
  String get msBarThickness;

  /// [domain] Size check.
  ///
  /// In en, this message translates to:
  /// **'Smaller than the frame around it.'**
  String get msSmallerThanFrame;

  /// [domain] Size check.
  ///
  /// In en, this message translates to:
  /// **'That does not fit the parts inside it.'**
  String get msNotFitInside;

  /// [domain] Size check.
  ///
  /// In en, this message translates to:
  /// **'That does not fit beside the parts next to it.'**
  String get msNotFitBeside;

  /// [domain] Size check.
  ///
  /// In en, this message translates to:
  /// **'Nothing to measure.'**
  String get msNothing;

  /// [domain] Size check.
  ///
  /// In en, this message translates to:
  /// **'That does not fit.'**
  String get msNotFit;

  /// [domain] Size check.
  ///
  /// In en, this message translates to:
  /// **'No frame.'**
  String get msNoFrame;

  /// [domain] Price list upgrade note.
  ///
  /// In en, this message translates to:
  /// **'The aluminium border and lines rate ({rate} a metre): aluminium is now priced as System Aluminium and Bend Shoulder Aluminium, each its own rate, and nothing says which of the two that rate was — so neither has a rate until one is set.'**
  String mnAluminium(String rate);

  /// [domain] Price list upgrade note.
  ///
  /// In en, this message translates to:
  /// **'The {material} bar rate ({bar} a metre): bars are now normal profile, priced at the frame rate ({frame}).'**
  String mnBarRate(String material, String bar, String frame);

  /// [domain] Price list upgrade note.
  ///
  /// In en, this message translates to:
  /// **'A price per leaf ({each}): a leaf is now priced by its opening profile and its ironmongery.'**
  String mnLeaf(String each);

  /// [domain] Price list upgrade note.
  ///
  /// In en, this message translates to:
  /// **'A price per angled joint ({joint}): an angled design is now priced by its own measurements.'**
  String mnJoint(String joint);

  /// [domain] Price list upgrade note.
  ///
  /// In en, this message translates to:
  /// **'Sealed glazing units are priced at the glass rates the list already had, which priced every pane before sealed units had a rate of their own.'**
  String get mnSealed;

  /// [domain] Price list upgrade note.
  ///
  /// In en, this message translates to:
  /// **'Colours are now one catalog: a colour sold in more than one material is one colour with a rate on each, at the figures it had.'**
  String get mnCatalog;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ckb', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ckb':
      return AppLocalizationsCkb();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
