# Central Kurdish (Sorani) translation review

**ProFrame Phase 34 — English and Central Kurdish localisation. Written 2026-10-11.**

Every message the application shows, 1219 in all: 140 of low confidence, 512 of medium and 567 of high, low first. **None of the Sorani here has been checked by a native speaker.** It was written for this phase, and nothing in it is marked verified.

## How to review

1. Read down the table. **Low** rows are trade and technical terms nobody has confirmed — the factory's own words matter most here (for example *Bend Shoulder Aluminium*, *sealed unit*, *sliding*, *lever*, *transom*, *mullion*, *pleated screen*). Then **Medium**, then **High**.
2. Where the proposed Sorani is right, leave the last column empty. Where it is wrong, write the wording you want in **Approved Sorani**, on the same row.
3. Keep every `{placeholder}` exactly as it is in the proposed wording — `{name}`, `{amount}`, `{count}` and the like are filled in by the application. In a plural row (`{count, plural, …}`), keep the `{count, plural, other{…}}` shape and change only the words inside the inner braces.
4. Write `\n` for a line break and `\|` for a vertical bar inside a cell. Do not change the **Key** column.
5. Do not translate figures, units (`cm`, `m`, `m²`, `mm`), currencies (`USD`), or ProFrame.

## How to apply

From the repository root, after editing this file:

```
dart run tool/apply_approved_translations.dart
dart run tool/generate_domain_words.dart
flutter gen-l10n
flutter test test/app/the_words_are_one_set_test.dart
```

The first writes each approved wording into `lib/app/l10n/app_ckb.arb` and nothing else. It refuses a key that does not exist or a wording that loses or adds a placeholder, and then writes nothing at all. The next two bring the code up to date, and the test checks that every message still has its Kurdish, with the same placeholders and a glyph for every letter. A row left empty keeps the proposed wording.

If a message is ever missing in Kurdish, the application shows the English one. It never shows a key.

## Terms used throughout

The proposed wording keeps one Sorani term for each concept everywhere. Changing one of these here means changing it in every row that uses it, so these are the ones to settle first.

| English | Proposed Sorani | Approved Sorani |
| --- | --- | --- |
| customer | کڕیار |  |
| design | دیزاین |  |
| opening | بەشی کراوە |  |
| fixed light | بەشی چەسپاو |  |
| frame | چوارچێوە |  |
| border | لێوار |  |
| internal lines | هێڵە ناوەکییەکان |  |
| divider / bar | دابەشکەر |  |
| glass | شووشە |  |
| panel | پانێڵ |  |
| sealed unit | شووشەی دووقات |  |
| profile | پرۆفایل |  |
| hardware / ironmongery | ئیکسسوار |  |
| hinge | لولاو |  |
| handle | دەسک |  |
| lever | لیڤەر |  |
| sliding | سلایدینگ |  |
| roller | تەگەرە |  |
| track | ڕێڕەو |  |
| angled / asymmetrical | لار / ناهاوسەنگ |  |
| drawing | نەخشە |  |
| geometry | شێوەکاری |  |
| price | نرخ |  |
| discount | داشکاندن |  |
| quotation | پێشنیاری نرخ |  |
| receipt | پسوولە |  |
| extra charge | تێچووی زیادە |  |
| amount due | بڕی ماوە |  |
| credit | پارەی زیادە |  |
| draft | ڕەشنووس |  |
| completed | تەواوکراو |  |
| System Aluminium | ئەلەمنیۆمی سیستەم |  |
| Bend Shoulder Aluminium | ئەلەمنیۆمی Bend Shoulder (left in English) |  |

The glossary is for agreeing terms. Only the table below is read by the apply tool.

## Every message

| Key | English | Context | Proposed Sorani | Confidence | Reason / status | Approved Sorani |
| --- | --- | --- | --- | --- | --- | --- |
| `beginFirstDesign` | Begin {name}'s first door, window or sliding set. | A customer with no designs. | یەکەم دەرگا، پەنجەرە یان سلایدینگی {name} دەست پێ بکە. | Low | Trade or technical term (sliding): no established Sorani term was verified — awaiting review |  |
| `catBendShoulderAluminium` | Bend Shoulder Aluminium | Aluminium profile category: Bend Shoulder Aluminium (product term, kept in English pending review). | ئەلەمنیۆمی Bend Shoulder | Low | Trade or technical term (bend shoulder): no established Sorani term was verified — awaiting review |  |
| `catSystemAluminium` | System Aluminium | Aluminium profile category: System Aluminium. | ئەلەمنیۆمی سیستەم | Low | Trade or technical term (system aluminium): no established Sorani term was verified — awaiting review |  |
| `classMesh` | Mesh | Material class: mesh. | تۆڕ | Low | Trade or technical term (mesh): no established Sorani term was verified — awaiting review |  |
| `classRubber` | Rubber gasket | Material class: rubber. | گاسکێتی لاستیک | Low | Trade or technical term (rubber, gasket): no established Sorani term was verified — awaiting review |  |
| `dimDaylight` | Daylight | Name of a row of figures: the main divisions' clear openings. | ڕووناکی | Low | Trade or technical term (daylight): no established Sorani term was verified — awaiting review |  |
| `finCredit` | Credit | Row: paid more than the total. | پارەی زیادە | Low | Trade or technical term (credit): no established Sorani term was verified — awaiting review |  |
| `finCreditOf` | Credit {amount} | Glance: the credit. | زیادە ‎{amount}‎ | Low | Trade or technical term (credit): no established Sorani term was verified — awaiting review |  |
| `finIssueAReceipt` | Issue a receipt | Tick: issue a receipt with the payment. | پسوولەیەک دەربکە | Low | Trade or technical term (receipt): no established Sorani term was verified — awaiting review |  |
| `finIssueReceipt` | Issue receipt | Button: issue a payment's receipt. | دەرکردنی پسوولە | Low | Trade or technical term (receipt): no established Sorani term was verified — awaiting review |  |
| `finNewQuotation` | New quotation | Button: make a quotation. | پێشنیاری نرخی نوێ | Low | Trade or technical term (quotation): no established Sorani term was verified — awaiting review |  |
| `fwAlert` | Alert | An alert dialog (screen reader). | ئاگادارکردنەوە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwApril` | April | Month name. | نیسان | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwAugust` | August | Month name. | ئاب | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwBack` | Back | Tooltip of the back arrow. | گەڕانەوە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwBottomSheet` | Bottom sheet | A sheet rising from the bottom (screen reader). | پەڕەی خوارەوە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwCancel` | Cancel | Cancel button. | هەڵوەشاندنەوە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwClearText` | Clear text | Clear a text field. | سڕینەوەی نووسین | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwClose` | Close | Close button or tooltip. | داخستن | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwCollapse` | Collapse | Fold a section (screen reader). | پێچانەوە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwContinue` | Continue | Continue button. | بەردەوامبوون | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwCopy` | Copy | Text selection menu. | لەبەرگرتنەوە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwCut` | Cut | Text selection menu. | بڕین | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwDateFormat` | dd/mm/yyyy | Date picker format hint. | ڕۆژ/مانگ/ساڵ | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwDateOutOfRange` | Out of range. | Date picker error. | لە سنوور دەرچووە. | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwDecember` | December | Month name. | کانوونی یەکەم | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwDelete` | Delete | Delete button or tooltip. | سڕینەوە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwDialog` | Dialog | A dialog (screen reader). | پەنجەرەی گفتوگۆ | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwDismiss` | Dismiss | Dismiss a dialog or menu (screen reader). | لابردن | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwEnterDate` | Enter date | Date picker text field. | بەروار بنووسە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwExpand` | Expand | Expand a folded section (screen reader). | فراوانکردن | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwFebruary` | February | Month name. | شوبات | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwFriday` | Friday | Weekday. | هەینی | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwInvalidDate` | Invalid format. | Date picker error. | شێوازی هەڵە. | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwJanuary` | January | Month name. | کانوونی دووەم | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwJuly` | July | Month name. | تەممووز | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwJune` | June | Month name. | حوزەیران | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwMarch` | March | Month name. | ئازار | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwMay` | May | Month name. | ئایار | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwMonday` | Monday | Weekday. | دووشەممە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwMore` | More | More options tooltip. | زیاتر | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwNarrowWeekdays` | S,M,T,W,T,F,S | The seven weekdays' initials, Sunday first, separated by commas, for a calendar's column heads. | ی,د,س,چ,پ,ه,ش | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwNextMonth` | Next month | Date picker tooltip. | مانگی داهاتوو | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwNovember` | November | Month name. | تشرینی دووەم | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwOctober` | October | Month name. | تشرینی یەکەم | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwOk` | OK | OK button. | باشە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwPaste` | Paste | Text selection menu. | لکاندن | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwPopupMenu` | Popup menu | A popup menu (screen reader). | لیستی دەرکەوتوو | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwPreviousMonth` | Previous month | Date picker tooltip. | مانگی پێشوو | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwRefresh` | Refresh | Refresh (screen reader). | نوێکردنەوە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwSaturday` | Saturday | Weekday. | شەممە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwSave` | Save | Save button. | پاشەکەوت | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwSearch` | Search | Search field label. | گەڕان | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwSelectAll` | Select all | Text selection menu. | هەمووی هەڵبژێرە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwSelectDate` | Select date | Date picker heading. | بەروار هەڵبژێرە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwSelected` | Selected | A selected date (screen reader). | هەڵبژێردراو | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwSelectYear` | Select year | Date picker (screen reader). | ساڵ هەڵبژێرە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwSeptember` | September | Month name. | ئەیلوول | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwShortMonths` | Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec | The twelve months as a date on a card writes them, January first, separated by commas. | کانوونی دووەم,شوبات,ئازار,نیسان,ئایار,حوزەیران,تەممووز,ئاب,ئەیلوول,تشرینی یەکەم,تشرینی دووەم,کانوونی یەکەم | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwShowMenu` | Show menu | Tooltip of a menu button. | پیشاندانی لیست | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwSunday` | Sunday | Weekday. | یەکشەممە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwThursday` | Thursday | Weekday. | پێنجشەممە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwToCalendar` | Switch to calendar | Date picker mode button. | گۆڕین بۆ ڕۆژژمێر | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwToday` | Today | Today, in a calendar. | ئەمڕۆ | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwToInput` | Switch to input | Date picker mode button. | گۆڕین بۆ نووسین | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwTuesday` | Tuesday | Weekday. | سێشەممە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `fwWednesday` | Wednesday | Weekday. | چوارشەممە | Low | Framework word (dates, buttons); month and weekday names follow one regional convention — awaiting review |  |
| `gfMullion` | a mullion | Geometry check: an upright dividing line. | دابەشکەرێکی ستوونی | Low | Trade or technical term (mullion): no established Sorani term was verified — awaiting review |  |
| `gfTransom` | a transom | Geometry check: a level dividing line. | دابەشکەرێکی ئاسۆیی | Low | Trade or technical term (transom): no established Sorani term was verified — awaiting review |  |
| `hasReceiptOne` | 1 receipt | What a customer has: one receipt. | 1 پسوولە | Low | Trade or technical term (receipt): no established Sorani term was verified — awaiting review |  |
| `hwCloser` | Closer | Ironmongery: a door closer. | داخەری دەرگا | Low | Trade or technical term (closer): no established Sorani term was verified — awaiting review |  |
| `hwKnob` | Knob | Ironmongery: a round knob. | دەسکی خڕ | Low | Trade or technical term (knob): no established Sorani term was verified — awaiting review |  |
| `hwLetterplate` | Letter plate | Ironmongery: a letter plate. | کونی نامە | Low | Trade or technical term (letter): no established Sorani term was verified — awaiting review |  |
| `hwLever` | Lever | Ironmongery: a lever handle on a backplate. | دەسکی لیڤەر | Low | Trade or technical term (lever): no established Sorani term was verified — awaiting review |  |
| `hwPeephole` | Peephole | Ironmongery: a door viewer. | چاوی دەرگا | Low | Trade or technical term (peephole): no established Sorani term was verified — awaiting review |  |
| `hwPull` | Pull handle | Ironmongery: the long bar a sliding panel is pulled by. | دەسکی ڕاکێشان | Low | Trade or technical term (pull): no established Sorani term was verified — awaiting review |  |
| `hwScreen` | Pleated screen | A pleated insect screen in a cassette. | تۆڕی قەدکراو | Low | Trade or technical term (pleated): no established Sorani term was verified — awaiting review |  |
| `inAutomaticHelp` | Opened by a drive when the sensor on the head sees somebody coming. | Help under the automatic switch. | بە بزوێنەرێک دەکرێتەوە کاتێک هەستەوەرەکەی سەرەوە کەسێک دەبینێت کە دێت. | Low | Trade or technical term (head): no established Sorani term was verified — awaiting review |  |
| `inHandleKnob` | Knob | Handle form: a knob. | دەسکی خڕ | Low | Trade or technical term (knob): no established Sorani term was verified — awaiting review |  |
| `inHandleLever` | Lever | Handle form: a lever. | لیڤەر | Low | Trade or technical term (lever): no established Sorani term was verified — awaiting review |  |
| `inHandlePull` | Pull | Handle form: a pull handle. | دەسکی ڕاکێشان | Low | Trade or technical term (pull): no established Sorani term was verified — awaiting review |  |
| `inPleated` | Pleated screen | Switch: a pleated insect screen on a sliding panel. | تۆڕی چینچین | Low | Trade or technical term (pleated): no established Sorani term was verified — awaiting review |  |
| `inPleatedHelp` | An insect screen that fans out of a cassette at the jamb across the passage as the panel opens. | Help under the pleated screen. | تۆڕێکی مێرووگر کە لە قوتوویەکی لای تەنیشتەوە دەکرێتەوە و ڕێڕەوەکە دادەپۆشێت کاتێک پانێڵەکە دەکرێتەوە. | Low | Trade or technical term (jamb): no established Sorani term was verified — awaiting review |  |
| `kindSliding` | Sliding | Design category: sliding panels. | سلایدینگ | Low | Trade or technical term (sliding): no established Sorani term was verified — awaiting review |  |
| `layHandles` | Handles | Layer: the grips to drag. | دەسکەکانی دەستکاری | Low | Trade or technical term (handles): no established Sorani term was verified — awaiting review |  |
| `layHatching` | Hatching | Layer. | هێڵکاری | Low | Trade or technical term (hatching): no established Sorani term was verified — awaiting review |  |
| `laySnap` | Snap | Layer: snap to geometry. | لکاندن | Low | Trade or technical term (snap): no established Sorani term was verified — awaiting review |  |
| `lineSealed` | Sealed unit — {glass} | A price line: a sealed double-glazed unit. | شووشەی دووقات — {glass} | Low | Trade or technical term (sealed): no established Sorani term was verified — awaiting review |  |
| `lineTrack` | Sliding track | A price line: the track sliding panels run on. | ڕێڕەوی سلایدینگ | Low | Trade or technical term (sliding, track): no established Sorani term was verified — awaiting review |  |
| `matLouvre` | Louvre | Material: louvre slats. | لۆڤەر | Low | Trade or technical term (louvre): no established Sorani term was verified — awaiting review |  |
| `matMesh` | Insect mesh | Material: insect mesh. | تۆڕی مێشوولە | Low | Trade or technical term (mesh): no established Sorani term was verified — awaiting review |  |
| `matRubber` | Rubber gasket | Material: rubber gasket. | گاسکێتی لاستیک | Low | Trade or technical term (rubber, gasket): no established Sorani term was verified — awaiting review |  |
| `matUpvc` | uPVC | Material: uPVC profile (kept as the trade name). | uPVC | Low | Trade or technical term (upvc): no established Sorani term was verified — awaiting review |  |
| `mdIso` | Iso | Named view. | ئایزۆ | Low | Trade or technical term (iso): no established Sorani term was verified — awaiting review |  |
| `mechBifold` | Bi-fold | How a section opens: folds in leaves. | قەدکراو | Low | Trade or technical term (bi-fold): no established Sorani term was verified — awaiting review |  |
| `mechBottomHung` | Bottom hung | How a section opens: hinged at the bottom. | هەڵواسراو لە خوارەوە | Low | Trade or technical term (bottom hung): no established Sorani term was verified — awaiting review |  |
| `mechHingedLeft` | Hinged left | How a section opens: hinged on the left. | لولاو لە چەپ | Low | Trade or technical term (hinged left): no established Sorani term was verified — awaiting review |  |
| `mechHingedRight` | Hinged right | How a section opens: hinged on the right. | لولاو لە ڕاست | Low | Trade or technical term (hinged right): no established Sorani term was verified — awaiting review |  |
| `mechPivot` | Pivot | How a section opens: turns about a central axis. | تەوەرەیی | Low | Trade or technical term (pivot): no established Sorani term was verified — awaiting review |  |
| `mechSlidingLeft` | Sliding left | How a section opens: slides to the left. | خزان بۆ چەپ | Low | Trade or technical term (sliding): no established Sorani term was verified — awaiting review |  |
| `mechSlidingLeftHint` | Slides to the left | Explains Sliding left. | بۆ چەپ دەخزێت | Low | Trade or technical term (slides): no established Sorani term was verified — awaiting review |  |
| `mechSlidingRight` | Sliding right | How a section opens: slides to the right. | خزان بۆ ڕاست | Low | Trade or technical term (sliding): no established Sorani term was verified — awaiting review |  |
| `mechSlidingRightHint` | Slides to the right | Explains Sliding right. | بۆ ڕاست دەخزێت | Low | Trade or technical term (slides): no established Sorani term was verified — awaiting review |  |
| `mechTiltAndTurn` | Tilt and turn | How a section opens: tilt and turn. | لاربوونەوە و سووڕان | Low | Trade or technical term (tilt and turn): no established Sorani term was verified — awaiting review |  |
| `mechTopHung` | Top hung | How a section opens: hinged at the top. | هەڵواسراو لە سەرەوە | Low | Trade or technical term (top hung): no established Sorani term was verified — awaiting review |  |
| `mnAluminium` | The aluminium border and lines rate ({rate} a metre): aluminium is now priced as System Aluminium and Bend Shoulder Aluminium, each its own rate, and nothing says which of the two that rate was — so neither has a rate until one is set. | Price list upgrade note. | نرخی لێوار و هێڵەکانی ئەلەمنیۆم (‎{rate}‎ بۆ هەر مەترێک): ئەلەمنیۆم ئێستا وەک ئەلەمنیۆمی سیستەم و ئەلەمنیۆمی Bend Shoulder نرخی بۆ دادەنرێت، هەریەکەیان نرخی خۆی، و هیچ شتێک نابڵێت ئەو نرخە کامیان بوو — بۆیە هیچیان نرخیان نییە تا یەکێک دادەنرێت. | Low | Trade or technical term (bend shoulder, system aluminium): no established Sorani term was verified — awaiting review |  |
| `mnSealed` | Sealed glazing units are priced at the glass rates the list already had, which priced every pane before sealed units had a rate of their own. | Price list upgrade note. | شووشەی دووقات بە نرخەکانی شووشەی پێشووی لیستەکە هەژمار دەکرێت، کە پێش ئەوەی شووشەی دووقات نرخی خۆی هەبێت نرخی هەموو پارچەیەکی دادەنا. | Low | Trade or technical term (sealed): no established Sorani term was verified — awaiting review |  |
| `nounSliding` | sliding | A sliding design, in the middle of a sentence. | سلایدینگ | Low | Trade or technical term (sliding): no established Sorani term was verified — awaiting review |  |
| `payCredit` | Credit | A customer's money: paid more than the total; the customer has credit. | پارەی زیادە | Low | Trade or technical term (credit): no established Sorani term was verified — awaiting review |  |
| `payOutstanding` | Outstanding | A customer's money: some is still due. | قەرزی ماوە | Low | Trade or technical term (outstanding): no established Sorani term was verified — awaiting review |  |
| `placeHead` | Head | The top member of a frame. | سەرەوە | Low | Trade or technical term (head): no established Sorani term was verified — awaiting review |  |
| `placeLeftJamb` | Left jamb | The left upright member of a frame. | لای چەپ | Low | Trade or technical term (jamb): no established Sorani term was verified — awaiting review |  |
| `placeRakingLowerLeft` | Raking lower left side | A sloping side of a frame, lower left. | لای لاری خوارەوەی چەپ | Low | Trade or technical term (raking): no established Sorani term was verified — awaiting review |  |
| `placeRakingLowerRight` | Raking lower right side | A sloping side of a frame, lower right. | لای لاری خوارەوەی ڕاست | Low | Trade or technical term (raking): no established Sorani term was verified — awaiting review |  |
| `placeRakingUpperLeft` | Raking upper left side | A sloping side of a frame, upper left. | لای لاری سەرەوەی چەپ | Low | Trade or technical term (raking): no established Sorani term was verified — awaiting review |  |
| `placeRakingUpperRight` | Raking upper right side | A sloping side of a frame, upper right. | لای لاری سەرەوەی ڕاست | Low | Trade or technical term (raking): no established Sorani term was verified — awaiting review |  |
| `placeRightJamb` | Right jamb | The right upright member of a frame. | لای ڕاست | Low | Trade or technical term (jamb): no established Sorani term was verified — awaiting review |  |
| `placeSill` | Sill | The bottom member of a frame. | بنەوە | Low | Trade or technical term (sill): no established Sorani term was verified — awaiting review |  |
| `projectionParallel` | Orthographic | 3D projection keeping parallel edges parallel. | ئۆرتۆگرافیک | Low | Trade or technical term (orthographic): no established Sorani term was verified — awaiting review |  |
| `projectionPerspective` | Perspective | 3D projection as the eye sees it. | پێرسپێکتیڤ | Low | Trade or technical term (perspective): no established Sorani term was verified — awaiting review |  |
| `quotationGone` | That quotation is not kept. | A quotation that is not kept. | ئەو پێشنیارەی نرخ هەڵنەگیراوە. | Low | Trade or technical term (quotation): no established Sorani term was verified — awaiting review |  |
| `quoteCannotBecome` | A quotation that is {status} cannot become {next}. | Quotation status check. | پێشنیاری نرخێک کە {status}ە ناتوانێت ببێتە {next}. | Low | Trade or technical term (quotation): no established Sorani term was verified — awaiting review |  |
| `quoteCreate` | Create quotation | Button. | دروستکردنی پێشنیاری نرخ | Low | Trade or technical term (quotation): no established Sorani term was verified — awaiting review |  |
| `quoteDesignChanged` | Design changed after quotation: {names}. | Warning on a quotation. | دیزاین دوای پێشنیاری نرخ گۆڕاوە: {names}. | Low | Trade or technical term (quotation): no established Sorani term was verified — awaiting review |  |
| `quoteDiscountExceeds` | The discount of {discount} is more than this quotation's subtotal, {subtotal}. | Quotation check. | داشکاندنی ‎{discount}‎ لە کۆی بەرایی ئەم پێشنیارەی نرخ زیاترە، ‎{subtotal}‎. | Low | Trade or technical term (quotation): no established Sorani term was verified — awaiting review |  |
| `quoteHeading` | QUOTATION | Heading of a quotation. | پێشنیاری نرخ | Low | Trade or technical term (quotation): no established Sorani term was verified — awaiting review |  |
| `quoteIncomplete` | Please complete all selected designs before creating the quotation. | Quotation check. | تکایە پێش دروستکردنی پێشنیاری نرخ هەموو دیزاینە هەڵبژێردراوەکان تەواو بکە. | Low | Trade or technical term (quotation): no established Sorani term was verified — awaiting review |  |
| `quoteKeepsPrices` | The quotation keeps every price as it is now. A complete design is priced first; an incomplete one cannot be quoted. | In the new quotation dialog. | پێشنیاری نرخ هەموو نرخێک وەک ئێستا دەپارێزێت. دیزاینێکی تەواو سەرەتا نرخی بۆ دادەنرێت؛ دیزاینێکی ناتەواو ناخرێتە ناو پێشنیاری نرخەوە. | Low | Trade or technical term (quotation): no established Sorani term was verified — awaiting review |  |
| `quoteNewFor` | New quotation for {name} | Title. | پێشنیاری نرخی نوێ بۆ {name} | Low | Trade or technical term (quotation): no established Sorani term was verified — awaiting review |  |
| `quoteStaysAsOffered` | This quotation stays as it was offered; make a new one for the current figures. | Warning on a quotation. | ئەم پێشنیارەی نرخ وەک خۆی دەمێنێتەوە کە پێشکەش کرا؛ بۆ ژمارەکانی ئێستا یەکێکی نوێ دروست بکە. | Low | Trade or technical term (quotation): no established Sorani term was verified — awaiting review |  |
| `rcpCredit` | {amount} credit | On a receipt. | ‎{amount}‎ زیادە | Low | Trade or technical term (credit): no established Sorani term was verified — awaiting review |  |
| `rcpHeading` | RECEIPT | Heading of a receipt. | پسوولە | Low | Trade or technical term (receipt): no established Sorani term was verified — awaiting review |  |
| `rfRoller` | Roller | Price list field. | تەگەرە | Low | Trade or technical term (roller): no established Sorani term was verified — awaiting review |  |
| `rfRollersPerPanel` | Rollers on each sliding panel | Price list field. | تەگەرەکانی هەر پانێڵێکی سلایدینگ | Low | Trade or technical term (sliding): no established Sorani term was verified — awaiting review |  |
| `rfSealed` | Sealed glass unit | Price list section. | شووشەی دووقات | Low | Trade or technical term (sealed): no established Sorani term was verified — awaiting review |  |
| `rfSliding` | Sliding | Price list section. | سلایدینگ | Low | Trade or technical term (sliding): no established Sorani term was verified — awaiting review |  |
| `rfTrack` | Track | Price list field: a sliding track. | ڕێڕەو | Low | Trade or technical term (track): no established Sorani term was verified — awaiting review |  |
| `straighteningNote` | Door, Window, Sliding and Door & window straighten lines drawn a little out of square. Angled / Asymmetrical keeps every slope exactly as you draw it. | Under the category cards: what separates the standard categories from the angled one. | دەرگا، پەنجەرە، سلایدینگ و دەرگا و پەنجەرە ئەو هێڵانە ڕاست دەکەنەوە کە کەمێک لار کێشراون. لار / ناهاوسەنگ هەموو لارییەک وەک خۆی دەهێڵێتەوە کە دەیکێشیت. | Low | Trade or technical term (sliding): no established Sorani term was verified — awaiting review |  |
| `vmShaded` | Shaded | View mode. | سێبەردار | Low | Trade or technical term (shaded): no established Sorani term was verified — awaiting review |  |
| `vmWireframe` | Wireframe | View mode. | تۆڕی هێڵ | Low | Trade or technical term (wireframe): no established Sorani term was verified — awaiting review |  |
| `acIntro` | The owner may do everything. Each member of staff may do what is ticked here, and nothing else. With nobody signed in, the device may only look once any member of staff is active. | Staff screen. | خاوەن دەتوانێت هەموو شتێک بکات. هەر کارمەندێک دەتوانێت ئەوەی لێرە دیاری کراوە بیکات، و هیچی تر. کاتێک کەس نەچووەتە ژوورەوە، ئامێرەکە تەنها دەتوانێت سەیر بکات ئەگەر کارمەندێکی چالاک هەبێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `acNoStaffYet` | No member of staff has been added yet. The owner adds them under Staff & permissions. | Sign-in dialog. | هێشتا هیچ کارمەندێک زیاد نەکراوە. خاوەن لە بەشی کارمەندان و مۆڵەتەکان زیادیان دەکات. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `acStartLooking` | They start able to look and nothing more. Tick what else they may do on their card. | Add staff dialog. | لە سەرەتادا تەنها دەتوانن سەیر بکەن. ئەوەی تر دەتوانن بیکەن لەسەر کارتەکەیان دیاری بکە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `amtAsNumber` | Enter the amount as a number, such as 500.00. | Amount check. | بڕەکە وەک ژمارە بنووسە، بۆ نموونە 500.00. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `amtEnter` | Enter an amount. | Amount check. | بڕێک بنووسە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `amtMoreThanNothing` | The amount must be more than nothing. | Amount check. | بڕەکە دەبێت لە سفر زیاتر بێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `amtSmaller` | Enter a smaller amount. | Amount check. | بڕێکی بچووکتر بنووسە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `amtToTheCent` | Enter the amount to the cent — two decimal places at most. | Amount check. | بڕەکە تا سەنت بنووسە — زۆرترین دوو ژمارە دوای خاڵ. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `axisHeight` | Height | A height. | بەرزی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `axisWidth` | Width | A width. | پانی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `cadGlass` | GLASS | Written on a pane of glass on the technical drawing. | شووشە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `cadIn` | IN | Written by a leaf that opens inward. | ناوەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `cadLookGlass` | {look} GLASS | Written on a pane of tinted or frosted glass. | شووشەی {look} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `cadOut` | OUT | Written by a leaf that opens outward. | دەرەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `cannotDeleteCustomer` | {name} cannot be deleted: they have {has}. A customer is deleted only when nothing of theirs would go with them — delete each design on its own; payments, receipts, discounts and quotations are the workshop's records and are kept. | Why a customer cannot be deleted. | {name} ناسڕدرێتەوە: ئەمانەی هەیە: {has}. کڕیار تەنها کاتێک دەسڕدرێتەوە کە هیچ شتێکی لەگەڵیدا نەڕوات — هەر دیزاینێک بە جیا بسڕەوە؛ پارەدان و پسوولە و داشکاندن و پێشنیاری نرخ تۆماری کارگەن و هەڵدەگیرێن. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `capAdd` | Add | Permission: add. | زیادکردن | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capAddEditStaff` | Add and edit staff | Permission. | زیادکردن و دەستکاریی کارمەندان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capApplyAndChange` | Apply and change | Permission: give and change discounts. | دانان و گۆڕین | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capChangePermissions` | Change permissions | Permission. | گۆڕینی مۆڵەتەکان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capChangeStatus` | Change status | Permission: change a quotation's status. | گۆڕینی دۆخ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capCreate` | Create | Permission: create. | دروستکردن | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capDelete` | Delete | Permission: delete. | سڕینەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capEdit` | Edit | Permission: edit. | دەستکاریکردن | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capEditAndDraw` | Edit and draw | Permission: edit and draw designs. | دەستکاری و نەخشەکێشان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capEditFactoryPrices` | Edit factory prices | Permission. | دەستکاریی نرخەکانی کارگە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capGroupCustomers` | Customers | Permission group. | کڕیاران | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capGroupDesigns` | Designs | Permission group. | دیزاینەکان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capGroupDiscounts` | Discounts | Permission group. | داشکاندنەکان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capGroupExtras` | Extra charges | Permission group. | تێچووە زیادەکان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capGroupFinances` | Customer finances | Permission group. | دارایی کڕیاران | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capGroupPayments` | Payments | Permission group. | پارەدانەکان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capGroupPricing` | Pricing | Permission group. | نرخدانان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capGroupQuotations` | Quotations | Permission group. | پێشنیارەکانی نرخ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capGroupReceipts` | Receipts | Permission group. | پسوولەکان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capGroupStaff` | Staff | Permission group. | کارمەندان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capIssue` | Issue | Permission: issue receipts. | دەرکردن | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capRecordPayments` | Record payments | Permission. | تۆمارکردنی پارەدان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capRecordRefunds` | Record refunds | Permission. | تۆمارکردنی گەڕاندنەوەی پارە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capRemove` | Remove | Permission: remove extra charges. | لابردن | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capView` | View | Permission: view. | بینین | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capViewHistory` | View history | Permission: see the payment history. | بینینی مێژوو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capViewPrices` | View prices | Permission. | بینینی نرخەکان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `capViewSummary` | View summary | Permission: see a customer's financial summary. | بینینی کورتە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `ccChooseMaterial` | Choose at least one material. | Colour check. | لانیکەم یەک کەرەستە هەڵبژێرە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `ccEnterFigure` | Enter a figure. | Rate check. | ژمارەیەک بنووسە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `ccNameRequired` | Colour name is required. | Colour check. | ناوی ڕەنگ پێویستە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `ccNameTaken` | An active colour is already called {name} for {material}. | Colour check. | ڕەنگێکی چالاک پێشتر بە ناوی {name} بۆ {material} هەیە. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `ccNoProfile` | The price list has no {material} profile to sell a colour in. | Colour check. | لیستی نرخ هیچ پرۆفایلێکی {material}ی تێدا نییە بۆ فرۆشتنی ڕەنگێک تێیدا. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `ccNotInList` | This colour is not in the price list. | Colour check. | ئەم ڕەنگە لە لیستی نرخدا نییە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `ccRateNotBelow` | A rate cannot be below nothing. | Rate check. | نرخ ناتوانێت لە سفر کەمتر بێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `ccRateRequired` | {material} colour rate is required for a colour that applies to {material}. | Colour check. | نرخی ڕەنگی {material} پێویستە بۆ ڕەنگێک کە بۆ {material} بەکاردێت. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `checkNothingDecided` | Nothing has been decided for you. Your drawing is unchanged until you answer. | Under the questions the reading raised. | هیچ شتێک لە جیاتی تۆ بڕیار نەدراوە. نەخشەکەت وەک خۆی دەمێنێتەوە تا وەڵام دەدەیتەوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `classAluminium` | Aluminium | Material class: aluminium. | ئەلەمنیۆم | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `classGlass` | Glass | Material class: glass. | شووشە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `classHandleMetal` | Handle metal | Material class: polished metal of a handle. | کانزای دەسک | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `classHingeMetal` | Hinge metal | Material class: satin metal of a hinge. | کانزای لولاو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `classMetal` | Metal | Material class: metal. | کانزا | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `classPanel` | Panel | Material class: panel. | پانێڵ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `classPvc` | PVC | Material class: PVC. | PVC | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `classWood` | Wood | Material class: wood. | دار | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourBlack` | Black | Colour name. | ڕەش | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourBronze` | Bronze | Colour name. | برۆنزی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourBrown` | Brown | Colour name. | قاوەیی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourClearGlass` | Clear glass | Colour name: the colour of clear glass. | شووشەی ڕوون | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourCream` | Cream | Colour name. | کرێمی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourDeepGreen` | Deep green | Colour name. | سەوزی تۆخ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourFrosted` | Frosted | Colour name: frosted glass. | تەماوی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourGraphite` | Graphite | Colour name: a very dark grey. | گرافیتی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourGrey` | Grey | Colour name. | خۆڵەمێشی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourNoProfile` | The price list has no price for {material} profile. | The price list has no price for this material. | لیستی نرخەکان نرخی پرۆفایلی {material}ی تێدا نییە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourNotConfigured` | Colour pricing is not configured for {material}. | The price list has no rate for this colour on this material. | نرخی ڕەنگ بۆ {material} دیاری نەکراوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourNotForMaterial` | Please select a colour available for {material}. | The chosen colour is not sold in this material. | تکایە ڕەنگێک هەڵبژێرە کە بۆ {material} بەردەستە. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `colourOak` | Oak | Colour name: the colour of oak wood. | دار بەڕوو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourOffWhite` | Off white | Colour name: a white with a little grey. | نیمچە سپی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourOxblood` | Oxblood | Colour name: a deep dark red. | سووری تۆخ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourSilver` | Silver | Colour name. | زیوی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourSteelBlue` | Steel blue | Colour name. | شینی پۆڵایی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourUnavailable` | Colour pricing unavailable — please select an active colour. | The chosen colour is retired or unknown. | نرخی ڕەنگ بەردەست نییە — تکایە ڕەنگێکی چالاک هەڵبژێرە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourWalnut` | Walnut | Colour name: the colour of walnut wood. | دار گوێز | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourWarmCream` | Warm cream | Colour name. | کرێمی گەرم | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `colourWhite` | White | Colour name. | سپی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `completeIncomplete` | This design is not complete yet. Please finish the required parts before completing it. | Completing a design that is not finished. | ئەم دیزاینە هێشتا تەواو نییە. تکایە پێش تەواوکردنی، بەشە پێویستەکان تەواو بکە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `completeSaveFailed` | The design could not be saved, so it was not completed. Your work is still here — try again. ({error}) | Completing when the save failed; the error is technical text. | دیزاینەکە پاشەکەوت نەکرا، بۆیە تەواو نەکرا. کارەکەت هێشتا لێرەیە — دووبارە هەوڵ بدەرەوە. ({error}) | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `completeUnsupported` | This design was made by a newer ProFrame or with a category this version does not recognise, so it cannot be completed here. | Completing a design of an unknown category. | ئەم دیزاینە بە وەشانێکی نوێتری ProFrame یان بە جۆرێک دروستکراوە کە ئەم وەشانە نایناسێتەوە، بۆیە لێرە تەواو ناکرێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `constructionBoth` | Panel + glass | Built of panel and glass. | پانێڵ + شووشە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `constructionGlass` | Glass | Built of glass. | شووشە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `constructionPanel` | Panel | Built of panel. | پانێڵ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `constructionPending` | Not said | What a door is built of: not said yet. | نەوتراوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `copyOf` | {name} (copy) | The name of a duplicated design. | {name} (لەبەرگیراوە) | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `custom` | Custom | A colour or glass of the user's own, not one of the named ones. | تایبەت | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `customersCount` | {count, plural, =1{1 customer} other{{count} customers}} | How many customers are kept. | {count, plural, other{{count} کڕیار}} | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `customersNoMatch` | No customer matches "{query}". | A search that found nobody. | هیچ کڕیارێک لەگەڵ «{query}» ناگونجێت. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `customerSubtitle` | {count, plural, =0{Customer · no designs yet} =1{Customer · 1 design} other{Customer · {count} designs}} | Under a customer's name on their page. | {count, plural, =0{کڕیار · هێشتا هیچ دیزاینێک نییە} other{کڕیار · {count} دیزاین}} | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `deleteCustomerBody` | Only a customer with nothing of theirs kept can be deleted: no designs, payments, receipts, discounts, quotations or extra charges. Their record is then removed, and nothing else. | Explains deleting a customer. | تەنها ئەو کڕیارەی هیچ شتێکی هەڵنەگیراوە دەسڕدرێتەوە: نە دیزاین، نە پارەدان، نە پسوولە، نە داشکاندن، نە پێشنیاری نرخ و نە تێچووی زیادە. ئینجا تەنها تۆمارەکەی دەسڕدرێتەوە و هیچی تر. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `deleteDesignAlone` | This design will be removed from this device. No other design is touched. | Deleting a design with no customer named. | ئەم دیزاینە لەم ئامێرە لادەبرێت. دەست لە هیچ دیزاینێکی تر نادرێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `deleteDesignOf` | This design will be removed from this device. {who}, their phone, address and notes, and their other designs stay exactly as they are. | Deleting a customer's design. | ئەم دیزاینە لەم ئامێرە لادەبرێت. {who}، ژمارەی مۆبایل و ناونیشان و تێبینییەکانی، و دیزاینەکانی تری وەک خۆیان دەمێننەوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `deniedAction` | {who} does not have permission to {action} ({key}). | Refusal: a permission somebody does not hold. The key is the permission's code. | {who} مۆڵەتی «{action}»ی نییە ({key}). | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `deniedPriceList` | Only the owner can change the price list (asked by {who}). | Refusal: somebody else tried to change the price list. | تەنها خاوەن دەتوانێت لیستی نرخەکان بگۆڕێت (داواکار: {who}). | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `designsCount` | {count, plural, =0{No designs yet} =1{1 design} other{{count} designs}} | How many designs a customer has. | {count, plural, =0{هێشتا هیچ دیزاینێک نییە} other{{count} دیزاین}} | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `dimDivision` | Division | Name of a row of figures: the divisions inside a part. | دابەشبوون | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `dimKindHeight` | {what} height | A figure being typed over: the height of a kind of part. | بەرزی {what} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `dimKindWidth` | {what} width | A figure being typed over: the width of a kind of part. | پانی {what} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `dimOpening` | Opening | Name of a row of figures: each opening's size. | بەشی کراوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `dimOverall` | Overall | Name of a row of figures on the technical drawing: the overall size. | گشتی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `dimOverallHeight` | Overall height | A figure being typed over. | بەرزی گشتی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `dimOverallWidth` | Overall width | A figure being typed over. | پانی گشتی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `dimRealSize` | Real size | A drawn dimension being typed over. | قەبارەی ڕاستەقینە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `dimSectionHeight` | Section height | A figure being typed over. | بەرزی بەش | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `dimSectionWidth` | Section width | A figure being typed over. | پانی بەش | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `dimSide` | Side | Name of a row of figures: a side of an angled frame. | لا | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `discountDesignNotFinal` | The total is not final yet. A fixed discount can be given once it is priced. | A design's own discount check. | کۆی گشتی هێشتا کۆتایی نییە. داشکاندنی بڕی جێگیر دەدرێت کاتێک نرخی بۆ دانرا. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `discountEnter` | Enter the discount. | Discount check. | داشکاندنەکە بنووسە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `discountFixed` | Fixed amount | A discount as a fixed amount of money. | بڕی دیاریکراو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `discountMoreThanNothing` | A discount must be more than nothing. | Discount check. | داشکاندن دەبێت لە سفر زیاتر بێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `discountNone` | No discount | No discount in force. | بێ داشکاندن | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `discountNotFinal` | The total is not final yet. A fixed discount can be given once every design is priced. | Discount check. | کۆی گشتی هێشتا کۆتایی نییە. داشکاندنی بڕی جێگیر دەدرێت کاتێک هەموو دیزاینەکان نرخیان بۆ دانرا. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `discountOver100` | A percentage cannot be more than 100%. | Discount check. | ڕێژەی سەدی ناتوانێت لە 100% زیاتر بێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `discountOverSubtotal` | The discount cannot be more than the subtotal, {amount}. | Discount check. | داشکاندن ناتوانێت لە کۆی بەرایی زیاتر بێت، ‎{amount}‎. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `discountPercent` | Percentage | A discount as a percentage. | ڕێژەی سەدی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `discountPercentNumber` | Enter the percentage as a number, such as 10 or 12.5. | Discount check. | ڕێژەی سەدی وەک ژمارە بنووسە، بۆ نموونە 10 یان 12.5. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `editCustomerLine` | Change how to reach them or what to remember. Their designs stay exactly as they are. | Under the title of the form editing a customer. | ڕێگای پەیوەندیکردن یان ئەوەی دەبێت لەبیرت بێت بگۆڕە. دیزاینەکانیان وەک خۆیان دەمێننەوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `editInformationLine` | Change what this design is called. The drawing, its sizes and everything in it stay exactly as they are. | Under the title of Edit information. | ناوی ئەم دیزاینە بگۆڕە. نەخشەکە و پێوانەکانی و هەموو شتێکی ناوی وەک خۆیان دەمێننەوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `elAngledDivider` | Angled divider | A sloped line dividing the design. | دابەشکەری لار | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `elArrow` | Arrow | An arrow drawn on the drawing. | تیر | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `elFrame` | Frame | The frame of the design. | چوارچێوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `elHorizontalDivider` | Horizontal divider | A level line dividing the design. | دابەشکەری ئاسۆیی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `elNote` | Note | A note written on the drawing. | تێبینی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `elSection` | Section | A section of the design. | بەش | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `elVerticalDivider` | Vertical divider | An upright line dividing the design. | دابەشکەری ستوونی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `engineExtraCurrency` | The extra charge "{name}" is in {currency}, and this design is priced in {listCurrency}. Write it in {listCurrency}. | An extra charge in another currency than the price list's. | تێچووی زیادەی «{name}» بە {currency}ـە، و ئەم دیزاینە بە {listCurrency} نرخی بۆ دادەنرێت. بە {listCurrency} بینووسە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `engineMissing` | The price list has no price for {what}. | Something the price list has no rate for. | لیستی نرخەکان نرخی {what}ی تێدا نییە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `engineNoCategory` | The price list has no prices for {kind} designs. | Why a design cannot be priced. | لیستی نرخەکان نرخی دیزاینەکانی {kind}ی تێدا نییە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `engineUnsupported` | This version of ProFrame cannot price a design of this category. | Why a design cannot be priced. | ئەم وەشانەی ProFrame ناتوانێت نرخ بۆ دیزاینی ئەم جۆرە دابنێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `everyPartStartsAs` | Every part you draw starts as this. Any part can be changed later with Material. | Under the second step. | هەموو بەشێک کە دەیکێشیت بەمە دەست پێدەکات. هەر بەشێک دواتر بە ئامرازی کەرەستە دەگۆڕدرێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `fcIntro` | What each colour adds on each material it is sold in, by the metre of profile and as a share of the profile's price. A retired colour is not offered for new designs; designs already in it keep it. | Under the colours heading. | ئەوەی هەر ڕەنگێک لەسەر هەر کەرەستەیەک کە پێی دەفرۆشرێت زیادی دەکات، بە مەتری پرۆفایل و وەک بەشێک لە نرخی پرۆفایلەکە. ڕەنگی خانەنشینکراو بۆ دیزاینی نوێ پێشکەش ناکرێت؛ ئەو دیزاینانەی پێشتر پێیەتی دەیپارێزن. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `fcRenaming` | Renaming keeps it the same colour: every design in it shows the new name. | Under the name. | گۆڕینی ناو هەمان ڕەنگ دەهێڵێتەوە: هەموو دیزاینێک کە پێیەتی ناوە نوێیەکە پیشان دەدات. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `fcRetireBody` | It will no longer be offered for new designs. Every design already in it keeps it, is still shown in it and is still priced at its rate. Nothing is deleted, and it can be brought back. | Confirmation. | ئیتر بۆ دیزاینی نوێ پێشکەش ناکرێت. هەموو دیزاینێک کە پێشتر بەم ڕەنگەیە هەر بەو ڕەنگە دەمێنێتەوە، هەر بەو ڕەنگە پیشان دەدرێت و هەر بە نرخی خۆی هەژمار دەکرێت. هیچ شتێک ناسڕدرێتەوە، و دەتوانرێت بگەڕێنرێتەوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `finCreditNote` | The customer has paid {amount} more than their designs now come to. It is theirs: it can be refunded, or stand against a later design. | Under the credit. | کڕیارەکە ‎{amount}‎ زیاتر لەوەی دیزاینەکانی ئێستا دەکەن پارەی داوە. ئەمە هی خۆیەتی: دەتوانرێت بگەڕێنرێتەوە، یان بۆ دیزاینێکی دواتر بمێنێتەوە. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `finDiscountExceeds` | The discount of {amount} is more than the subtotal now, so it takes the whole subtotal and no more. | Warning under the total. | داشکاندنی ‎{amount}‎ ئێستا لە کۆی بەرایی زیاترە، بۆیە هەموو کۆی بەرایی دەبات و هیچی تر. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `finNoExtras` | No extra charges for the whole job. A design's own extras are on its price. | The customer has no extras. | هیچ تێچوویەکی زیادە بۆ هەموو کارەکە نییە. تێچووە زیادەکانی هەر دیزاینێک لەسەر نرخی خۆیەتی. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `finNoRate` | No exchange rate was recorded with these, so they are kept in their own currency and not added to the {currency} figures above. | Under money in other currencies. | هیچ نرخێکی گۆڕینەوە لەگەڵ ئەمانە تۆمار نەکراوە، بۆیە بە دراوی خۆیان هەڵدەگیرێن و ناخرێنە سەر ژمارەکانی {currency}ی سەرەوە. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `finQuoteLine` | {day} · {count, plural, =1{1 design} other{{count} designs}} | A quotation's day and how many designs. | {day} · {count, plural, other{{count} دیزاین}} | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `finRateHelp` | With a rate it counts towards the {base} total, at this rate for good. Without one it is kept in {currency} and not added to the {base} total. | Help under the exchange rate. | بە نرخێکەوە دەخرێتە سەر کۆی {base}، بەم نرخە بۆ هەمیشە. بەبێ نرخ بە {currency} هەڵدەگیرێت و ناخرێتە سەر کۆی {base}. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `finRefundNote` | Net paid: {amount}. A refund is money returned; it cannot be more than that. | In the refund dialog. | پارەی دراوی پوخت: ‎{amount}‎. گەڕاندنەوەی پارە پارەیەکە کە دەدرێتەوە؛ ناتوانێت لەوە زیاتر بێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `fpColoursKept` | {done} Prices kept as version {version}; every design priced before is now to be recalculated. | Notice. | {done} نرخەکان وەک وەشانی {version} هەڵگیران؛ هەموو دیزاینێک کە پێشتر نرخی بۆ دانرابوو ئێستا دەبێت دووبارە هەژمار بکرێتەوە. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `fpInCurrency` | In {currency}. A figure left empty is not priced: a design using it says so rather than being priced at nothing. | Note. | بە {currency}. ژمارەیەک کە بەتاڵ جێبهێڵرێت نرخی بۆ دانانرێت: دیزاینێک کە بەکاری دەهێنێت ئەوە دەڵێت نەک بە سفر نرخی بۆ دابنرێت. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `fpNeedCorrecting` | {count, plural, =1{1 figure needs correcting before the prices can be kept.} other{{count} figures need correcting before the prices can be kept.}} | Notice. | {count, plural, other{{count} ژمارە پێویستی بە ڕاستکردنەوە هەیە پێش ئەوەی نرخەکان هەڵبگیرێن.}} | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `fpRatesNote` | These are the rates every design is priced by. Staff can read them and price designs by them. | Card. | ئەمانە ئەو نرخانەن کە هەموو دیزاینێک پێیان هەژمار دەکرێت. کارمەندان دەتوانن بیانخوێننەوە و دیزاینەکان پێیان نرخ بکەن. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gapBottom` | the bottom | The side of an outline left open: the bottom. | خوارەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gapLeft` | the left side | The side of an outline left open: the left. | لای چەپ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gapOne` | one side | The side of an outline left open: unnamed. | لایەک | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gapRight` | the right side | The side of an outline left open: the right. | لای ڕاست | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gapTop` | the top | The side of an outline left open: the top. | سەرەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gcErrors` | {count, plural, =1{1 error} other{{count} errors}} | How many errors the geometry check found. | {count, plural, other{{count} هەڵە}} | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `gcWarnings` | {count, plural, =1{1 warning} other{{count} warnings}} | How many warnings the geometry check found. | {count, plural, other{{count} ئاگاداری}} | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `gfArrow` | an arrow | Geometry check: an arrow. | تیرێک | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfBar` | a bar | Geometry check: a line dividing the design. | دابەشکەرێک | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfCrossesItself` | {name} crosses itself. | Geometry check message. | {name} خۆی دەبڕێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfDimension` | a dimension | Geometry check: a dimension. | پێوانەیەک | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfDimensionDisagrees` | The dimension you gave as {stated} no longer matches the drawing, which measures {measured}. | Geometry check message. | ئەو پێوانەیەی وەک ‎{stated}‎ نووسیت ئیتر لەگەڵ نەخشەکە ناگونجێت، کە ‎{measured}‎ دەپێوێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfDimensionGiven` | the dimension you gave as {size} | Geometry check: a dimension the user stated. | ئەو پێوانەیەی وەک ‎{size}‎ نووسیت | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfDimensionMismatch` | A dimension does not match the drawing. | Geometry check message. | پێوانەیەک لەگەڵ نەخشەکە ناگونجێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfDimensionNothing` | A dimension measures nothing: its two ends are at the same point. | Geometry check message. | پێوانەیەک هیچ ناپێوێت: هەردوو سەری لە یەک خاڵدان. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfDimensionNotSize` | A dimension gives {size}, which is not a size. | Geometry check message. | پێوانەیەک ‎{size}‎ دەدات، کە قەبارە نییە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfEnclosesNothing` | {name} encloses no area. | Geometry check message. | {name} هیچ ڕووبەرێک داناخات. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `gfFixedLight` | a fixed light | Geometry check: a part that does not open. | بەشێکی چەسپاو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfFrame` | the frame | Geometry check: the frame. | چوارچێوەکە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfFrameEnclosesNothing` | The frame's outline does not enclose a shape. | Geometry check message. | دەوروبەری چوارچێوەکە شێوەیەک داناخات. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfFrameTouchesItself` | The frame's outline touches itself. | Geometry check message. | دەوروبەری چوارچێوەکە بەر خۆی دەکەوێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfLiesOutside` | {name} lies outside {within}. | Geometry check message. | {name} لە دەرەوەی {within}ـە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfLightItBelongsTo` | the light it belongs to | Geometry check: the light a child belongs to. | ئەو بەشەی کە سەر بەیەتی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfLineInside` | a line inside {parent} | Geometry check: a line inside an opening or a light. | هێڵێک لەناو {parent} | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `gfLostRegion` | {name} has lost the region it opens. | Geometry check message. | {name} ئەو ناوچەیەی کە دەیکاتەوە ونی کردووە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfMarkOutside` | The mark of {name} is outside the region it opens. | Geometry check message. | نیشانەی {name} لە دەرەوەی ئەو ناوچەیەیە کە دەیکاتەوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfMemberOfFrame` | the {member} of the frame | Geometry check: one side of the frame. | {member}ی چوارچێوەکە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfNotANumber` | {name} has a point that is not a number, so it cannot be placed. | Geometry check message. | {name} خاڵێکی تێدایە کە ژمارە نییە، بۆیە دانانی ناکرێت. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `gfNotConnected` | {name} is not connected to the frame or to another bar. | Geometry check message. | {name} بە چوارچێوەکە یان بە دابەشکەرێکی ترەوە نەبەستراوە. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `gfNote` | a note | Geometry check: a note. | تێبینییەک | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfNotOnLeaf` | {name} is not on its leaf. | Geometry check message: a hinge or handle off the leaf it belongs to. | {name} لەسەر دەرگا/پەنجەرە کراوەکەی خۆی نییە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfOutsideFrame` | {name} lies outside the frame. | Geometry check message. | {name} لە دەرەوەی چوارچێوەکەیە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfPaneOf` | a pane of {parent} | Geometry check: a pane inside an opening. | بەشێکی ناوەوەی {parent} | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `gfPartItBelongsTo` | the part it belongs to | Geometry check: the part a child belongs to. | ئەو بەشەی کە سەر بەیەتی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfPartOfDesign` | part of the design | Geometry check: a part with no name. | بەشێک لە دیزاینەکە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfPiece` | a {piece} | Geometry check: a piece of ironmongery. | {piece}ێک | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `gfPieceOf` | a {piece} of {opening} | Geometry check: a piece of ironmongery of an opening. | {piece}ێکی {opening} | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `gfReachesOutside` | {name} reaches outside {within}. | Geometry check message. | {name} دەگاتە دەرەوەی {within}. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfRegionOf` | the region of {opening} | Geometry check: the region an opening fills. | ناوچەی {opening} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfSideCrosses` | The {first} of the frame crosses the {second}. | Geometry check message: two named sides cross. | {first}ی چوارچێوەکە {second} دەبڕێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfSidesCross` | Two sides of the frame cross each other. | Geometry check message. | دوو لای چوارچێوەکە یەکتر دەبڕن. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfSlopedBar` | a sloped bar | Geometry check: a sloping dividing line. | دابەشکەرێکی لار | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfSummaryError` | Part of this design cannot be built as it is drawn. Nothing has been changed for you — put it right on your drawing. | Under the geometry check heading where there is an error. | بەشێک لەم دیزاینە بەو شێوەیەی کێشراوە دروست ناکرێت. هیچ شتێک بۆت نەگۆڕدراوە — لەسەر نەخشەکەت ڕاستی بکەرەوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfSummaryWarning` | This design can be built, but something in it may not be what you meant. Nothing has been changed for you. | Under the geometry check heading where there are only warnings. | ئەم دیزاینە دروست دەکرێت، بەڵام لەوانەیە شتێکی تێدا بێت کە مەبەستت نەبووبێت. هیچ شتێک بۆت نەگۆڕدراوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfTitleAttention` | Geometry needs attention | Heading of the geometry check where there is an error. | شێوەکاری پێویستی بە سەرنجە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gfTitleReview` | Geometry may need review | Heading of the geometry check where there are only warnings. | لەوانەیە شێوەکاری پێویستی بە پێداچوونەوە هەبێت | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `glassBlueGrey` | Blue-grey | Glass look: blue-grey tinted. | شینی خۆڵەمێشی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `glassClear` | Clear | Glass look: clear. | ڕوون | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `glassDark` | Dark | Glass look: dark tinted. | تاریک | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `glassFrosted` | Frosted | Glass look: frosted. | تەماوی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `glassNothingToCharge` | No measurable glass to price | Glass row: included, but no glass to charge. | هیچ شووشەیەکی پێوانەکراو نییە بۆ نرخدانان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `glassNotIncluded` | Not included | Glass row: the design has glass, not included in the price. | تێدا نییە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `glassNotUsed` | Not used | A material the design does not use. | بەکارنەهاتووە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `glassTinted` | Tinted | Glass look: tinted. | ڕەنگکراو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gradeNonStandard` | Non-standard colour | A colour the factory sells at a surcharge. | ڕەنگی ناستاندارد | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gradeSpecial` | Special colour | A colour the price list does not name. | ڕەنگی تایبەت | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `gradeStandard` | Standard colour | A colour the factory stocks as standard. | ڕەنگی ستاندارد | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `groupColour` | Colour | Price group: what a colour adds. | ڕەنگ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `groupGlass` | Glass | Price group: glass. | شووشە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `groupHardware` | Hardware | Price group: handles, hinges, locks. | ئیکسسوار | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `groupInstallation` | Installation | Price group: installation. | دامەزراندن | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `groupLabour` | Labour | Price group: labour. | کرێی کار | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `groupNormalProfile` | Border and internal lines | Price group: the frame's border and the lines inside the design. | لێوار و هێڵە ناوەکییەکان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `groupOpeningProfile` | Opening profile | Price group: the profile round each opening. | پرۆفایلی بەشی کراوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `groupOtherProfile` | Other profile | Price group: other profile by the metre, a sliding track. | پرۆفایلی تر | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `groupPanel` | Panel | Price group: panel. | پانێڵ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `hasDesignMany` | {n} designs | What a customer has: designs. | {n} دیزاین | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `hasDesignOne` | 1 design | What a customer has: one design. | 1 دیزاین | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `hasDiscount` | a discount | What a customer has: a discount. | داشکاندنێک | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `hasExtraMany` | {n} extra charges | What a customer has: extra charges. | {n} تێچووی زیادە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `hasExtraOne` | 1 extra charge | What a customer has: one extra charge. | 1 تێچووی زیادە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `hasPaymentMany` | {n} payments | What a customer has: payments. | {n} پارەدان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `hasPaymentOne` | 1 payment | What a customer has: one payment. | 1 پارەدان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `hasQuotations` | quotations | What a customer has: quotations. | پێشنیاری نرخ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `hasReceiptMany` | {n} receipts | What a customer has: receipts. | {n} پسوولە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `hwHandle` | Handle | Ironmongery: a handle. | دەسک | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `hwHinge` | Hinge | Ironmongery: a hinge. | لولاو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `hwLock` | Lock | Ironmongery: a lock. | قفڵ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `hwSensor` | Sensor | The sensor that opens an automatic entrance. | هەستەوەر | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `inAddHardwareHelp` | Nothing is added on its own. What you add goes in the middle of this section, and you can drag it where you want it. | Help on a section's panel. | هیچ شتێک بە خۆی زیاد ناکرێت. ئەوەی زیادی دەکەیت دەچێتە ناوەڕاستی ئەم بەشە، و دەتوانیت ڕایبکێشیت بۆ هەر شوێنێک کە دەتەوێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `inDiagonalHelp` | It is built as a bar, exactly where you drew it. On a drawing a diagonal often means the pane opens instead — if that is what you meant, say so and the line becomes the opening. | Help on a diagonal bar's panel. | وەک دابەشکەرێک دروست دەکرێت، ڕێک لەو شوێنەی کێشاوتە. لە نەخشەدا هێڵێکی لار زۆرجار مانای ئەوەیە کە ئەو بەشە دەکرێتەوە — ئەگەر مەبەستت ئەوە بوو، بیڵێ و هێڵەکە دەبێتە بەشی کراوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `inDragSide` | Drag its handle to move this side of the frame square to itself. The other sides stay where they are. | Help on a frame member's panel. | دەسکەکەی ڕابکێشە بۆ جوڵاندنی ئەم لایەی چوارچێوەکە بە ستوونی لەسەر خۆی. لاکانی تر لە شوێنی خۆیان دەمێننەوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `inDrawOutline` | Draw the outline of your {noun}, then read the drawing. Whatever you draw is what gets built — nothing is assumed and nothing is filled in for you. | Design panel before anything is read. | دەوری {noun}ـەکەت بکێشە، پاشان نەخشەکە بخوێنەرەوە. هەرچی بیکێشیت ئەوە دروست دەکرێت — هیچ شتێک گریمانە ناکرێت و هیچ شتێک لە جیاتی تۆ پڕ ناکرێتەوە. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `inEvenly` | Evenly spaced between the two ends, because evenly is the only spacing that is not a decision about where they look best. | Under the hinge count. | بە یەکسانی لە نێوان هەردوو سەرەکەدا دابەش دەکرێن، چونکە یەکسانی تاکە ماوەیەکە کە بڕیار نییە دەربارەی ئەوەی لە کوێ جوانتر دەردەکەون. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `inFollowsDesign` | Nobody has said yet, so this leaf follows the design — a {kind}. Choose to say. | Under the opening type, where the leaf follows the design. | هێشتا کەس نەیگوتووە، بۆیە ئەم باڵە بەدوای دیزاینەکەدا دەڕوات — {kind}. هەڵبژێرە بۆ ئەوەی بیڵێیت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `inHandleHelp` | Measured on the leaf, not on the frame, so it stays where you put it when the opening moves. | Help under the handle's height. | لەسەر باڵەکە دەپێورێت نەک لەسەر چوارچێوەکە، بۆیە کاتێک بەشە کراوەکە دەجوڵێت لە شوێنی خۆی دەمێنێتەوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `inLineInside` | This line is inside that section. It divides that section only, and travels with it. | Under the Divides choice. | ئەم هێڵە لە ناو ئەو بەشەدایە. تەنها ئەو بەشە دابەش دەکات، و لەگەڵیدا دەجوڵێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `inMarkedNothingElse` | You marked this section with a {drawn}. Nothing else opens. | On a marked section's panel. | ئەم بەشەت بە {drawn} نیشانە کرد. هیچ شتێکی تر ناکرێتەوە. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `inMeasuredInOpening` | Measured inside the opening, so it stays where you put it when the opening moves. | Help under a bar's place. | لە ناو بەشە کراوەکەدا دەپێورێت، بۆیە کاتێک بەشە کراوەکە دەجوڵێت لە شوێنی خۆی دەمێنێتەوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `inMovingOpening` | Moving the opening changes which section opens. Neither section changes shape, and whatever you have drawn inside the opening goes with it. | Under the opening's position. | جوڵاندنی بەشە کراوەکە دەیگۆڕێت کە کام بەش دەکرێتەوە. هیچ کام لە بەشەکان شێوەیان ناگۆڕێت، و هەرچی لە ناو بەشە کراوەکەدا کێشاوتە لەگەڵیدا دەڕوات. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `inNobodyAngled` | Nobody has said what this leaf is. An angled design can hold doors or windows, so it does not say which — until you choose, it hangs on its hinges and carries no handle. | Under the opening type, in an angled design. | کەس نەیگوتووە ئەم باڵە چییە. دیزاینێکی لار دەتوانێت دەرگا یان پەنجەرەی تێدابێت، بۆیە نابڵێت کامیانە — تا هەڵدەبژێریت، لەسەر لولاوەکانی هەڵدەواسرێت و هیچ دەسکێکی نییە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `inNobodyBoth` | Nobody has said what this leaf is. This design holds doors and windows, so it does not say either — until you choose, it hangs on its hinges and carries no handle. | Under the opening type, in a door & window design. | کەس نەیگوتووە ئەم باڵە چییە. ئەم دیزاینە دەرگا و پەنجەرەی تێدایە، بۆیە هیچیان نابڵێت — تا هەڵدەبژێریت، لەسەر لولاوەکانی هەڵدەواسرێت و هیچ دەسکێکی نییە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `inOnLeaf` | On {mechanism} — {description}. This is the opening's, so it moves with it. | On a hinge's or handle's panel. | لەسەر {mechanism} — {description}. ئەمە هی بەشە کراوەکەیە، بۆیە لەگەڵیدا دەجوڵێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `inProfileHelp` | One figure for the whole frame, as it is cut from one section of material. | Help under the frame profile. | یەک ژمارە بۆ هەموو چوارچێوەکە، چونکە لە یەک پارچە کەرەستە دەبڕدرێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `inRealSizeHelp` | Type the true measurement. The whole design is scaled to match it, in proportion — nothing moves relative to anything else. | Help under a dimension's real size. | پێوانە ڕاستەقینەکە بنووسە. هەموو دیزاینەکە بە ڕێژە گەورە یان بچووک دەکرێتەوە تا لەگەڵیدا بگونجێت — هیچ شتێک بەراورد بە شتێکی تر ناجوڵێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `inSideHelp` | Moves this side's free end. The other sides keep their sizes, and the slope between them follows. | Help under a side's own size. | سەرە ئازادەکەی ئەم لایە دەجوڵێنێت. لاکانی تر قەبارەی خۆیان دەپارێزن، و لێژییەکەی نێوانیان بەدوایدا دێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `joinAnd` | {a} and {b} | Two things joined: a and b. | {a} و {b} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `joinOr` | {a} or {b} | Two things offered: a or b. | {a} یان {b} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `kindAngled` | Angled / Asymmetrical | Design category: sloped, under-stair and custom shapes. | لار / ناهاوسەنگ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `kindBoth` | Door & window | Design category: doors and windows in one frame. | دەرگا و پەنجەرە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `kindDoor` | Door | Design category: a door. | دەرگا | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `kindUnsupported` | Unsupported category | A category this version does not know. | جۆری پشتگیری‌نەکراو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `kindWindow` | Window | Design category: a window. | پەنجەرە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `lineColour` | {colour} {material} ({grade}) | A price line: what a colour adds to a material's profile. | {colour} {material} ({grade}) | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `lineGlass` | {look} glass | A price line: glass of a look. | شووشەی {look} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `lineInside` | Line {n} (inside {opening}) | A line drawn inside an opening. | هێڵی {n} (لەناو {opening}) | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `lineInstallation` | Installation | A price line: installation. | دامەزراندن | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `lineInstallationArea` | Installation, by area | A price line: installation by area. | دامەزراندن، بەپێی ڕووبەر | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `lineMaking` | Making | A price line: the labour of making. | دروستکردن | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `lineMakingArea` | Making, by area | A price line: labour priced by area. | دروستکردن، بەپێی ڕووبەر | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `lineMakingMaterials` | Making, on materials | A price line: labour as a share of the materials. | دروستکردن، لەسەر کەرەستەکان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `lineNumbered` | Line {n} | A line of the design by its number. | هێڵی {n} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `lineOpeningProfile` | Opening profile — {material} | A price line: the opening profile of a material. | پرۆفایلی بەشی کراوە — {material} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `linePanel` | {colour} panel | A price line: a panel of a colour. | پانێڵی {colour} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `linePieces` | {piece}s | A price line: several pieces of ironmongery (English adds an s). | {piece} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `lineProfile` | {what} — {part} | A price line: a material or category, and border or internal lines. | {what} — {part} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `lineRollers` | Rollers | A price line: the rollers sliding panels run on. | تەگەرەکان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `listComma` | ,  | What separates items in a list, with its space. | ،  | Medium | Longer or technical sentence: check it reads naturally; Begins or ends with a space, which the application keeps — awaiting review |  |
| `matAluminium` | Aluminium | Material: aluminium. | ئەلەمنیۆم | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `matClearGlass` | Clear glass | Material: clear glass. | شووشەی ڕوون | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `matFrostedGlass` | Frosted glass | Material: frosted (obscured) glass. | شووشەی تەماوی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `matPanel` | Solid panel | Material: a solid (opaque) panel. | پانێڵی پڕ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `matSteel` | Steel | Material: steel. | پۆڵا | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `matTintedGlass` | Tinted glass | Material: tinted glass. | شووشەی ڕەنگکراو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `matWood` | Wood | Material: wood. | دار | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `mdNothingHelp` | Draw an outline and read the drawing. The model is built from your lines — there is no stock model to show in the meantime. | Model with nothing drawn. | دەورێک بکێشە و نەخشەکە بخوێنەرەوە. مۆدێلەکە لە هێڵەکانی خۆت دروست دەکرێت — لەم نێوانەدا هیچ مۆدێلێکی ئامادە نییە بۆ پیشاندان. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `mdOpenHelp` | How far the leaves are swung. A way of looking at the model; it changes nothing. | Tooltip. | باڵەکان چەند کراونەتەوە. تەنها شێوازێکی سەیرکردنی مۆدێلەکەیە؛ هیچ شتێک ناگۆڕێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `meanPointsDown` | hinged at the top, opening at the bottom | What a v mark says. | لولاو لە سەرەوە، لە خوارەوە دەکرێتەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `meanPointsLeft` | hinged on the right, opening from the left | What a < mark says. | لولاو لە ڕاست، لە چەپەوە دەکرێتەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `meanPointsRight` | hinged on the left, opening from the right | What a > mark says. | لولاو لە چەپ، لە ڕاستەوە دەکرێتەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `meanPointsUp` | hinged at the bottom, opening at the top | What a ^ mark says. | لولاو لە خوارەوە، لە سەرەوە دەکرێتەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `measBarThickness` | Bar thickness | Size: the thickness of the lines dividing the design. | ئەستووریی دابەشکەر | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `measFixedLight` | Fixed light {n} | A part of the design that does not open, by its number. | بەشی چەسپاوی {n} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `measFrameBorder` | Frame border | Size: the width of the frame's border profile. | لێواری چوارچێوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `measOverallHeight` | Overall height | Size: the whole design's height. | بەرزیی گشتی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `measOverallWidth` | Overall width | Size: the whole design's width. | پانیی گشتی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `measPane` | {around} — {material} {n} | A pane inside a part: the part, what fills the pane, and its number. | {around} — {material} {n} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `mechBifoldHint` | Folds back in leaves | Explains Bi-fold. | بە چەند پەڕەیەک قەد دەبێتەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `mechBottomHungHint` | Hinges at the bottom, opens inward at the top | Explains Bottom hung. | لولاوەکان لە خوارەوەن، لە سەرەوە بۆ ناوەوە دەکرێتەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `mechFixed` | Fixed | How a section opens: it does not. | چەسپاو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `mechFixedHint` | Does not open | Explains Fixed. | ناکرێتەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `mechHingedLeftHint` | Hinges on the left, opens from the right | Explains Hinged left. | لولاوەکان لە چەپن، لە ڕاستەوە دەکرێتەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `mechHingedRightHint` | Hinges on the right, opens from the left | Explains Hinged right. | لولاوەکان لە ڕاستن، لە چەپەوە دەکرێتەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `mechPivotHint` | Turns about a central axis | Explains Pivot. | بە دەوری تەوەرەیەکی ناوەڕاستدا دەسووڕێتەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `mechTiltAndTurnHint` | Tilts at the top and turns on one side | Explains Tilt and turn. | لە سەرەوە لار دەبێتەوە و لە لایەکەوە دەسووڕێتەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `mechTopHungHint` | Hinges at the top, opens outward at the bottom | Explains Top hung. | لولاوەکان لە سەرەوەن، لە خوارەوە بۆ دەرەوە دەکرێتەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `mfIntro` | Enter the real size of each part in centimetres. Nothing is guessed from the sketch; a size that follows from the others is worked out for you. | Sizes form. | قەبارەی ڕاستەقینەی هەر بەشێک بە سانتیمەتر بنووسە. هیچ شتێک لە نەخشەکەوە مەزەندە ناکرێت؛ قەبارەیەک کە لە ئەوانی ترەوە دێت بۆت هەژمار دەکرێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `mfLeft` | {count, plural, =1{1 size still to give.} other{{count} sizes still to give.}} | Sizes form. | {count, plural, other{{count} قەبارە ماوە بۆ دان.}} | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `missBorderLines` | {what} border and lines | What the price list lacks: border and lines of a material or category. | لێوار و هێڵەکانی {what} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `missInfill` | {material} infill | What the price list lacks: an infill material. | پڕکەرەوەی {material} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `missPiece` | a {piece} | What the price list lacks: a piece of ironmongery. | {piece} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `missProfile` | {material} profile | What the price list lacks: a material's profile. | پرۆفایلی {material} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `mnBarRate` | The {material} bar rate ({bar} a metre): bars are now normal profile, priced at the frame rate ({frame}). | Price list upgrade note. | نرخی دابەشکەری {material} (‎{bar}‎ بۆ هەر مەترێک): دابەشکەرەکان ئێستا پرۆفایلی ئاساین، بە نرخی چوارچێوە (‎{frame}‎) هەژمار دەکرێن. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `mnCatalog` | Colours are now one catalog: a colour sold in more than one material is one colour with a rate on each, at the figures it had. | Price list upgrade note. | ڕەنگەکان ئێستا یەک کاتالۆگن: ڕەنگێک کە بە زیاتر لە یەک کەرەستە دەفرۆشرێت یەک ڕەنگە و نرخێکی لەسەر هەریەکەیان هەیە، بە هەمان ژمارەکانی پێشوو. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `mnJoint` | A price per angled joint ({joint}): an angled design is now priced by its own measurements. | Price list upgrade note. | نرخێک بۆ هەر جومگەیەکی لار (‎{joint}‎): دیزاینی لار ئێستا بەپێی پێوانەکانی خۆی نرخی بۆ دادەنرێت. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `mnLeaf` | A price per leaf ({each}): a leaf is now priced by its opening profile and its ironmongery. | Price list upgrade note. | نرخێک بۆ هەر باڵێک (‎{each}‎): باڵ ئێستا بەپێی پرۆفایلی بەشی کراوە و ئیکسسوارەکەی نرخی بۆ دادەنرێت. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `msBarThickness` | A bar has to have some thickness. | Size check. | دابەشکەر دەبێت ئەستوورییەکی هەبێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `msgCalculate` | Calculate the price. | A design that can be priced and has not been. | نرخەکە بژمێرە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `msgRecalculate` | The design or the prices changed since this price was calculated. Calculate it again. | Why the kept price is not current. | دیزاینەکە یان نرخەکان لەوەتەی ئەم نرخە ژمێردراوە گۆڕاون. دووبارە بیژمێرەوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `msNoFrame` | No frame. | Size check. | چوارچێوە نییە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `msNotFit` | That does not fit. | Size check. | ئەوە ناگونجێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `msNotFitBeside` | That does not fit beside the parts next to it. | Size check. | ئەوە لە تەنیشت بەشەکانی دراوسێیدا ناگونجێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `msNotFitInside` | That does not fit the parts inside it. | Size check. | ئەوە لەگەڵ بەشەکانی ناوەوەیدا ناگونجێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `msNothing` | Nothing to measure. | Size check. | هیچ شتێک نییە بۆ پێوان. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `msSmallerThanFrame` | Smaller than the frame around it. | Size check. | لە چوارچێوەی دەوروبەری بچووکترە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `msTooWide` | Too wide for the frame. | Size check. | بۆ چوارچێوەکە زۆر پانە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `mtChoose` | Choose glass or panel for any part. Only what fills the part changes — every line stays where you drew it. | Material form. | بۆ هەر بەشێک شووشە یان پانێڵ هەڵبژێرە. تەنها ئەوەی بەشەکە پڕ دەکاتەوە دەگۆڕێت — هەموو هێڵێک لەو شوێنەی کێشاوتە دەمێنێتەوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `nameProblem` | Enter a name for this design, such as the room or the place it is for. | A design's name left empty. | ناوێک بۆ ئەم دیزاینە بنووسە، وەک ئەو ژوور یان شوێنەی کە بۆی دروست دەکرێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `noDesignsMatch` | No designs match {what} | A search or filter that found nothing. | هیچ دیزاینێک لەگەڵ {what} ناگونجێت | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `noteIncomplete` | Price unavailable until design is completed | Where the price would be. | نرخ بەردەست نییە تا دیزاینەکە تەواو دەبێت | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `noteNotCalculated` | Not calculated yet | Where the price would be. | هێشتا نەژمێردراوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `noteNotRead` | Price unavailable until drawing is read | Where the price would be. | نرخ بەردەست نییە تا نەخشەکە دەخوێندرێتەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `noteRecalculate` | Price needs recalculation | Where the price would be: the design or prices changed. | نرخ پێویستی بە دووبارە ژمێرینەوە هەیە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `noteUnavailable` | Price unavailable | Where the price would be. | نرخ بەردەست نییە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `notSelected` | Not selected | Nothing chosen yet. | هەڵنەبژێردراوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `nounAngled` | angled design | An angled design, in the middle of a sentence. | دیزاینی لار | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `nounBoth` | door & window | A door and window design, in the middle of a sentence. | دەرگا و پەنجەرە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `nounDoor` | door | A door, in the middle of a sentence. | دەرگا | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `nounUnsupported` | design of an unsupported category | A design of an unknown category, in the middle of a sentence. | دیزاینی جۆرێکی پشتگیری‌نەکراو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `nounWindow` | window | A window, in the middle of a sentence. | پەنجەرە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `openingAlone` | Opening | An opening, where it has no number. | بەشی کراوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `openingNumbered` | Opening {number} | An opening (a part of the design that opens) by its number across the drawing. | بەشی کراوەی {number} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `openingsCount` | {count, plural, =1{1 opening} other{{count} openings}} | How many openings a design has. | {count, plural, other{{count} بەشی کراوە}} | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `openingThe` | the opening | The opening, in a sentence. | بەشە کراوەکە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `paCompleteDesign` | Please complete the incomplete part of the design to calculate the price. | Price button. | تکایە بەشە ناتەواوەکەی دیزاینەکە تەواو بکە بۆ هەژمارکردنی نرخ. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `partA` | a part | A part of the design, in a sentence. | بەشێک | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `partBorder` | Border | The frame's border profile. | لێوار | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `partFixed` | Fixed | Where a part is: a fixed part of the design, in no opening. | چەسپاو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `partLines` | Internal lines | The lines inside the design, cut from the same profile. | هێڵە ناوەکییەکان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `partNumbered` | Part {number} | A part of the design, by its place in reading order. | بەشی {number} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `partsLeft` | {count, plural, =1{1 part still to choose.} other{{count} parts still to choose.}} | How many parts are still to be said glass or panel. | {count, plural, other{{count} بەش ماوە بۆ هەڵبژاردن.}} | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `payBankTransfer` | Bank transfer | Payment method. | گواستنەوەی بانکی | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `payCard` | Card | Payment method. | کارت | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `payCash` | Cash | Payment method. | نەقد | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `payLegacy` | Legacy / unknown | Payment method of a payment brought over from before the ledger. | کۆن / نەزانراو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `payLegacyNote` | Migrated from the previous customer payment balance. | Note on the one payment carried over from an older customer record. | لە باڵانسی پێشووی پارەدانی کڕیارەوە گوازرایەوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `paymentNotFuture` | Payments cannot be dated in the future. | Date check for a payment. | پارەدان ناتوانێت بەرواری داهاتووی هەبێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `payNothingToPay` | Nothing to pay | A customer's money: nothing to pay. | هیچ پارەیەک نییە بۆ دان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `payOther` | Other | Payment method: another way. | هی تر | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `payOtherDetail` | Other — {detail} | A payment method described by the user. | تر — {detail} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `payPaidInFull` | Paid in full | A customer's money: all paid. | بە تەواوی دراوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `payPricingIncomplete` | Pricing incomplete | A customer's money: the total is not final yet. | نرخدانان تەواو نییە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `payTypePayment` | Payment | Money received from the customer. | پارەدان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `payTypeRefund` | Refund | Money returned to the customer. | گەڕاندنەوەی پارە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `pinSetNote` | No owner PIN is set on this device. The PIN you set now is what signs the owner in from here on — to change the factory prices, give discounts and manage staff. | Note. | هیچ PINێکی خاوەن لەسەر ئەم ئامێرە دانەنراوە. ئەو PINەی ئێستا دایدەنێیت لەمەودوا خاوەن پێی دەچێتە ژوورەوە — بۆ گۆڕینی نرخەکانی کارگە، دانی داشکاندن و بەڕێوەبردنی کارمەندان. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `pinTooShort` | Use at least {n} digits. | A PIN that is too short. | لانیکەم {n} ژمارە بەکاربهێنە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `ppCorrectGeometry` | Please correct the geometry shown under the drawing to calculate the price. | Points to the geometry check. | تکایە ئەو شێوەکارییە ڕاست بکەرەوە کە لە ژێر نەخشەکەدا پیشان دراوە بۆ هەژمارکردنی نرخ. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `ppFixed` | fixed | A fixed price line. | جێگیر | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `ppPercentOf` | {percent}% of {amount} | A percentage line: so much per cent of an amount. | ‎{percent}‎% ی ‎{amount}‎ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qChangeIt` | I will change it | Answer: the user will change the drawing. | خۆم دەیگۆڕم | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qChangeItDetail` | Go back to the drawing and draw it as you want it. | Explains I will change it. | بگەڕێوە بۆ نەخشەکە و وەک خۆت دەتەوێت بیکێشە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qCloseIt` | Close it | Answer: close the side. | دایبخە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qCloseItDetail` | Put the frame across {side}, straight between the two ends you drew. | Explains Close it. | چوارچێوەکە بە درێژایی {side} دابنێ، ڕاستەوخۆ لە نێوان ئەو دوو سەرەی کێشاوتن. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qConstructionDesign` | How should this design be constructed? | Question as a door & window design starts: panel, glass or both. | ئەم دیزاینە چۆن دروست بکرێت؟ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qConstructionDetail` | You decide what fills the parts you draw. Nothing is divided or moved for you, and every part can be changed later. | Question detail: what a door is built of. | تۆ بڕیار دەدەیت چی ئەو بەشانە پڕ دەکاتەوە کە دەیانکێشیت. هیچ شتێک لە جیاتی تۆ دابەش ناکرێت یان ناجوڵێنرێت، و هەموو بەشێک دواتر دەگۆڕدرێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qConstructionDoor` | How should this door be constructed? | Question as a door design starts: panel, glass or both. | ئەم دەرگایە چۆن دروست بکرێت؟ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qDrawRest` | Let me draw the rest | Answer: the user will finish the outline. | با باقییەکەی بکێشم | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qDrawRestDetail` | Go back to the drawing and close the outline yourself. | Explains Let me draw the rest. | بگەڕێوە بۆ نەخشەکە و خۆت دەوروبەرەکە دابخە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qGapDetail` | Do you want it this way, or are you going to change it? Nothing has been added or taken away. | Question: one side of the outline left open. | دەتەوێت بەم شێوەیە بێت، یان دەیگۆڕیت؟ هیچ شتێک زیاد یان کەم نەکراوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qGapPrompt` | Your design is not closed — {side} is open. | Question: one side of the outline left open. | دیزاینەکەت داخراو نییە — {side} کراوەیە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qKeepOpen` | Keep it open | Answer: keep the side open. | با کراوە بێت | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qKeepOpenDetail` | Build it as drawn, with no frame across {side}. | Explains Keep it open. | وەک کێشراوە دروستی بکە، بەبێ چوارچێوە بە درێژایی {side}. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qKeepOpenFootDetail` | Build it as drawn, with no frame across {side} — a door runs down to the floor. | Explains Keep it open, for the bottom. | وەک کێشراوە دروستی بکە، بەبێ چوارچێوە بە درێژایی {side} — دەرگا تا زەوی دەگات. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qKindDetail` | A mark says this section opens. It does not say whether it is a door or a window, and the two are not made the same. This is about this one opening; every other section is untouched. | Question detail: door or window. | نیشانەیەک دەڵێت ئەم بەشە دەکرێتەوە. نابڵێت دەرگایە یان پەنجەرە، و ئەو دووانە وەک یەک دروست ناکرێن. ئەمە تەنها دەربارەی ئەم بەشە کراوەیەیە؛ هەموو بەشەکانی تر دەستیان لێ نادرێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qKindDoorDetail` | A leaf you walk through. | Answer detail: a door. | باڵێک کە پیایدا تێدەپەڕیت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qKindPrompt` | What is {opening}? | Question: is this opening a door or a window. | {opening} چییە؟ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qKindWindowDetail` | A leaf you open from indoors. | Answer detail: a window. | باڵێک کە لە ناوەوە دەیکەیتەوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qNotASymbol` | It is not an opening mark | Answer: the mark is not an opening mark. | ئەمە نیشانەی کردنەوە نییە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qNotASymbolDetail` | Build it as lines, exactly where it was drawn. | Explains the answer. | وەک هێڵ دروستی بکە، ڕێک لەو شوێنەی کێشراوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qNotClosedDetail` | Your lines do not join up into a shape, so there is no outer frame yet. Nothing has been changed or added. | Question: lines that do not close into a shape. | هێڵەکانت پێکەوە شێوەیەک دروست ناکەن، بۆیە هێشتا چوارچێوەی دەرەوە نییە. هیچ شتێک نەگۆڕدراوە و زیاد نەکراوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qNotClosedPrompt` | The outline does not close. What would you like to do? | Question: lines that do not close into a shape. | دەوروبەری دیزاینەکە داناخرێت. دەتەوێت چی بکەیت؟ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qOnePart` | Your design has no internal division yet | Said where a design to be both glass and panel has only one part. | دیزاینەکەت هێشتا هیچ دابەشبوونێکی ناوەکی نییە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qOnePartDetail` | Draw a divider first to create separate panel and glass parts. Nothing is divided for you. | Detail for the one-part case. | سەرەتا دابەشکەرێک بکێشە بۆ دروستکردنی بەشی جیاوازی پانێڵ و شووشە. هیچ شتێک لە جیاتی تۆ دابەش ناکرێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qParts` | Which parts should be glass and which should be panel? | Question: glass or panel, part by part. | کام بەش شووشە بێت و کامیان پانێڵ؟ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qPartsDetail` | Choose for each part you drew. The lines stay exactly where you drew them. | Detail of the glass-or-panel question. | بۆ هەر بەشێک کە کێشاوتە هەڵبژێرە. هێڵەکان ڕێک لەو شوێنە دەمێننەوە کە کێشاوتن. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qsAccepted` | Accepted | Quotation status. | پەسەندکراو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qsDraft` | Draft | Quotation status. | ڕەشنووس | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qsExpired` | Expired | Quotation status. | بەسەرچوو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qsIssued` | Issued | Quotation status. | دەرکراو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qsRejected` | Rejected | Quotation status. | ڕەتکراوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qSymbolDetail` | The mark is outside the design, so there is no section it could be in. Say which one you meant. | Question: a mark drawn outside the design. | نیشانەکە لە دەرەوەی دیزاینەکەیە، بۆیە هیچ بەشێک نییە کە تێیدا بێت. بڵێ مەبەستت کامیان بوو. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qSymbolOpen` | Open this one, {meaning}. | Answer: open this section, and how. | ئەمە بکەرەوە، {meaning}. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `qSymbolPrompt` | Which section does this {glyph} belong to? | Question: a mark drawn outside the design. | ئەم {glyph}ـە سەر بە کام بەشە؟ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `quoteChooseOne` | Choose at least one design. | Quotation check. | لانیکەم یەک دیزاین هەڵبژێرە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `quoteExtraCurrency` | The extra charge "{name}" is in {currency}, not {base}. Write it in {base} first. | Quotation check. | تێچووی زیادەی "{name}" بە {currency}ە، نەک {base}. سەرەتا بە {base} بینووسە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `quoteNotReady` | {message} Not ready: {names}. | Quotation check, naming the designs. | {message} ئامادە نییە: {names}. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rateAsNumber` | Enter the rate as a number, such as 1.10. | Exchange rate check. | نرخی گۆڕینەوە وەک ژمارە بنووسە، بۆ نموونە 1.10. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rateMoreThanNothing` | The rate must be more than nothing. | Exchange rate check. | نرخی گۆڕینەوە دەبێت لە سفر زیاتر بێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `readinessMoreMany` | {first} {more} more things need completing too. | The first missing thing, and how many more (several). | {first} {more} شتی تریش پێویستیان بە تەواوکردنە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `readinessMoreOne` | {first} {more} more thing needs completing too. | The first missing thing, and how many more (one). | {first} {more} شتی تریش پێویستی بە تەواوکردنە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `reasonListCannot` | The price list cannot price this design. | Why a design has no price. | لیستی نرخەکان ناتوانێت نرخ بۆ ئەم دیزاینە دابنێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `reasonUnsupported` | Unsupported category. Price unavailable. | Why a design of an unknown category has no price. | جۆری پشتگیری‌نەکراو. نرخ بەردەست نییە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `refundNotFuture` | Refunds cannot be dated in the future. | Date check for a refund. | گەڕاندنەوەی پارە ناتوانێت بەرواری داهاتووی هەبێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `refundNothingPaid` | Nothing has been paid, so nothing can be refunded. | Refund check. | هیچ پارەیەک نەدراوە، بۆیە هیچ شتێک ناگەڕێنرێتەوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `refundNothingPaidIn` | Nothing has been paid in {currency}, so nothing can be refunded. | Refund check, in another currency. | هیچ پارەیەک بە {currency} نەدراوە، بۆیە هیچ شتێک ناگەڕێنرێتەوە. | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `refundTooMuch` | A refund cannot be more than the net paid, {amount}. | Refund check. | گەڕاندنەوەی پارە ناتوانێت لە کۆی پارەی دراو زیاتر بێت، ‎{amount}‎. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `reqCategoryAll` | Please choose whether the {material} profile is {choices} to calculate the price. | Why an aluminium design cannot be priced: no profile category chosen. | تکایە بۆ ژمێرینی نرخ جۆری پرۆفایلی {material} هەڵبژێرە: {choices}. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `reqCategorySome` | Please choose {choices} for {parts} to calculate the price. | Why an aluminium design cannot be priced: some parts have no category. | تکایە بۆ ژمێرینی نرخ {choices} بۆ {parts} هەڵبژێرە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `reqConstruction` | Please choose what the door is built of — panel, glass or both — to calculate the price. | Why a door cannot be priced. | تکایە بۆ ژمێرینی نرخ هەڵبژێرە دەرگاکە لە چی دروست دەکرێت — پانێڵ، شووشە یان هەردووکیان. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `reqDraw` | Please draw the design to calculate the price. | Why a design cannot be priced. | تکایە بۆ ژمێرینی نرخ دیزاینەکە بکێشە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `reqFrame` | Please complete the outer frame to calculate the price. | Why a design cannot be priced. | تکایە بۆ ژمێرینی نرخ چوارچێوەی دەرەوە تەواو بکە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `reqFrameSizes` | Please give the {which} to calculate the price. | Why a design cannot be priced: sizes of the frame not given. | تکایە بۆ ژمێرینی نرخ {which} بنووسە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `reqGeometry` | Please correct the geometry to calculate the price: {problem} | Why a design cannot be priced, with the geometry problem. | تکایە بۆ ژمێرینی نرخ شێوەکاری (جیۆمەتری) ڕاست بکەرەوە: {problem} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `reqGroupSizes` | Please complete the dimensions of {group} (its {which}) to calculate the price. | Why a design cannot be priced: sizes of one part not given. | تکایە بۆ ژمێرینی نرخ پێوانەکانی {group} ({which}) تەواو بکە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `reqNotRead` | The drawing has changes that have not been read. Please Read the drawing before calculating the price. | Why a design cannot be priced: lines drawn since the last reading. | نەخشەکە گۆڕانکاریی تێدایە کە نەخوێندراونەتەوە. تکایە پێش ژمێرینی نرخ نەخشەکە بخوێنەرەوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `reqOpeningKind` | Please say whether {opening} is a door or a window to calculate the price. | Why a design cannot be priced. | تکایە بۆ ژمێرینی نرخ بڵێ {opening} دەرگایە یان پەنجەرە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `reqPanelOrGlass` | Please complete the panel/glass selection to calculate the price. | Why a design cannot be priced. | تکایە بۆ ژمێرینی نرخ هەڵبژاردنی پانێڵ/شووشە تەواو بکە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `reqProfile` | Please choose the material and colour of the profile to calculate the price. | Why a design cannot be priced. | تکایە بۆ ژمێرینی نرخ کەرەستە و ڕەنگی پرۆفایلەکە هەڵبژێرە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `reqUnsupported` | This design's category is not supported by this version of ProFrame, so its price is unavailable. | Why a design cannot be priced. | جۆری ئەم دیزاینە لەم وەشانەی ProFrame پشتگیری ناکرێت، بۆیە نرخەکەی بەردەست نییە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfAMetre` | A metre | Price list field. | بۆ هەر مەترێک | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfAnyOtherColour` | Any other colour | Price list field: a colour not named. | هەر ڕەنگێکی تر | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfAnyOtherColourOf` | Any other colour — {material} | Price list section. | هەر ڕەنگێکی تر — {material} | Medium | Built from a template: check the word order and suffixes with real values — awaiting review |  |
| `rfBorderLines` | Border and internal lines | Price list section. | لێوار و هێڵە ناوەکییەکان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfByArea` | By area | Price list field: a figure a square metre. | بەپێی ڕووبەر | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfEachDesign` | Each design | Price list field: a fixed figure a design. | هەر دیزاینێک | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfGlassSingle` | Glass (single sheet) | Price list section. | شووشە (تاک چین) | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfHardware` | Hardware | Price list section. | ئیکسسوار | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfInstallation` | Installation | Price list section. | دامەزراندن | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfLabourOf` | Labour — {category} | Price list section. | کرێی کار — {category} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfNeeded` | A price is needed here. | Factory price check. | لێرە نرخێک پێویستە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfOnMaterials` | On the materials | Price list field. | لەسەر کەرەستەکان | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfOnProfile` | On the profile | Price list field. | لەسەر پرۆفایل | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfOpeningProfile` | Opening profile | Price list section. | پرۆفایلی بەشی کراوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfPanel` | Panel | Price list section. | پانێڵ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfUnitEach` | each | Unit after a price field. | دانە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfUnitFixed` | fixed | Unit after a price field. | جێگیر | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfUnitRollers` | rollers | Unit after a price field. | تەگەرە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfWhole` | Enter a whole number. | Factory price check. | ژمارەیەکی تەواو بنووسە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `rfZeroOrMore` | Enter a figure of 0 or more. | Factory price check. | ژمارەیەکی 0 یان زیاتر بنووسە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `roleNobody` | Nobody signed in | Who is at the device: nobody signed in. | کەس نەچووەتە ژوورەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `roleOwner` | Owner | Who is signed in: the workshop's owner. | خاوەن | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `roleStaff` | Staff | Who is at the device: staff. | کارمەند | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `sectionDescribed` | The {place} section — {size} | A section named by where it is and its size. | بەشی {place} — ‎{size}‎ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `sentenceStop` | . | The full stop that ends a sentence. | . | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `settingsLanguageNote` | The application changes language at once. Customers, designs, prices and records are not changed. | Under the language choice. | زمانی بەرنامەکە دەستبەجێ دەگۆڕێت. کڕیاران و دیزاینەکان و نرخەکان و تۆمارەکان ناگۆڕێن. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `sideHeight` | {side} height | The height of one side of an angled frame. | بەرزیی {side} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `sideWidth` | {side} width | The width of one side of an angled frame. | پانیی {side} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `staffNameNeeded` | Enter a name. | A member of staff with no name. | ناوێک بنووسە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `staffNameTaken` | A member of staff is already called that. | A member of staff's name already used. | کارمەندێک هەیە بەم ناوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `stateComplete` | Complete | A design that can be priced. | تەواو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `stateIncomplete` | Incomplete | A design that cannot be priced yet. | ناتەواو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `stateNotRead` | Drawing not read | A design's card: lines drawn and not read. | نەخشە نەخوێندراوەتەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `stillMixed` | This is where the design starts, not a limit on it: any opening you mark can still be made a door or a window, and fixed areas sit beside them in the same frame. | Note under the category cards. | ئەمە سەرەتای دیزاینەکەیە، نەک سنوورێک بۆی: هەر بەشێکی کراوە کە نیشانەی دەکەیت دەتوانرێت بکرێتە دەرگا یان پەنجەرە، و بەشە چەسپاوەکان لە هەمان چوارچێوەدا لە تەنیشتیانن. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `storeCustomerGone` | This customer is no longer kept. | A customer that has been removed. | ئەم کڕیارە ئیتر هەڵنەگیراوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `takeoffNoSize` | The design has no width or no height. | Why a design cannot be measured. | دیزاینەکە پانی یان بەرزیی نییە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `takeoffNothing` | Nothing has been drawn yet. | Why a design cannot be measured. | هێشتا هیچ شتێک نەکێشراوە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `takeoffOutline` | The outline cannot be measured. | Why a design cannot be measured. | دەوروبەری دیزاینەکە ناپێورێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `tbDarkInk` | On the dark sheet a dark ink is shown light, so it can be seen. The drawing keeps the colour you choose. | Pen colour dialog in the dark appearance. | لەسەر پەڕەی تاریک مەرەکەبی تاریک بە ڕووناکی پیشان دەدرێت تا ببینرێت. نەخشەکە ئەو ڕەنگە دەپارێزێت کە هەڵیدەبژێریت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `unitEach` | each | Price unit: counted by the piece. | دانە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `unsupportedMessage` | This design was made with a newer version of ProFrame, or has a category this version does not recognise. It is shown exactly as it was saved and cannot be changed here, so nothing in it is lost. Its original category is kept. | Note on a design of an unknown category. | ئەم دیزاینە بە وەشانێکی نوێتری ProFrame دروستکراوە، یان جۆرێکی هەیە کە ئەم وەشانە نایناسێتەوە. وەک خۆی کە پاشەکەوت کراوە پیشان دەدرێت و لێرە ناگۆڕدرێت، بۆیە هیچ شتێکی لێ ون نابێت. جۆرە سەرەکییەکەی هەڵدەگیرێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `untitledDesign` | Untitled {noun} | A design with no name, e.g. 'Untitled window'. | {noun}ی بێ‌ناو | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `viewOnlyMessage` | View only. You do not have permission to edit designs, so nothing you change here is kept. Sign in as somebody who may. | Note under the drawing for somebody who may not edit. | تەنها بینین. مۆڵەتی دەستکاریکردنی دیزاینەکانت نییە، بۆیە هیچ گۆڕانکارییەک لێرە هەڵناگیرێت. وەک کەسێک بچۆرە ژوورەوە کە مۆڵەتی هەیە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `whereBoth` | {vertical} {horizontal} | Where a section is: e.g. upper left. | {vertical}ی {horizontal} | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `whereLeft` | left | Where a section is: left. | چەپ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `whereLower` | lower | Where a section is: lower. | خوارەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `whereRight` | right | Where a section is: right. | ڕاست | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `whereUpper` | upper | Where a section is: upper. | سەرەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `whyCalculateMany` | {n} designs need their prices calculated | Why a customer's total is not final. | نرخی {n} دیزاین پێویستی بە ژمێرینە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `whyCalculateOne` | 1 design needs its price calculated | Why a customer's total is not final. | نرخی 1 دیزاین پێویستی بە ژمێرینە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `whyCannotMany` | {n} designs cannot be priced | Why a customer's total is not final. | نرخ بۆ {n} دیزاین دانانرێت | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `whyCannotOne` | 1 design cannot be priced | Why a customer's total is not final. | نرخ بۆ 1 دیزاین دانانرێت | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `whyExtraMany` | {n} extra charges are in {currencies}, not {currency}. | Why a customer's total is not final: extras in another currency. | {n} تێچووی زیادە بە {currencies}ـن، نەک {currency}. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `whyExtraOne` | An extra charge is in {currencies}, not {currency}. | Why a customer's total is not final: an extra in another currency. | تێچوویەکی زیادە بە {currencies}ـە، نەک {currency}. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `whyIncompleteMany` | {n} designs are incomplete | Why a customer's total is not final. | {n} دیزاین ناتەواون | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `whyIncompleteOne` | 1 design is incomplete | Why a customer's total is not final. | 1 دیزاین ناتەواوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xAlreadyItem` | {what} ({amount}) | A group already priced and what it comes to. | {what} (‎{amount}‎) | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xAlreadyMany` | {what} are already calculated from the design. Add this only if it is an additional charge. | An extra that may charge twice for some things. | {what} پێشتر لە دیزاینەکەوە هەژمار کراون. تەنها ئەگەر تێچوویەکی زیادەیە زیادی بکە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xAlreadyOne` | {what} is already calculated from the design. Add this only if it is an additional charge. | An extra that may charge twice for one thing. | {what} پێشتر لە دیزاینەکەوە هەژمار کراوە. تەنها ئەگەر تێچوویەکی زیادەیە زیادی بکە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xcInstallation` | Installation | Category of an extra charge. | دامەزراندن | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xcLabour` | Labour | Category of an extra charge. | کرێی کار | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xcMaterial` | Material | Category of an extra charge. | کەرەستە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xcOther` | Other | Category of an extra charge. | تر | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xcService` | Service | Category of an extra charge. | خزمەتگوزاری | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xcTransport` | Transport | Category of an extra charge. | گواستنەوە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xNameNeeded` | Enter what the extra is. | Extra charge check. | بنووسە تێچووە زیادەکە چییە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xPriceEnter` | Enter the unit price. | Extra charge check. | نرخی یەکە بنووسە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xPriceNotBelow` | A unit price cannot be below nothing. | Extra charge check. | نرخی یەکە ناتوانێت لە سفر کەمتر بێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xPriceNumber` | Enter the unit price as a number, such as 3.25. | Extra charge check. | نرخی یەکە وەک ژمارە بنووسە، بۆ نموونە 3.25. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xPricePlaces` | Enter the unit price to the cent — two decimal places at most. | Extra charge check. | نرخی یەکە تا سەنت بنووسە — زۆرترین دوو ژمارە دوای خاڵ. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xQtyEnter` | Enter the quantity. | Extra charge check. | بڕەکە بنووسە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xQtyMore` | The quantity must be more than nothing. | Extra charge check. | بڕەکە دەبێت لە سفر زیاتر بێت. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xQtyNumber` | Enter the quantity as a number, such as 5 or 2.5. | Extra charge check. | بڕەکە وەک ژمارە بنووسە، بۆ نموونە 5 یان 2.5. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xQtyPlaces` | Enter the quantity to three decimal places at most. | Extra charge check. | بڕەکە بە زۆرترین سێ ژمارە دوای خاڵ بنووسە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuBottle` | bottle | Unit of an extra charge, one. | بوتڵ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuBottles` | bottles | Unit of an extra charge, more than one. | بوتڵ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuDay` | day | Unit of an extra charge, one. | ڕۆژ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuDays` | days | Unit of an extra charge, more than one. | ڕۆژ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuHour` | hour | Unit of an extra charge, one. | کاتژمێر | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuHours` | hours | Unit of an extra charge, more than one. | کاتژمێر | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuKg` | kg | Unit of an extra charge, one. | کیلۆ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuKgs` | kg | Unit of an extra charge, more than one. | کیلۆ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuMetre` | metre | Unit of an extra charge, one. | مەتر | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuMetres` | metres | Unit of an extra charge, more than one. | مەتر | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xUnitNeeded` | Choose or type the unit. | Extra charge check. | یەکەکە هەڵبژێرە یان بینووسە. | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuPiece` | piece | Unit of an extra charge, one. | دانە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuPieces` | pieces | Unit of an extra charge, more than one. | دانە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuRoll` | roll | Unit of an extra charge, one. | ڕۆڵ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuRolls` | rolls | Unit of an extra charge, more than one. | ڕۆڵ | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuSet` | set | Unit of an extra charge, one. | سێت | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuSets` | sets | Unit of an extra charge, more than one. | سێت | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuSquareMetre` | square metre | Unit of an extra charge, one. | مەتری چوارگۆشە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuSquareMetres` | square metres | Unit of an extra charge, more than one. | مەتری چوارگۆشە | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuTrip` | trip | Unit of an extra charge, one. | گەشت | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `xuTrips` | trips | Unit of an extra charge, more than one. | گەشت | Medium | Longer or technical sentence: check it reads naturally — awaiting review |  |
| `acActive` | Active | A member of staff's status. | چالاک | High | Common interface wording — awaiting review |  |
| `acAddStaff` | Add staff member | Button and title. | زیادکردنی کارمەند | High | Common interface wording — awaiting review |  |
| `acAsOwner` | Sign in as owner | Menu. | چوونە ژوورەوە وەک خاوەن | High | Common interface wording — awaiting review |  |
| `acAsStaff` | Sign in as staff | Menu. | چوونە ژوورەوە وەک کارمەند | High | Common interface wording — awaiting review |  |
| `acChooseWho` | Choose who you are. | Sign-in check. | هەڵبژێرە تۆ کێیت. | High | Common interface wording — awaiting review |  |
| `acInactive` | Inactive | A member of staff's status. | ناچالاک | High | Common interface wording — awaiting review |  |
| `acName` | Name | Field. | ناو | High | Common interface wording — awaiting review |  |
| `acNoAccounts` | No accounts yet — working as staff | Who is at the device. | هێشتا هیچ هەژمارێک نییە — وەک کارمەند کار دەکات | High | Common interface wording — awaiting review |  |
| `acNobody` | Nobody signed in | Who is at the device. | کەس نەچووەتە ژوورەوە | High | Common interface wording — awaiting review |  |
| `acNoStaff` | No member of staff has been added yet. | Staff screen. | هێشتا هیچ کارمەندێک زیاد نەکراوە. | High | Common interface wording — awaiting review |  |
| `acPin` | PIN | Field. | PIN | High | Common interface wording — awaiting review |  |
| `acSignedInAs` | Signed in as {who} | Who is at the device. | چوویتە ژوورەوە وەک {who} | High | Common interface wording — awaiting review |  |
| `acSignIn` | Sign in | Button. | چوونە ژوورەوە | High | Common interface wording — awaiting review |  |
| `acSignOut` | Sign out | Menu. | چوونە دەرەوە | High | Common interface wording — awaiting review |  |
| `acStaffPermissions` | Staff & permissions | Menu and title. | کارمەندان و مۆڵەتەکان | High | Common interface wording — awaiting review |  |
| `actAdd` | Add | Button: add. | زیادکردن | High | Common interface wording — awaiting review |  |
| `actApply` | Apply | Button: apply a typed value. | جێبەجێکردن | High | Common interface wording — awaiting review |  |
| `actBack` | Back | Button: go back a step. | گەڕانەوە | High | Common interface wording — awaiting review |  |
| `actCancel` | Cancel | Button: close a dialog without doing anything. | هەڵوەشاندنەوە | High | Common interface wording — awaiting review |  |
| `actClose` | Close | Button: close. | داخستن | High | Common interface wording — awaiting review |  |
| `actContinue` | Continue | Button: go on to the next step. | بەردەوامبوون | High | Common interface wording — awaiting review |  |
| `actDelete` | Delete | Button: delete. | سڕینەوە | High | Common interface wording — awaiting review |  |
| `actDone` | Done | Button: finished choosing. | تەواو | High | Common interface wording — awaiting review |  |
| `actHide` | Hide | Button: stop showing a highlighted part. | شاردنەوە | High | Common interface wording — awaiting review |  |
| `actionDeleteLine` | Remove it from this device. | Design actions sheet: Delete. | لەم ئامێرە لایببە. | High | Common interface wording — awaiting review |  |
| `actionDuplicateLine` | A copy to change without touching this one. | Design actions sheet: Duplicate. | کۆپییەک بۆ گۆڕین بەبێ دەستلێدان لەمیان. | High | Common interface wording — awaiting review |  |
| `actionEditLine` | Change the name of this design. | Design actions sheet: Edit information. | ناوی ئەم دیزاینە بگۆڕە. | High | Common interface wording — awaiting review |  |
| `actionOpenLine` | Carry on with this design. | Design actions sheet: Open. | لەسەر ئەم دیزاینە بەردەوام بە. | High | Common interface wording — awaiting review |  |
| `actLater` | Later | Button: answer later. | دواتر | High | Common interface wording — awaiting review |  |
| `actNotNow` | Not now | Button: put a question away without answering. | ئێستا نا | High | Common interface wording — awaiting review |  |
| `actRemove` | Remove | Button: remove. | لابردن | High | Common interface wording — awaiting review |  |
| `actSave` | Save | Button: save. | پاشەکەوتکردن | High | Common interface wording — awaiting review |  |
| `actShowMe` | Show me | Button: light the part a message is about on the drawing. | پیشانم بدە | High | Common interface wording — awaiting review |  |
| `acWho` | Who | Field. | کێ | High | Common interface wording — awaiting review |  |
| `acWrongPin` | That is not their PIN. | Sign-in check. | ئەوە PINەکەی ئەو نییە. | High | Common interface wording — awaiting review |  |
| `address` | Address | A customer's address. | ناونیشان | High | Common interface wording — awaiting review |  |
| `addressHint` | e.g. Salim Street 12, Sulaymaniyah | Example in the address field. | بۆ نموونە شەقامی سالم 12، سلێمانی | High | Common interface wording — awaiting review |  |
| `appearanceDark` | Dark | Dark appearance. | تاریک | High | Common interface wording — awaiting review |  |
| `appearanceLight` | Light | Light appearance. | ڕووناک | High | Common interface wording — awaiting review |  |
| `appearanceSystem` | Match device | Follow the device's light or dark setting. | وەک ئامێرەکە | High | Common interface wording — awaiting review |  |
| `appTitle` | ProFrame | The application's name; a product name, not translated. | ProFrame | High | Common interface wording — awaiting review |  |
| `backToCustomer` | Back to Customer | After completing: go to the customer's page. | گەڕانەوە بۆ کڕیار | High | Common interface wording — awaiting review |  |
| `blurbAngled` | Sloped, under-stair & custom shapes | Choose your design: the angled card. | شێوەی لار، ژێر پەیژە و تایبەت | High | Common interface wording — awaiting review |  |
| `blurbBoth` | Doors and windows in one frame | Choose your design: the door and window card. | دەرگا و پەنجەرە لە یەک چوارچێوەدا | High | Common interface wording — awaiting review |  |
| `blurbDoor` | Create a custom door design | Choose your design: the door card. | دیزاینی دەرگایەکی تایبەت دروست بکە | High | Common interface wording — awaiting review |  |
| `blurbSliding` | Panels that slide past each other | Choose your design: the sliding card. | پانێڵەکان بەلای یەکتردا دەخزێن | High | Common interface wording — awaiting review |  |
| `blurbWindow` | Create a custom window design | Choose your design: the window card. | دیزاینی پەنجەرەیەکی تایبەت دروست بکە | High | Common interface wording — awaiting review |  |
| `bothPanelGlass` | Both Panel + Glass | Choice: some parts glass, some panel. | هەردووکیان پانێڵ + شووشە | High | Common interface wording — awaiting review |  |
| `bothPanelGlassDetail` | You choose which parts are glass and which are panel. | Detail of the choice. | تۆ هەڵدەبژێریت کام بەش شووشەیە و کامیان پانێڵ. | High | Common interface wording — awaiting review |  |
| `brandWordmark` | PROFRAME | The product's name in capitals over the customers' heading; a name, not translated. | PROFRAME | High | Common interface wording — awaiting review |  |
| `bulleted` | • {item} | An item in a list, with a bullet. | • {item} | High | Common interface wording — awaiting review |  |
| `cadCounts` | {sections} sections · {bars} bars · {openings} openings | Status bar. | {sections} بەش · {bars} دابەشکەر · {openings} بەشی کراوە | High | Common interface wording — awaiting review |  |
| `cadFit` | Fit the drawing to the view | Tooltip. | نەخشەکە لەگەڵ پیشاندانەکە بگونجێنە | High | Common interface wording — awaiting review |  |
| `cadInside` | Inside {what} — {size} | Caption of the tools inside an opening. | لە ناو {what} — ‎{size}‎ | High | Common interface wording — awaiting review |  |
| `cadNoteHint` | Type your note | Hint. | تێبینییەکەت بنووسە | High | Common interface wording — awaiting review |  |
| `cadNoteTitle` | Note | Title of the note dialog. | تێبینی | High | Common interface wording — awaiting review |  |
| `cadTapSomething` | Tap a line, a bar or a pane | Status bar. | دەست لە هێڵێک، دابەشکەرێک یان پارچەیەک بدە | High | Common interface wording — awaiting review |  |
| `cadThisOpening` | this opening | Caption: an opening with no mechanism. | ئەم بەشە کراوەیە | High | Common interface wording — awaiting review |  |
| `category` | Category | A design's category label. | جۆر | High | Common interface wording — awaiting review |  |
| `categoryStays` | The category stays with the design. | Why a design's category cannot be changed. | جۆرەکە لەگەڵ دیزاینەکەدا دەمێنێتەوە. | High | Common interface wording — awaiting review |  |
| `checkMany` | {count} things to check | Heading over the questions the reading raised. | {count} شت بۆ پشکنین | High | Common interface wording — awaiting review |  |
| `checkOne` | One thing to check | Heading over the questions the reading raised: one question. | یەک شت بۆ پشکنین | High | Common interface wording — awaiting review |  |
| `chooseTheGlass` | Choose the glass | Prompt in the material form. | شووشەکە هەڵبژێرە | High | Common interface wording — awaiting review |  |
| `chooseThePanelColour` | Choose the panel colour | Prompt in the material form. | ڕەنگی پانێڵەکە هەڵبژێرە | High | Common interface wording — awaiting review |  |
| `chooseTypeToContinue` | Choose a type to continue | Foot bar before a category is chosen. | جۆرێک هەڵبژێرە بۆ بەردەوامبوون | High | Common interface wording — awaiting review |  |
| `chooseYourDesign` | Choose your design | Title of the category choice. | دیزاینەکەت هەڵبژێرە | High | Common interface wording — awaiting review |  |
| `chooseYourDesignLine` | Select the type of product you want to create. | Under the category choice's title. | جۆری ئەو بەرهەمە هەڵبژێرە کە دەتەوێت دروستی بکەیت. | High | Common interface wording — awaiting review |  |
| `clearSearch` | Clear search | Tooltip: empty the search field. | سڕینەوەی گەڕان | High | Common interface wording — awaiting review |  |
| `completeButton` | Complete! | The button that completes and saves the design. | تەواوکردن! | High | Common interface wording — awaiting review |  |
| `completedAndSaved` | Completed and saved | Beside Complete!, once the design is completed. | تەواوکرا و پاشەکەوت کرا | High | Common interface wording — awaiting review |  |
| `completedSuccess` | Design completed and saved successfully. | After Complete! saved the design. | دیزاینەکە بە سەرکەوتوویی تەواوکرا و پاشەکەوت کرا. | High | Common interface wording — awaiting review |  |
| `completeNoPermission` | You do not have permission to complete designs. | Completing without permission. | مۆڵەتی تەواوکردنی دیزاینەکانت نییە. | High | Common interface wording — awaiting review |  |
| `copyMade` | Copy made: {name} | Notice after a design is duplicated. | لەبەرگیرایەوە: {name} | High | Common interface wording — awaiting review |  |
| `couldNotOpen` | {name} could not be opened. | A design that could not be opened. | {name} نەکرایەوە. | High | Common interface wording — awaiting review |  |
| `ctAsDrawn` | as drawn | A dimension as drawn. | وەک کێشراوە | High | Common interface wording — awaiting review |  |
| `ctBars` | Bars | Parts list group. | دابەشکەرەکان | High | Common interface wording — awaiting review |  |
| `ctDimensions` | Dimensions | Parts list group. | پێوانەکان | High | Common interface wording — awaiting review |  |
| `ctFromLeft` | {length} from the left | Where a hinge is. | ‎{length}‎ لە لای چەپەوە | High | Common interface wording — awaiting review |  |
| `ctHardware` | Hardware | Parts list group. | ئیکسسوار | High | Common interface wording — awaiting review |  |
| `ctHolds` | {size} · holds {count} | A section holding panes. | ‎{size}‎ · {count} لەخۆدەگرێت | High | Common interface wording — awaiting review |  |
| `ctInside` | {length} · inside | A bar inside a section. | ‎{length}‎ · لە ناوەوە | High | Common interface wording — awaiting review |  |
| `ctNotes` | Notes | Parts list group. | تێبینییەکان | High | Common interface wording — awaiting review |  |
| `ctNothingRead` | Nothing has been read from your drawing yet. | Parts list, empty. | هێشتا هیچ شتێک لە نەخشەکەت نەخوێندراوەتەوە. | High | Common interface wording — awaiting review |  |
| `ctOnOpening` | {place} · on the opening | Where a handle is. | {place} · لەسەر بەشە کراوەکە | High | Common interface wording — awaiting review |  |
| `ctSections` | Sections | Parts list group. | بەشەکان | High | Common interface wording — awaiting review |  |
| `ctTyped` | you typed this | A dimension the user stated. | تۆ نووسیوتە | High | Common interface wording — awaiting review |  |
| `ctUp` | {length} up | Where a hinge is. | ‎{length}‎ بۆ سەرەوە | High | Common interface wording — awaiting review |  |
| `customerDeleted` | {name} deleted. | Notice after a customer is deleted. | {name} سڕدرایەوە. | High | Common interface wording — awaiting review |  |
| `customerGone` | This customer is no longer kept. | A customer page whose customer has been removed. | ئەم کڕیارە ئیتر هەڵنەگیراوە. | High | Common interface wording — awaiting review |  |
| `customerInformation` | Customer information | Heading of a customer's details. | زانیاریی کڕیار | High | Common interface wording — awaiting review |  |
| `customersAll` | All Customers | Heading over the list of customers. | هەموو کڕیاران | High | Common interface wording — awaiting review |  |
| `customersEmptyLine` | Everyone you draw for is kept here. | Under the title when there are no customers. | هەموو ئەو کەسانەی بۆیان دیزاین دەکەیت لێرە هەڵدەگیرێن. | High | Common interface wording — awaiting review |  |
| `customersNoAccess` | You do not have permission to view customers. | Customers screen, for somebody not allowed to see them. | مۆڵەتی بینینی کڕیارانت نییە. | High | Common interface wording — awaiting review |  |
| `customersNoneYet` | No customers yet | Empty customers list heading. | هێشتا هیچ کڕیارێک نییە | High | Common interface wording — awaiting review |  |
| `customersNoneYetLine` | Add the people you draw for, and keep their designs together. | Empty customers list explanation. | ئەو کەسانە زیاد بکە کە بۆیان دیزاین دەکەیت، و دیزاینەکانیان پێکەوە هەڵبگرە. | High | Common interface wording — awaiting review |  |
| `customersResults` | Results | Heading over the customers a search found. | ئەنجامەکان | High | Common interface wording — awaiting review |  |
| `customersSearchHint` | Search by name or phone... | Hint in the customers' search field. | گەڕان بە ناو یان ژمارەی مۆبایل... | High | Common interface wording — awaiting review |  |
| `customersTitle` | Customers | The customers screen's title. | کڕیاران | High | Common interface wording — awaiting review |  |
| `dateAt` | {day} {month} {year}, {time} | When a design was last edited: a date and a time. | {day}ی {month}ی {year}، {time} | High | Common interface wording — awaiting review |  |
| `deleteCustomer` | Delete customer | Button and menu item: delete this customer. | سڕینەوەی کڕیار | High | Common interface wording — awaiting review |  |
| `deleteCustomerTitle` | Delete {name}? | Asked before a customer is deleted. | {name} بسڕدرێتەوە؟ | High | Common interface wording — awaiting review |  |
| `deleteDesign` | Delete design | Button: delete the design. | سڕینەوەی دیزاین | High | Common interface wording — awaiting review |  |
| `deleteDesignTitle` | Delete {name}? | Asked before a design is deleted. | {name} بسڕدرێتەوە؟ | High | Common interface wording — awaiting review |  |
| `designDeleted` | {name} deleted | Notice after a design is deleted. | {name} سڕدرایەوە | High | Common interface wording — awaiting review |  |
| `designName` | Design name | The design name field and its heading. | ناوی دیزاین | High | Common interface wording — awaiting review |  |
| `designNameHint` | e.g. Basement Door | Example in the design name field. | بۆ نموونە دەرگای ژێرزەمین | High | Common interface wording — awaiting review |  |
| `designNameNote` | The customer is who it is for; this is the name of the design itself. | Under the design name field. | کڕیار ئەو کەسەیە کە دیزاینەکە بۆی دەکرێت؛ ئەمە ناوی خودی دیزاینەکەیە. | High | Common interface wording — awaiting review |  |
| `designNameQuestion` | What is this design called? | Under the design name heading. | ناوی ئەم دیزاینە چییە؟ | High | Common interface wording — awaiting review |  |
| `designNotClosedTitle` | Design not closed | Title of the alert: the outline has a side missing. | دیزاینەکە دانەخراوە | High | Common interface wording — awaiting review |  |
| `designNumber` | #{number} | A design's short number. | #{number} | High | Common interface wording — awaiting review |  |
| `designsNoAccess` | You do not have permission to view designs. | For somebody not allowed to see designs. | مۆڵەتی بینینی دیزاینەکانت نییە. | High | Common interface wording — awaiting review |  |
| `designsTitle` | Designs | Heading of a customer's designs. | دیزاینەکان | High | Common interface wording — awaiting review |  |
| `discountFor` | Discount for {name} | Title of the discount dialog. | داشکاندن بۆ {name} | High | Common interface wording — awaiting review |  |
| `discountNoneChoice` | None | Choice: no discount. | هیچ | High | Common interface wording — awaiting review |  |
| `discountReason` | Reason (optional) | Field. | هۆکار (ئارەزوومەندانە) | High | Common interface wording — awaiting review |  |
| `discountRemove` | Remove discount | Button. | لابردنی داشکاندن | High | Common interface wording — awaiting review |  |
| `discountType` | Discount type | Label in the discount dialog. | جۆری داشکاندن | High | Common interface wording — awaiting review |  |
| `draftHint` | Draft — press Complete! when the design is finished | Beside Complete!, while the design is a draft. | ڕەشنووس — کاتێک دیزاینەکە تەواو بوو «تەواوکردن!» دابگرە | High | Common interface wording — awaiting review |  |
| `drawDivider` | Draw divider | Button: back to the drawing to draw a divider. | دابەشکەر بکێشە | High | Common interface wording — awaiting review |  |
| `drawDividerDetail` | Back to the drawing with a straight line. | Detail of the button. | گەڕانەوە بۆ نەخشەکە بە هێڵێکی ڕاست. | High | Common interface wording — awaiting review |  |
| `drawingOf` | Drawing of {name} | Screen reader: a design's picture. | نەخشەی {name} | High | Common interface wording — awaiting review |  |
| `duplicate` | Duplicate | Design actions sheet: make a copy. | لەبەرگرتنەوە | High | Common interface wording — awaiting review |  |
| `edit` | Edit | Button: edit. | دەستکاری | High | Common interface wording — awaiting review |  |
| `editCustomer` | Edit Customer | Title of the form editing a customer. | دەستکاریی کڕیار | High | Common interface wording — awaiting review |  |
| `editInformation` | Edit information | Button: change a design's name. | دەستکاریی زانیاری | High | Common interface wording — awaiting review |  |
| `everyPartChosen` | Every part is chosen. | All parts said glass or panel. | هەموو بەشەکان هەڵبژێردران. | High | Common interface wording — awaiting review |  |
| `fcActive` | Active | A colour's status. | چالاک | High | Common interface wording — awaiting review |  |
| `fcAdd` | Add colour | Button. | زیادکردنی ڕەنگ | High | Common interface wording — awaiting review |  |
| `fcAdded` | Colour added. | Notice. | ڕەنگەکە زیاد کرا. | High | Common interface wording — awaiting review |  |
| `fcAMetre` | A metre | Field: the rate a metre. | بۆ هەر مەترێک | High | Common interface wording — awaiting review |  |
| `fcCode` | Or its code | Field: the colour's hex code. | یان کۆدەکەی | High | Common interface wording — awaiting review |  |
| `fcColours` | COLOURS | Heading. | ڕەنگەکان | High | Common interface wording — awaiting review |  |
| `fcEdit` | Edit {name} | Tooltip. | دەستکاریکردنی {name} | High | Common interface wording — awaiting review |  |
| `fcName` | Colour name | Field. | ناوی ڕەنگ | High | Common interface wording — awaiting review |  |
| `fcNone` | No colours yet. Every colour is priced as any other colour. | Empty catalog. | هێشتا هیچ ڕەنگێک نییە. هەموو ڕەنگێک وەک "هەر ڕەنگێکی تر" نرخی بۆ دادەنرێت. | High | Common interface wording — awaiting review |  |
| `fcNotPriced` | {material} not priced | A colour's rate on a material, none set. | {material} نرخی بۆ دانەنراوە | High | Common interface wording — awaiting review |  |
| `fcOfferAgain` | Offer {name} again | Tooltip. | {name} دووبارە پێشکەش بکەرەوە | High | Common interface wording — awaiting review |  |
| `fcOfferedAgain` | {name} is offered again. | Notice. | {name} دووبارە پێشکەش دەکرێتەوە. | High | Common interface wording — awaiting review |  |
| `fcOnProfile` | On the profile | Field: the share of the profile's price. | لەسەر پرۆفایل | High | Common interface wording — awaiting review |  |
| `fcPerMetre` | {material} {amount}/m | A colour's rate a metre on a material. | {material} ‎{amount}‎/m | High | Common interface wording — awaiting review |  |
| `fcRetire` | Retire colour | Button. | خانەنشینکردنی ڕەنگ | High | Common interface wording — awaiting review |  |
| `fcRetireAsk` | Retire {name}? | Confirmation title: stop offering a colour. | {name} خانەنشین بکرێت؟ | High | Common interface wording — awaiting review |  |
| `fcRetired` | {name} retired. | Notice. | {name} خانەنشین کرا. | High | Common interface wording — awaiting review |  |
| `fcRetiredStatus` | Retired | A colour's status. | خانەنشین | High | Common interface wording — awaiting review |  |
| `fcRetireOf` | Retire {name} | Tooltip. | خانەنشینکردنی {name} | High | Common interface wording — awaiting review |  |
| `fcSave` | Save colour | Button. | پاشەکەوتکردنی ڕەنگ | High | Common interface wording — awaiting review |  |
| `fcSaved` | Colour saved. | Notice. | ڕەنگەکە پاشەکەوت کرا. | High | Common interface wording — awaiting review |  |
| `fcSoldIn` | Sold in, and what it adds | Label. | پێی دەفرۆشرێت، و ئەوەی زیادی دەکات | High | Common interface wording — awaiting review |  |
| `fcStandard` | Standard colour | Switch. | ڕەنگی ستاندارد | High | Common interface wording — awaiting review |  |
| `fcSwatch` | Swatch | Label. | نموونەی ڕەنگ | High | Common interface wording — awaiting review |  |
| `fillGlass` | Glass | What fills a part: glass. | شووشە | High | Common interface wording — awaiting review |  |
| `fillPanel` | Panel | What fills a part: panel. | پانێڵ | High | Common interface wording — awaiting review |  |
| `filterAll` | All | Filter chip: every category. | هەموو | High | Common interface wording — awaiting review |  |
| `finAddExtra` | Add extra | Button: add an extra charge. | زیادکردنی تێچوو | High | Common interface wording — awaiting review |  |
| `finAddPayment` | Add payment | Button: record a payment. | زیادکردنی پارەدان | High | Common interface wording — awaiting review |  |
| `finAmount` | Amount | Field. | بڕ | High | Common interface wording — awaiting review |  |
| `finAmountDue` | Amount due | Row: what is still owed. | بڕی ماوە | High | Common interface wording — awaiting review |  |
| `finAtRate` | At 1 {from} = {rate} {to}: {amount} | A payment converted at its rate. | بە ‎1 {from} = {rate} {to}‎: {amount} | High | Common interface wording — awaiting review |  |
| `finCurrency` | Currency | Field. | دراو | High | Common interface wording — awaiting review |  |
| `finCurrencyPayments` | {currency} payments | Row: payments in another currency. | پارەدانەکانی {currency} | High | Common interface wording — awaiting review |  |
| `finCurrencyRefunds` | {currency} refunds | Row: refunds in another currency. | گەڕاندنەوەکانی {currency} | High | Common interface wording — awaiting review |  |
| `finCustomerNotFinal` | Customer price is not final. {reason} | Why the customer's total is not final. | نرخی کڕیار کۆتایی نییە. {reason} | High | Common interface wording — awaiting review |  |
| `finDate` | Date | Field. | بەروار | High | Common interface wording — awaiting review |  |
| `finDay` | {day} {month} {year} | A date: day, short month, year. | {day}ی {month}ی {year} | High | Common interface wording — awaiting review |  |
| `finDescriptionHint` | Company cheque | Example description of another payment method. | چەکی کۆمپانیا | High | Common interface wording — awaiting review |  |
| `finDescriptionOptional` | Description (optional) | Field: describe another payment method. | وەسف (ئارەزوومەندانە) | High | Common interface wording — awaiting review |  |
| `finDesignFacts` | Category: {category} · Material: {material} · Colour: {colour} | What a design is and is made of. | جۆر: {category} · کەرەستە: {material} · ڕەنگ: {colour} | High | Common interface wording — awaiting review |  |
| `finDesigns` | Designs | Row: how many designs. | دیزاینەکان | High | Common interface wording — awaiting review |  |
| `finDesignsHeading` | DESIGNS | Heading over each design's price. | دیزاینەکان | High | Common interface wording — awaiting review |  |
| `finDesignsPriced` | {count} · {priced} priced | How many designs, and how many have a price. | {count} · {priced} نرخیان بۆ دانراوە | High | Common interface wording — awaiting review |  |
| `finDesignsTotal` | Designs total | Row: the designs' prices summed. | کۆی دیزاینەکان | High | Common interface wording — awaiting review |  |
| `finDiscount` | Discount | Button: give a discount. | داشکاندن | High | Common interface wording — awaiting review |  |
| `finDiscountOf` | Discount ({amount}) | Row: the discount in force. | داشکاندن (‎{amount}‎) | High | Common interface wording — awaiting review |  |
| `finDue` | Due {amount} | Glance: what is due. | ماوە ‎{amount}‎ | High | Common interface wording — awaiting review |  |
| `finExtrasHeading` | EXTRA CHARGES — WHOLE JOB | Heading over the customer's own extras. | تێچووە زیادەکان — هەموو کارەکە | High | Common interface wording — awaiting review |  |
| `finExtrasWholeJob` | Extra charges (whole job) | Row: the customer's own extras. | تێچووە زیادەکان (هەموو کارەکە) | High | Common interface wording — awaiting review |  |
| `finFinalTotal` | Final total | Row: the total after discount and extras. | کۆی کۆتایی | High | Common interface wording — awaiting review |  |
| `finHideDesigns` | Hide each design and the materials | Fold the summary. | هەر دیزاینێک و کەرەستەکان بشارەوە | High | Common interface wording — awaiting review |  |
| `finHistory` | PAYMENT HISTORY | Heading of the payment history. | مێژووی پارەدان | High | Common interface wording — awaiting review |  |
| `finLoadMore` | Load more ({count} more) | Button: show the next page. | زیاتر پیشان بدە ({count}ی تر) | High | Common interface wording — awaiting review |  |
| `finMaterialSummary` | CUSTOMER MATERIAL SUMMARY | Heading over the customer's measurements. | پوختەی کەرەستەی کڕیار | High | Common interface wording — awaiting review |  |
| `finNetPaid` | Net paid | Row: payments less refunds. | پارەی دراوی پوخت | High | Common interface wording — awaiting review |  |
| `finNoAccess` | You do not have permission to view this customer's finances. | Customer's finances, without permission. | مۆڵەتت نییە بۆ بینینی دارایی ئەم کڕیارە. | High | Common interface wording — awaiting review |  |
| `finNoHistory` | No payment history yet. | The history is empty. | هێشتا هیچ مێژوویەکی پارەدان نییە. | High | Common interface wording — awaiting review |  |
| `finNoQuotations` | No quotations yet. | There are no quotations. | هێشتا هیچ پێشنیارێکی نرخ نییە. | High | Common interface wording — awaiting review |  |
| `finNote` | Note | Field: a payment's note. | تێبینی | High | Common interface wording — awaiting review |  |
| `finNotFinal` | Not final | A total that is not final. | کۆتایی نییە | High | Common interface wording — awaiting review |  |
| `finNotFinalYet` | The total is not final yet: {reason} | In the payment dialog. | کۆی گشتی هێشتا کۆتایی نییە: {reason} | High | Common interface wording — awaiting review |  |
| `finOfPriced` | Of the {priced} of {count} designs with a current price. | Under the material summary. | لە {priced} دیزاین لە کۆی {count} کە نرخی ئێستایان هەیە. | High | Common interface wording — awaiting review |  |
| `finOtherCurrencies` | OTHER CURRENCIES — not included in the {currency} total | Heading over money in other currencies. | دراوی تر — لە کۆی {currency} نەژمێردراوە | High | Common interface wording — awaiting review |  |
| `finPaymentFrom` | Payment from {name} | Title of the payment dialog. | پارەدان لە {name}ەوە | High | Common interface wording — awaiting review |  |
| `finPaymentMethod` | Payment method | Field. | شێوازی پارەدان | High | Common interface wording — awaiting review |  |
| `finPricedSoFar` | Priced so far (not the total) | Row: what is priced so far. | ئەوەی تا ئێستا نرخی بۆ دانراوە (کۆی گشتی نییە) | High | Common interface wording — awaiting review |  |
| `finQuotations` | QUOTATIONS | Heading over the quotations. | پێشنیارەکانی نرخ | High | Common interface wording — awaiting review |  |
| `finRateOptional` | Exchange rate (optional) | Field. | نرخی گۆڕینەوە (ئارەزوومەندانە) | High | Common interface wording — awaiting review |  |
| `finReasonNote` | Reason / note | Field: a refund's note. | هۆکار / تێبینی | High | Common interface wording — awaiting review |  |
| `finRefund` | Refund | Button: record a refund. | گەڕاندنەوەی پارە | High | Common interface wording — awaiting review |  |
| `finRefundAmount` | Refund amount | Field. | بڕی گەڕاندنەوە | High | Common interface wording — awaiting review |  |
| `finRefundMethod` | Refund method | Field. | شێوازی گەڕاندنەوە | High | Common interface wording — awaiting review |  |
| `finRefunds` | Refunds | Row: every refund. | گەڕاندنەوەکان | High | Common interface wording — awaiting review |  |
| `finRefundTo` | Refund to {name} | Title of the refund dialog. | گەڕاندنەوەی پارە بۆ {name} | High | Common interface wording — awaiting review |  |
| `finSavePayment` | Save payment | Button. | پاشەکەوتکردنی پارەدان | High | Common interface wording — awaiting review |  |
| `finSaveRefund` | Save refund | Button. | پاشەکەوتکردنی گەڕاندنەوە | High | Common interface wording — awaiting review |  |
| `finShowDesigns` | Show each design and the materials | Unfold the summary. | هەر دیزاینێک و کەرەستەکان پیشان بدە | High | Common interface wording — awaiting review |  |
| `finSubtotal` | Subtotal | Row: before the discount. | کۆی بەرایی | High | Common interface wording — awaiting review |  |
| `finSummary` | FINANCIAL SUMMARY | Heading of the customer's money. | پوختەی دارایی | High | Common interface wording — awaiting review |  |
| `finTotalDue` | {label}: {total} · due {due} | In the payment dialog. | {label}: ‎{total}‎ · ماوە ‎{due}‎ | High | Common interface wording — awaiting review |  |
| `finTotalPayments` | Total payments | Row: every payment. | کۆی پارەدانەکان | High | Common interface wording — awaiting review |  |
| `finTotalPrice` | Total price | Row: the total price. | کۆی نرخ | High | Common interface wording — awaiting review |  |
| `finWhenFinal` | when the total is final | A discount that cannot be worked out yet. | کاتێک کۆی گشتی کۆتایی دێت | High | Common interface wording — awaiting review |  |
| `finWholeJob` | {name}'s whole job | Where a customer's extra charge belongs. | هەموو کارەکەی {name} | High | Common interface wording — awaiting review |  |
| `finWholeJobOf` | {name}'s whole job — no one design's | Where a customer's extra charge belongs. | هەموو کارەکەی {name} — نەک هی یەک دیزاین | High | Common interface wording — awaiting review |  |
| `forCustomer` | for {customer} | Who a design is for. | بۆ {customer} | High | Common interface wording — awaiting review |  |
| `foundOf` | {found} of {count} | How many designs a search or filter shows, of all. | {found} لە {count} | High | Common interface wording — awaiting review |  |
| `fpKeep` | Keep prices | Button. | هەڵگرتنی نرخەکان | High | Common interface wording — awaiting review |  |
| `fpKept` | Prices kept. Every design priced before is now to be recalculated. | Notice. | نرخەکان هەڵگیران. هەموو دیزاینێک کە پێشتر نرخی بۆ دانرابوو ئێستا دەبێت دووبارە هەژمار بکرێتەوە. | High | Common interface wording — awaiting review |  |
| `fpLock` | Lock | Button. | قفڵکردن | High | Common interface wording — awaiting review |  |
| `fpNotPriced` | not priced | Hint in an empty optional figure. | نرخی بۆ دانەنراوە | High | Common interface wording — awaiting review |  |
| `fpOnlyOwner` | Only the workshop owner can change prices. | Card. | تەنها خاوەنی کارگە دەتوانێت نرخەکان بگۆڕێت. | High | Common interface wording — awaiting review |  |
| `fpTitle` | Factory prices | Title. | نرخەکانی کارگە | High | Common interface wording — awaiting review |  |
| `fpUnlock` | Unlock as owner | Button. | کردنەوە وەک خاوەن | High | Common interface wording — awaiting review |  |
| `gcError` | Error | Severity of a geometry problem: it cannot be built as drawn. | هەڵە | High | Common interface wording — awaiting review |  |
| `gcFewerDetails` | Fewer details | Screen reader: fold the geometry check. | وردەکاری کەمتر | High | Common interface wording — awaiting review |  |
| `gcMore` | {message}  +{count} more | A geometry problem, and how many more there are. | {message}  +{count} ی تر | High | Common interface wording — awaiting review |  |
| `gcMoreDetails` | More details | Screen reader: unfold the geometry check. | وردەکاری زیاتر | High | Common interface wording — awaiting review |  |
| `gcWarning` | Warning | Severity of a geometry problem: it may not be what was meant. | ئاگاداری | High | Common interface wording — awaiting review |  |
| `glassOrPanelTitle` | Glass or panel | Title of the alert asking what a door is built of. | شووشە یان پانێڵ | High | Common interface wording — awaiting review |  |
| `inAddHardware` | Add hardware here | Label on a section's panel. | ئیکسسوار لێرە زیاد بکە | High | Common interface wording — awaiting review |  |
| `inAllSizes` | All sizes | Button: open the sizes form, every size given. | هەموو قەبارەکان | High | Common interface wording — awaiting review |  |
| `inAngle` | Angle | Field: an angle. | گۆشە | High | Common interface wording — awaiting review |  |
| `inArrow` | Arrow | Readout heading for an arrow. | تیر | High | Common interface wording — awaiting review |  |
| `inAsDrawn` | As drawn | Readout: a dimension as drawn. | وەک کێشراوە | High | Common interface wording — awaiting review |  |
| `inAutomatic` | Automatic, by sensor | Switch: an automatic sliding panel. | ئۆتۆماتیکی، بە هەستەوەر | High | Common interface wording — awaiting review |  |
| `inBars` | Bars | Readout: how many bars. | دابەشکەرەکان | High | Common interface wording — awaiting review |  |
| `inBarWidth` | Bar width | Field: a bar's width. | پانی دابەشکەر | High | Common interface wording — awaiting review |  |
| `inCategory` | in {category} | A filter by category. | لە {category} | High | Common interface wording — awaiting review |  |
| `inColour` | Colour | Label: a part's colour. | ڕەنگ | High | Common interface wording — awaiting review |  |
| `inDeleteArrow` | Delete this arrow | Button on an arrow's panel. | ئەم تیرە بسڕەوە | High | Common interface wording — awaiting review |  |
| `inDeleteBar` | Delete this bar | Button on a bar's panel. | ئەم دابەشکەرە بسڕەوە | High | Common interface wording — awaiting review |  |
| `inDeleteDimension` | Delete this dimension | Button on a dimension's panel. | ئەم پێوانەیە بسڕەوە | High | Common interface wording — awaiting review |  |
| `inDeleteNote` | Delete this note | Button on a note's panel. | ئەم تێبینییە بسڕەوە | High | Common interface wording — awaiting review |  |
| `inDepth` | Depth | Field: the design's depth. | قووڵی | High | Common interface wording — awaiting review |  |
| `inDesign` | Design | Heading of the design's own panel, when nothing is picked. | دیزاین | High | Common interface wording — awaiting review |  |
| `inDirection` | Direction | Label: which way the leaf opens. | ئاراستە | High | Common interface wording — awaiting review |  |
| `inDivides` | Divides | Label: what a bar divides. | دابەش دەکات | High | Common interface wording — awaiting review |  |
| `inDoesNotOpen` | This section does not open | Button: make the opening fixed. | ئەم بەشە ناکرێتەوە | High | Common interface wording — awaiting review |  |
| `inDragToMove` | Drag it to move it. | Readout for an arrow. | ڕایبکێشە بۆ جوڵاندنی. | High | Common interface wording — awaiting review |  |
| `inDrewChanged` | You drew {drawn} here. You have since changed it to {now}. | Under the direction: the mark drawn and the one now. | لێرە {drawn}ت کێشا. دواتر گۆڕیوتە بۆ {now}. | High | Common interface wording — awaiting review |  |
| `inEditOpening` | Edit this opening | Button on a section's panel. | دەستکاری ئەم بەشە کراوەیە بکە | High | Common interface wording — awaiting review |  |
| `inEnterSizes` | Enter the sizes | Button: open the sizes form. | قەبارەکان بنووسە | High | Common interface wording — awaiting review |  |
| `inErase` | Erase | Tool inside an opening. | سڕینەوە | High | Common interface wording — awaiting review |  |
| `inFirstHinge` | First hinge from the top | Field: where the first hinge is. | یەکەم لولاو لە سەرەوە | High | Common interface wording — awaiting review |  |
| `inFrameProfile` | Frame profile | Field: the frame's border width. | پرۆفایلی چوارچێوە | High | Common interface wording — awaiting review |  |
| `inFrom` | From | Readout: where a side starts. | لە | High | Common interface wording — awaiting review |  |
| `inFromLeft` | From the left | Field: a distance from the left. | لە لای چەپەوە | High | Common interface wording — awaiting review |  |
| `inFromLeftOfOpening` | From the left of the opening | Field: a bar's place inside an opening. | لە لای چەپی بەشە کراوەکەوە | High | Common interface wording — awaiting review |  |
| `inFromRight` | From the right | Field: a distance from the right. | لە لای ڕاستەوە | High | Common interface wording — awaiting review |  |
| `inFromTopOfOpening` | From the top of the opening | Field: a bar's place inside an opening. | لە سەرەوەی بەشە کراوەکەوە | High | Common interface wording — awaiting review |  |
| `inHandleBar` | Bar | Handle form: a long pull bar for a sliding panel. | دەسکی درێژ | High | Common interface wording — awaiting review |  |
| `inHandleType` | Handle type | Label over the handle's form. | جۆری دەسک | High | Common interface wording — awaiting review |  |
| `inHeight` | Height | Field: a height. | بەرزی | High | Common interface wording — awaiting review |  |
| `inHeightFromBottom` | Height from the bottom | Field: the handle's height. | بەرزی لە خوارەوە | High | Common interface wording — awaiting review |  |
| `inHingeCount` | Number of hinges | Label over the hinge count. | ژمارەی لولاوەکان | High | Common interface wording — awaiting review |  |
| `inHorizontalLine` | Horizontal line | Tool inside an opening. | هێڵی ئاسۆیی | High | Common interface wording — awaiting review |  |
| `inHowItOpens` | How it opens | Label: the opening's mechanism. | چۆن دەکرێتەوە | High | Common interface wording — awaiting review |  |
| `inInsideOpening` | Inside the opening — {section} | Choice: the bar divides an opening. | لە ناو بەشە کراوەکە — {section} | High | Common interface wording — awaiting review |  |
| `inInsideSection` | Inside {section} | Choice: the bar divides a section. | لە ناو {section} | High | Common interface wording — awaiting review |  |
| `inIntoOpening` | Into the opening, square to this bar | Field: a diagonal bar's place inside an opening. | بەرەو ناو بەشە کراوەکە، بە ستوونی لەسەر ئەم دابەشکەرە | High | Common interface wording — awaiting review |  |
| `inInward` | Inward | The leaf opens inward. | بەرەو ناوەوە | High | Common interface wording — awaiting review |  |
| `inLastHinge` | Last hinge from the bottom | Field: where the last hinge is. | دوایین لولاو لە خوارەوە | High | Common interface wording — awaiting review |  |
| `inLength` | Length | Field: a length. | درێژی | High | Common interface wording — awaiting review |  |
| `inLineDividesDesign` | This line divides the design itself. | Under the Divides choice. | ئەم هێڵە خودی دیزاینەکە دابەش دەکات. | High | Common interface wording — awaiting review |  |
| `inMarkedWith` | You marked this section with a {drawn}. | Under the direction: the mark drawn. | ئەم بەشەت بە {drawn} نیشانە کرد. | High | Common interface wording — awaiting review |  |
| `inMaterial` | Material | Label: a part's material. | کەرەستە | High | Common interface wording — awaiting review |  |
| `inMeasuredInSection` | Measured inside the section this bar divides. | Help under a bar's place. | لە ناو ئەو بەشەدا دەپێورێت کە ئەم دابەشکەرە دابەشی دەکات. | High | Common interface wording — awaiting review |  |
| `inNote` | Note | Readout: a note's text. | تێبینی | High | Common interface wording — awaiting review |  |
| `inOpenings` | Openings | Readout: how many openings. | بەشە کراوەکان | High | Common interface wording — awaiting review |  |
| `inOpeningType` | Opening type | Label: door or window. | جۆری بەشی کراوە | High | Common interface wording — awaiting review |  |
| `inOpeningTypes` | Opening types | Heading over each opening's door or window switch. | جۆری بەشە کراوەکان | High | Common interface wording — awaiting review |  |
| `inOpens` | Opens | Label: whether a section opens. | دەکرێتەوە | High | Common interface wording — awaiting review |  |
| `inOpensAs` | Opens {how} | Button: the diagonal's pane opens this way. | دەکرێتەوە {how} | High | Common interface wording — awaiting review |  |
| `inOutward` | Outward | The leaf opens outward. | بەرەو دەرەوە | High | Common interface wording — awaiting review |  |
| `inOverallHeight` | Overall height | Field: the design's overall height. | بەرزی گشتی | High | Common interface wording — awaiting review |  |
| `inOverallWidth` | Overall width | Field: the design's overall width. | پانی گشتی | High | Common interface wording — awaiting review |  |
| `inOverallWidthHelp` | The width alone: the height stays as it is. | Help under the overall width. | تەنها پانی: بەرزی وەک خۆی دەمێنێتەوە. | High | Common interface wording — awaiting review |  |
| `inPaneInside` | This pane is inside the opening, so it moves and swings with it. | Under a pane's place inside an opening. | ئەم پارچەیە لە ناو بەشە کراوەکەدایە، بۆیە لەگەڵیدا دەجوڵێت و دەسووڕێتەوە. | High | Common interface wording — awaiting review |  |
| `inPickedWrong` | Picked the wrong one? Change it here. | Under the opening types. | هەڵەت هەڵبژارد؟ لێرە بیگۆڕە. | High | Common interface wording — awaiting review |  |
| `inPosition` | Position | Field: where something is. | شوێن | High | Common interface wording — awaiting review |  |
| `inRealSize` | Real size | Field: a dimension's true measurement. | قەبارەی ڕاستەقینە | High | Common interface wording — awaiting review |  |
| `inRemovePiece` | Remove this {piece} | Button on a piece of hardware's panel. | ئەم {piece}ـە لاببە | High | Common interface wording — awaiting review |  |
| `inRise` | Rise | Readout: how far a slope climbs. | بەرزبوونەوە | High | Common interface wording — awaiting review |  |
| `inRun` | Run | Readout: how far across a slope goes. | ڕۆیشتن | High | Common interface wording — awaiting review |  |
| `inSections` | Sections | Readout: how many sections. | بەشەکان | High | Common interface wording — awaiting review |  |
| `inTapAnyPart` | Tap any part of the drawing to change it. | Under the design's own panel heading. | دەست لە هەر بەشێکی نەخشەکە بدە بۆ گۆڕینی. | High | Common interface wording — awaiting review |  |
| `inTheOpeningIs` | The opening is | Readout: the opening's size. | بەشە کراوەکە | High | Common interface wording — awaiting review |  |
| `inThisDiagonal` | This diagonal | Heading on a diagonal bar's panel. | ئەم هێڵە لارە | High | Common interface wording — awaiting review |  |
| `inTo` | To | Readout: where a side ends. | بۆ | High | Common interface wording — awaiting review |  |
| `inVerticalLine` | Vertical line | Tool inside an opening. | هێڵی ستوونی | High | Common interface wording — awaiting review |  |
| `inWholeDesign` | The whole design | Choice: the bar divides the whole design. | هەموو دیزاینەکە | High | Common interface wording — awaiting review |  |
| `inWidth` | Width | Field: a width. | پانی | High | Common interface wording — awaiting review |  |
| `kindSelected` | {kind} selected | Foot bar once a category is chosen. | {kind} هەڵبژێردرا | High | Common interface wording — awaiting review |  |
| `labelColour` | Colour | Label: the profile's colour. | ڕەنگ | High | Common interface wording — awaiting review |  |
| `labelled` | {label}:  | A label followed by its value. | {label}:  | High | Common interface wording; Begins or ends with a space, which the application keeps — awaiting review |  |
| `labelMaterial` | Material | Label: what the profile is made of. | کەرەستە | High | Common interface wording — awaiting review |  |
| `lastEdited` | Last edited: {when} | When a design was last edited. | دوایین دەستکاری: {when} | High | Common interface wording — awaiting review |  |
| `layCentreLines` | Centre lines | Layer. | هێڵە ناوەندییەکان | High | Common interface wording — awaiting review |  |
| `layDimensions` | Dimensions | Layer. | پێوانەکان | High | Common interface wording — awaiting review |  |
| `layFit` | Fit | Button. | گونجاندن | High | Common interface wording — awaiting review |  |
| `layGrid` | Grid | Layer. | تۆڕ | High | Common interface wording — awaiting review |  |
| `layHidden` | Hidden | Layer: hidden detail. | شاراوە | High | Common interface wording — awaiting review |  |
| `layMyDrawing` | My drawing | Layer. | نەخشەکەم | High | Common interface wording — awaiting review |  |
| `layNotes` | Notes | Layer. | تێبینییەکان | High | Common interface wording — awaiting review |  |
| `layOpenings` | Openings | Layer. | بەشە کراوەکان | High | Common interface wording — awaiting review |  |
| `mdBack` | Back | Named view. | دواوە | High | Common interface wording — awaiting review |  |
| `mdBothDesign` | Both are the design. The drawing changes with them. | Under depth and profile. | هەردووکیان دیزاینەکەن. نەخشەکەش لەگەڵیان دەگۆڕێت. | High | Common interface wording — awaiting review |  |
| `mdBottom` | Bottom | Named view. | خوارەوە | High | Common interface wording — awaiting review |  |
| `mdCamera` | yaw {yaw}°  pitch {pitch}°  ×{zoom} | Camera readout. | سووڕانەوە {yaw}°  لاری {pitch}°  ×‎{zoom}‎ | High | Common interface wording — awaiting review |  |
| `mdCounts` | {sections} sections · {bars} bars | Readout. | {sections} بەش · {bars} دابەشکەر | High | Common interface wording — awaiting review |  |
| `mdDepth` | Depth | Field. | قووڵی | High | Common interface wording — awaiting review |  |
| `mdFit` | Fit the model to the view | Tooltip. | مۆدێلەکە لەگەڵ پیشاندانەکە بگونجێنە | High | Common interface wording — awaiting review |  |
| `mdFront` | Front | Named view. | پێشەوە | High | Common interface wording — awaiting review |  |
| `mdGround` | Ground plane | Tooltip. | زەوی | High | Common interface wording — awaiting review |  |
| `mdLeft` | Left | Named view. | چەپ | High | Common interface wording — awaiting review |  |
| `mdNothing` | Nothing to show yet | Model with nothing drawn. | هێشتا هیچ شتێک نییە بۆ پیشاندان | High | Common interface wording — awaiting review |  |
| `mdOpen` | Open | Slider: how open the leaves are. | کردنەوە | High | Common interface wording — awaiting review |  |
| `mdPlay` | Open, pause and close | Tooltip: play the leaves. | کردنەوە، ڕاوەستان و داخستن | High | Common interface wording — awaiting review |  |
| `mdProfile` | Profile | Field. | پرۆفایل | High | Common interface wording — awaiting review |  |
| `mdRight` | Right | Named view. | ڕاست | High | Common interface wording — awaiting review |  |
| `mdTop` | Top | Named view. | سەرەوە | High | Common interface wording — awaiting review |  |
| `mdViewOf` | {name} view | Tooltip of a named view. | پیشاندانی {name} | High | Common interface wording — awaiting review |  |
| `mfAllGiven` | Every size is given. | Sizes form. | هەموو قەبارەکان دراون. | High | Common interface wording — awaiting review |  |
| `mfFromOthers` | from the others | A size worked out from the rest. | لە ئەوانی ترەوە | High | Common interface wording — awaiting review |  |
| `mfTitle` | Measurements | Title of the sizes form. | پێوانەکان | High | Common interface wording — awaiting review |  |
| `moreOptions` | More options | Tooltip of the three-dot menu. | هەڵبژاردەی زیاتر | High | Common interface wording — awaiting review |  |
| `mtReadFirst` | Read your drawing first: its parts are what glass or panel goes into. | Material form. | سەرەتا نەخشەکەت بخوێنەرەوە: بەشەکانی ئەو شوێنانەن کە شووشە یان پانێڵ دەچنە ناویانەوە. | High | Common interface wording — awaiting review |  |
| `mtTitle` | Material | Title of the material form. | کەرەستە | High | Common interface wording — awaiting review |  |
| `name` | Name | A customer's name field. | ناو | High | Common interface wording — awaiting review |  |
| `nameHint` | e.g. Adam | Example in the customer's name field. | بۆ نموونە ئادەم | High | Common interface wording — awaiting review |  |
| `newCustomer` | New Customer | Button: add a customer. | کڕیاری نوێ | High | Common interface wording — awaiting review |  |
| `newCustomerLine` | Who are you drawing for? Their designs are kept together under them. | Under the title of the form making a customer. | بۆ کێ دیزاین دەکەیت؟ دیزاینەکانیان پێکەوە لەژێر ناوی ئەواندا هەڵدەگیرێن. | High | Common interface wording — awaiting review |  |
| `newDesign` | New Design | Button: begin a new design. | دیزاینی نوێ | High | Common interface wording — awaiting review |  |
| `noDesignsMatchHint` | Search by the design's name, or choose another category. | Under a search that found nothing. | بە ناوی دیزاینەکە بگەڕێ، یان جۆرێکی تر هەڵبژێرە. | High | Common interface wording — awaiting review |  |
| `noDesignsYet` | No designs yet | A customer with no designs. | هێشتا هیچ دیزاینێک نییە | High | Common interface wording — awaiting review |  |
| `noPhoneNumber` | No phone number | A customer card with no phone number. | ژمارەی مۆبایل نییە | High | Common interface wording — awaiting review |  |
| `normalizedMessage` | Geometry normalized for standard design. | Brief note after lines drawn a little out of square were straightened. | شێوەکاری بۆ دیزاینی ستاندارد ڕێکخرا. | High | Common interface wording — awaiting review |  |
| `notCompleted` | Not completed | Heading when completing failed. | تەواو نەکرا | High | Common interface wording — awaiting review |  |
| `notCompleteYet` | Not complete yet | Heading when the design is incomplete. | هێشتا تەواو نییە | High | Common interface wording — awaiting review |  |
| `notDeleted` | Not deleted | Heading when a customer could not be deleted. | نەسڕدرایەوە | High | Common interface wording — awaiting review |  |
| `notes` | Notes | Notes about a customer. | تێبینییەکان | High | Common interface wording — awaiting review |  |
| `notesHint` | Anything to remember about them | Hint in the notes field. | هەر شتێک کە دەبێت لەبارەیانەوە لەبیرت بێت | High | Common interface wording — awaiting review |  |
| `notGiven` | Not given | A customer detail left empty. | نەدراوە | High | Common interface wording — awaiting review |  |
| `nothingDrawnYet` | Nothing drawn yet | A design card with nothing drawn. | هێشتا هیچ شتێک نەکێشراوە | High | Common interface wording — awaiting review |  |
| `oneOfMany` | 1 of {count} | How many questions are left, the one shown being the first. | 1 لە {count} | High | Common interface wording — awaiting review |  |
| `open` | Open | Button: open a design. | کردنەوە | High | Common interface wording — awaiting review |  |
| `openingTypeTitle` | Opening type | Title of the alert asking whether an opening is a door or a window. | جۆری بەشی کراوە | High | Common interface wording — awaiting review |  |
| `optionalField` |   optional | After the label of a field that may be left empty (with its leading spaces). |   ئارەزوومەندانە | High | Common interface wording; Begins or ends with a space, which the application keeps — awaiting review |  |
| `paBreakdown` | COST BREAKDOWN | Heading. | وردەکاری تێچوو | High | Common interface wording — awaiting review |  |
| `paCalculate` | Calculate price | Button. | هەژمارکردنی نرخ | High | Common interface wording — awaiting review |  |
| `paCannot` | This design cannot be priced as it is. | Price sheet. | ئەم دیزاینە وەک خۆی نرخی بۆ دانانرێت. | High | Common interface wording — awaiting review |  |
| `paCategory` | Category: {category} | On the price sheet. | جۆر: {category} | High | Common interface wording — awaiting review |  |
| `paDesignAlone` | Off this design alone: its cost and its extras together. | Caption. | تەنها لەسەر ئەم دیزاینە: تێچووەکەی و تێچووە زیادەکانی پێکەوە. | High | Common interface wording — awaiting review |  |
| `paDesignPrice` | DESIGN PRICE | Heading. | نرخی دیزاین | High | Common interface wording — awaiting review |  |
| `paDiscountOn` | Discount on {name} | Title. | داشکاندن لەسەر {name} | High | Common interface wording — awaiting review |  |
| `paFinalTotal` | FINAL TOTAL | Heading. | کۆی کۆتایی | High | Common interface wording — awaiting review |  |
| `paMeasurements` | MATERIAL MEASUREMENTS | Heading. | پێوانەکانی کەرەستە | High | Common interface wording — awaiting review |  |
| `panelColour` | Panel colour | Label over the panel's colours. | ڕەنگی پانێڵ | High | Common interface wording — awaiting review |  |
| `paNotAllowed` | You do not have permission to view prices. | Price button, no permission. | مۆڵەتت نییە بۆ بینینی نرخەکان. | High | Common interface wording — awaiting review |  |
| `paThisDesign` | this design | Where an extra is removed from. | ئەم دیزاینە | High | Common interface wording — awaiting review |  |
| `paWorkingOut` | The price is still being worked out. | Price button. | نرخەکە هێشتا هەژمار دەکرێت. | High | Common interface wording — awaiting review |  |
| `pbAutomatic` | AUTOMATIC DESIGN COSTS | Heading of the breakdown. | تێچووە خۆکارەکانی دیزاین | High | Common interface wording — awaiting review |  |
| `pbChange` | Change | Button: change the discount. | گۆڕین | High | Common interface wording — awaiting review |  |
| `pbCombinedProfile` | Combined profile cost | Row. | کۆی تێچووی پرۆفایل | High | Common interface wording — awaiting review |  |
| `pbDesignCost` | Design cost | Row. | تێچووی دیزاین | High | Common interface wording — awaiting review |  |
| `pbExtras` | EXTRA CHARGES | Heading. | تێچووە زیادەکان | High | Common interface wording — awaiting review |  |
| `pbExtrasCost` | Extras cost | Row. | تێچووی زیادەکان | High | Common interface wording — awaiting review |  |
| `pbGive` | Give | Button: give a discount. | بدە | High | Common interface wording — awaiting review |  |
| `pbNoExtras` | No extra charges. | No extras. | هیچ تێچوویەکی زیادە نییە. | High | Common interface wording — awaiting review |  |
| `pbNotUsed` | Not used | Glass or panel that the design does not have. | بەکارنەهاتووە | High | Common interface wording — awaiting review |  |
| `pcColour` | Colour | Field. | ڕەنگ | High | Common interface wording — awaiting review |  |
| `pcMaterial` | Material | Field. | کەرەستە | High | Common interface wording — awaiting review |  |
| `pcRetired` | Retired: no longer offered for new designs. | Under the colour. | خانەنشین: ئیتر بۆ دیزاینی نوێ پێشکەش ناکرێت. | High | Common interface wording — awaiting review |  |
| `pcSpecial` | {name} (special) | A colour the catalog does not name. | {name} (تایبەت) | High | Common interface wording — awaiting review |  |
| `personCustomer` | Person / Customer | The field for who a new design is for. | کەس / کڕیار | High | Common interface wording — awaiting review |  |
| `personHint` | e.g. Ahmed | Example in the person field. | بۆ نموونە ئەحمەد | High | Common interface wording — awaiting review |  |
| `phone` | Phone | A customer's phone number. | مۆبایل | High | Common interface wording — awaiting review |  |
| `phoneHint` | e.g. +964 750 123 4567 | Example in the phone field. | بۆ نموونە +964 750 123 4567 | High | Common interface wording — awaiting review |  |
| `phoneNumber` | Phone number | A customer's phone number field. | ژمارەی مۆبایل | High | Common interface wording — awaiting review |  |
| `pinAgain` | The PIN again | Field. | دووبارەی PIN | High | Common interface wording — awaiting review |  |
| `pinAlreadySet` | An owner PIN is already set. | PIN check. | PINی خاوەن پێشتر دانراوە. | High | Common interface wording — awaiting review |  |
| `pinEnterOwner` | Enter the owner PIN. | Note. | PINی خاوەن بنووسە. | High | Common interface wording — awaiting review |  |
| `pinNotSame` | The two PINs are not the same. | PIN check. | هەردوو PINەکە وەک یەک نین. | High | Common interface wording — awaiting review |  |
| `pinOwner` | Owner PIN | Field. | PINی خاوەن | High | Common interface wording — awaiting review |  |
| `pinSet` | Set PIN | Button. | دانانی PIN | High | Common interface wording — awaiting review |  |
| `pinSetTitle` | Set the owner PIN | Title. | دانانی PINی خاوەن | High | Common interface wording — awaiting review |  |
| `pinUnlock` | Unlock | Button. | کردنەوە | High | Common interface wording — awaiting review |  |
| `pinWrong` | That is not the owner PIN. | PIN check. | ئەوە PINی خاوەن نییە. | High | Common interface wording — awaiting review |  |
| `poAsDesign` | As the design | A part following the design's profile. | وەک دیزاینەکە | High | Common interface wording — awaiting review |  |
| `poAsDesignOf` | As the design ({category}) | A part following the design's profile. | وەک دیزاینەکە ({category}) | High | Common interface wording — awaiting review |  |
| `poChooseProfile` | Choose the profile the factory makes it in. | Helper. | ئەو پرۆفایلە هەڵبژێرە کە کارگە پێی دروستی دەکات. | High | Common interface wording — awaiting review |  |
| `poEachPart` | Set each part | Button. | هەر بەشێک دیاری بکە | High | Common interface wording — awaiting review |  |
| `poGlassCharged` | Glass is charged by its measured area. | Note. | نرخی شووشە بەپێی ڕووبەری پێوراوی وەردەگیرێت. | High | Common interface wording — awaiting review |  |
| `poGlassMeasured` | Glass is not included: its area is measured and not charged. | Note. | شووشە لەخۆنەگیراوە: ڕووبەرەکەی دەپێورێت بەڵام نرخی لێ وەرناگیرێت. | High | Common interface wording — awaiting review |  |
| `poGlassOff` | Glass is not included. | Note. | شووشە لەخۆنەگیراوە. | High | Common interface wording — awaiting review |  |
| `poHideParts` | Hide the parts | Button. | بەشەکان بشارەوە | High | Common interface wording — awaiting review |  |
| `poIncludeGlass` | Include glass in price | Switch. | شووشە بخەرە ناو نرخەوە | High | Common interface wording — awaiting review |  |
| `poNoGlass` | There is no measurable glass to price. | Note. | هیچ شووشەیەکی پێوراو نییە بۆ نرخدانان. | High | Common interface wording — awaiting review |  |
| `poProfileOf` | {material} profile | Field. | پرۆفایلی {material} | High | Common interface wording — awaiting review |  |
| `poSomeOwn` | Some parts are set on their own below. | Helper. | هەندێک بەش لە خوارەوە بە جیا دیاری کراون. | High | Common interface wording — awaiting review |  |
| `ppBorderAndLines` | Border and internal lines | Measurement. | لێوار و هێڵە ناوەکییەکان | High | Common interface wording — awaiting review |  |
| `ppBorderLength` | Border length | Measurement. | درێژی لێوار | High | Common interface wording — awaiting review |  |
| `ppCarriedOver` | Prices carried over from an older price list. | Under a price from a migrated list. | نرخەکان لە لیستێکی نرخی کۆنترەوە گوازراونەتەوە. | High | Common interface wording — awaiting review |  |
| `ppCombinedLength` | Combined profile length | Measurement. | کۆی درێژی پرۆفایل | High | Common interface wording — awaiting review |  |
| `ppExamplePrices` | Example prices — the workshop owner sets the real ones. | Under a price from the example list. | نرخی نموونە — خاوەنی کارگە نرخە ڕاستەقینەکان دادەنێت. | High | Common interface wording — awaiting review |  |
| `ppHideBreakdown` | Hide the breakdown | Button. | وردەکاری نرخ بشارەوە | High | Common interface wording — awaiting review |  |
| `ppInstallation` | Include installation | Switch. | دامەزراندنیش لەخۆبگرێت | High | Common interface wording — awaiting review |  |
| `ppLineLength` | Internal line length | Measurement. | درێژی هێڵە ناوەکییەکان | High | Common interface wording — awaiting review |  |
| `ppOpeningProfile` | Opening profile | Measurement. | پرۆفایلی بەشی کراوە | High | Common interface wording — awaiting review |  |
| `ppOtherProfile` | Other profile | Measurement. | پرۆفایلی تر | High | Common interface wording — awaiting review |  |
| `ppPrevious` | Previous calculation: {amount} — not current | A stale price. | هەژماری پێشوو: ‎{amount}‎ — ئێستایی نییە | High | Common interface wording — awaiting review |  |
| `ppPrice` | PRICE | Heading of the price panel. | نرخ | High | Common interface wording — awaiting review |  |
| `ppReadingList` | Reading the price list… | While the price list loads. | خوێندنەوەی لیستی نرخ… | High | Common interface wording — awaiting review |  |
| `ppShowBreakdown` | Show the breakdown | Button. | وردەکاری نرخ پیشان بدە | High | Common interface wording — awaiting review |  |
| `ppTotal` | Total | Row: the design's total. | کۆ | High | Common interface wording — awaiting review |  |
| `ppTotalProfile` | Total profile | Measurement. | کۆی پرۆفایل | High | Common interface wording — awaiting review |  |
| `previewUnavailable` | Preview unavailable | A design card whose record cannot be read. | پێشبینین بەردەست نییە | High | Common interface wording — awaiting review |  |
| `price` | Price | Button: see or calculate a design's price. | نرخ | High | Common interface wording — awaiting review |  |
| `priceChooseColour` | Price: choose colour | A design's card: a colour to choose again. | نرخ: ڕەنگ هەڵبژێرە | High | Common interface wording — awaiting review |  |
| `priceChooseMaterial` | Price: choose material | A design's card: the material to choose. | نرخ: کەرەستە هەڵبژێرە | High | Common interface wording — awaiting review |  |
| `priceChooseProfile` | Price: choose profile | A design's card: the aluminium profile category to choose. | نرخ: پرۆفایل هەڵبژێرە | High | Common interface wording — awaiting review |  |
| `priceHidden` | Price: hidden | A design's card, for somebody not allowed to see prices. | نرخ: شاراوە | High | Common interface wording — awaiting review |  |
| `priceIs` | Price: {amount} | A design's card: its price. | نرخ: ‎{amount}‎ | High | Common interface wording — awaiting review |  |
| `priceLoading` | Price: … | A design's card while its price is read. | نرخ: … | High | Common interface wording — awaiting review |  |
| `priceNeedsUpdate` | Price: needs update | A design's card: drawn on since it was read. | نرخ: پێویستی بە نوێکردنەوەیە | High | Common interface wording — awaiting review |  |
| `priceNotCalculated` | Price: not calculated | A design's card. | نرخ: نەژمێردراوە | High | Common interface wording — awaiting review |  |
| `priceRecalculate` | Price: recalculate | A design's card: the kept price is not current. | نرخ: دووبارە بژمێرەوە | High | Common interface wording — awaiting review |  |
| `priceUnavailable` | Price: unavailable | A design's card. | نرخ: بەردەست نییە | High | Common interface wording — awaiting review |  |
| `quoteBy` |  by {who} | Added after a date: who did it. |  لەلایەن {who}ەوە | High | Common interface wording; Begins or ends with a space, which the application keeps — awaiting review |  |
| `quoted` | “{query}” | A search, quoted. | «{query}» | High | Common interface wording — awaiting review |  |
| `quoteDesignDiscount` | Design discount ({discount}) | A design's own discount on a quotation. | داشکاندنی دیزاین (‎{discount}‎) | High | Common interface wording — awaiting review |  |
| `quoteDiscountLine` | Discount: {discount} | In the new quotation dialog. | داشکاندن: ‎{discount}‎ | High | Common interface wording — awaiting review |  |
| `quoteFor` | For {name} · made {day} | Under a quotation's number. | بۆ {name} · دروستکراوە لە {day} | High | Common interface wording — awaiting review |  |
| `quoteIssue` | Issue | Button: issue a quotation. | دەرکردن | High | Common interface wording — awaiting review |  |
| `quoteListVersion` | prices of list version {version} | Which price list a quotation used. | نرخەکانی وەشانی {version}ی لیست | High | Common interface wording — awaiting review |  |
| `quoteMarkAccepted` | Mark accepted | Button. | وەک پەسەندکراو دیاری بکە | High | Common interface wording — awaiting review |  |
| `quoteMarkExpired` | Mark expired | Button. | وەک بەسەرچوو دیاری بکە | High | Common interface wording — awaiting review |  |
| `quoteMarkRejected` | Mark rejected | Button. | وەک ڕەتکراوە دیاری بکە | High | Common interface wording — awaiting review |  |
| `quoteNoDesigns` | This customer has no designs yet. | In the new quotation dialog. | ئەم کڕیارە هێشتا هیچ دیزاینێکی نییە. | High | Common interface wording — awaiting review |  |
| `quoteNotes` | Notes (optional) | Field. | تێبینییەکان (ئارەزوومەندانە) | High | Common interface wording — awaiting review |  |
| `quotePricedWhenQuoted` | Complete — priced when quoted | A design not yet priced. | تەواوە — لە کاتی پێشنیارکردندا نرخی بۆ دادەنرێت | High | Common interface wording — awaiting review |  |
| `quotePricesChanged` | The factory prices have changed since. | Warning on a quotation. | نرخەکانی کارگە لەو کاتەوە گۆڕاون. | High | Common interface wording — awaiting review |  |
| `quoteStatusOn` | {status} — {day} | A status change and its day. | {status} — {day} | High | Common interface wording — awaiting review |  |
| `rcpAmount` | Amount received | On a receipt. | بڕی وەرگیراو | High | Common interface wording — awaiting review |  |
| `rcpAtRate` | At 1 {from} = {rate} {to} | On a receipt. | بە ‎1 {from} = {rate} {to}‎ | High | Common interface wording — awaiting review |  |
| `rcpBalance` | Balance after this payment | On a receipt. | باڵانس دوای ئەم پارەدانە | High | Common interface wording — awaiting review |  |
| `rcpDate` | Date received | On a receipt. | بەرواری وەرگرتن | High | Common interface wording — awaiting review |  |
| `rcpDue` | {amount} due | On a receipt. | ‎{amount}‎ ماوە | High | Common interface wording — awaiting review |  |
| `rcpForPayment` |  · for payment {id} | On a receipt. |  · بۆ پارەدانی {id} | High | Common interface wording; Begins or ends with a space, which the application keeps — awaiting review |  |
| `rcpIssued` | Issued {day} | On a receipt. | دەرکراوە لە {day} | High | Common interface wording — awaiting review |  |
| `rcpNotFinal` | Total not final when issued | On a receipt. | کۆی گشتی لە کاتی دەرکردندا کۆتایی نەبوو | High | Common interface wording — awaiting review |  |
| `rcpPaidInFull` | Paid in full | On a receipt. | بە تەواوی دراوە | High | Common interface wording — awaiting review |  |
| `rcpReceivedFrom` | Received from {name} | On a receipt. | وەرگیراوە لە {name}ەوە | High | Common interface wording — awaiting review |  |
| `saveChanges` | Save changes | Button: keep the changes made. | پاشەکەوتکردنی گۆڕانکارییەکان | High | Common interface wording — awaiting review |  |
| `saveCustomer` | Save customer | Button: keep a new customer. | پاشەکەوتکردنی کڕیار | High | Common interface wording — awaiting review |  |
| `searchDesignsHint` | Search designs by name... | Hint in the designs' search field. | گەڕان لە دیزاینەکان بە ناو... | High | Common interface wording — awaiting review |  |
| `secLeft` | left | Where a section is: the left column. | چەپ | High | Common interface wording — awaiting review |  |
| `secLower` | Lower | Where a section is: the lower row. | خوارەوە | High | Common interface wording — awaiting review |  |
| `secPlaced` | {place} section — {size} | A section, named by where it is and its size. | بەشی {place} — ‎{size}‎ | High | Common interface wording — awaiting review |  |
| `secRight` | right | Where a section is: the right column. | ڕاست | High | Common interface wording — awaiting review |  |
| `secUpper` | Upper | Where a section is: the upper row. | سەرەوە | High | Common interface wording — awaiting review |  |
| `settingsAppearance` | Appearance | Heading of the light or dark choice, and its button's tooltip. | ڕووکار | High | Common interface wording — awaiting review |  |
| `settingsLanguage` | Language | Heading of the language choice. | زمان | High | Common interface wording — awaiting review |  |
| `settingsTitle` | Settings | The settings screen's title, and the button that opens it. | ڕێکخستنەکان | High | Common interface wording — awaiting review |  |
| `showAllDesigns` | Show all designs | Button: clear the search and filter. | پیشاندانی هەموو دیزاینەکان | High | Common interface wording — awaiting review |  |
| `stageCompleted` | Completed | A design the user completed. | تەواوکراو | High | Common interface wording — awaiting review |  |
| `stageDraft` | Draft | A design ready but not completed. | ڕەشنووس | High | Common interface wording — awaiting review |  |
| `startDrawing` | Start drawing | Button: begin the design and go to the drawing. | دەستپێکردنی نەخشەکێشان | High | Common interface wording — awaiting review |  |
| `tbPenColour` | Pen colour | Tooltip and title. | ڕەنگی قەڵەم | High | Common interface wording — awaiting review |  |
| `todayAt` | Today, {time} | When a design was last edited: today. | ئەمڕۆ، {time} | High | Common interface wording — awaiting review |  |
| `toolArrow` | Arrow | Tool. | تیر | High | Common interface wording — awaiting review |  |
| `toolArrowHint` | Drag from the tail to the point. | Tool hint. | لە کلکەوە بۆ سەری تیرەکە ڕابکێشە. | High | Common interface wording — awaiting review |  |
| `toolDimension` | Dimension | Tool. | پێوانە | High | Common interface wording — awaiting review |  |
| `toolDimensionHint` | Drag between the two points you are measuring. | Tool hint. | لە نێوان ئەو دوو خاڵەدا ڕابکێشە کە دەیانپێویت. | High | Common interface wording — awaiting review |  |
| `toolEraser` | Eraser | Tool. | سڕەرەوە | High | Common interface wording — awaiting review |  |
| `toolEraserHint` | Tap a stroke to rub it out. | Tool hint. | دەست لە هێڵێک بدە بۆ سڕینەوەی. | High | Common interface wording — awaiting review |  |
| `toolGoBack` | {tool}\nTap to go back to the drawing and use it. | Tooltip on a drawing tool away from the drawing. | {tool}\nدەستی لێبدە بۆ گەڕانەوە بۆ نەخشەکە و بەکارهێنانی. | High | Common interface wording — awaiting review |  |
| `toolLine` | Straight line | Tool. | هێڵی ڕاست | High | Common interface wording — awaiting review |  |
| `toolLineHint` | Two taps, or drag from one end to the other. | Tool hint. | دوو جار دەست لێدان، یان لە سەرێکەوە بۆ سەرەکەی تر ڕابکێشە. | High | Common interface wording — awaiting review |  |
| `toolNote` | Note | Tool. | تێبینی | High | Common interface wording — awaiting review |  |
| `toolNoteHint` | Tap where the note goes, then type it. | Tool hint. | دەست لەو شوێنە بدە کە تێبینییەکە دەچێتە ئەوێ، پاشان بینووسە. | High | Common interface wording — awaiting review |  |
| `toolPen` | Freehand | Tool: draw freehand. | دەستی ئازاد | High | Common interface wording — awaiting review |  |
| `toolPenHint` | Draw as you would on paper. Pause with the pen down to straighten. | Tool hint. | وەک لەسەر کاغەز بیکێشە. قەڵەمەکە دابگرە و ڕاوەستە بۆ ڕاستکردنەوەی هێڵەکە. | High | Common interface wording — awaiting review |  |
| `toolPolyline` | Polyline | Tool: a chain of lines. | هێڵی شکاو | High | Common interface wording — awaiting review |  |
| `toolPolylineHint` | Tap each corner. Tap the first one again to close. | Tool hint. | دەست لە هەر گۆشەیەک بدە. دووبارە دەست لە یەکەمیان بدە بۆ داخستن. | High | Common interface wording — awaiting review |  |
| `toolRectangle` | Rectangle | Tool. | لاکێشە | High | Common interface wording — awaiting review |  |
| `toolRectangleHint` | Drag a corner to the opposite corner. | Tool hint. | گۆشەیەک بۆ گۆشەی بەرامبەر ڕابکێشە. | High | Common interface wording — awaiting review |  |
| `toolSelect` | Select | Tool. | هەڵبژاردن | High | Common interface wording — awaiting review |  |
| `toolSelectHint` | Tap a part to pick it. Drag to move it. | Tool hint. | دەست لە بەشێک بدە بۆ هەڵبژاردنی. ڕایبکێشە بۆ جوڵاندنی. | High | Common interface wording — awaiting review |  |
| `undo` | Undo | Undo the last action. | گەڕاندنەوە | High | Common interface wording — awaiting review |  |
| `undoAfterwards` | You can undo it straight afterwards. | Under the delete question. | دەتوانیت دەستبەجێ دوای ئەوە بیگەڕێنیتەوە. | High | Common interface wording — awaiting review |  |
| `unsupportedTitle` | Unsupported design category | Note on a design of an unknown category. | جۆری دیزاینی پشتگیری‌نەکراو | High | Common interface wording — awaiting review |  |
| `vcFit` | Fit to the view | Tooltip. | گونجاندن لەگەڵ پیشاندان | High | Common interface wording — awaiting review |  |
| `vcReset` | Reset the view | Tooltip. | گەڕاندنەوەی پیشاندان | High | Common interface wording — awaiting review |  |
| `vcZoomIn` | Zoom in | Tooltip. | نزیککردنەوە | High | Common interface wording — awaiting review |  |
| `vcZoomOut` | Zoom out | Tooltip. | دوورخستنەوە | High | Common interface wording — awaiting review |  |
| `view3d` | 3D model | View: the model. | مۆدێلی 3D | High | Common interface wording — awaiting review |  |
| `view3dShort` | 3D | View, short. | 3D | High | Common interface wording — awaiting review |  |
| `viewCad` | CAD drawing | View: the technical drawing. | نەخشەی CAD | High | Common interface wording — awaiting review |  |
| `viewCadShort` | CAD | View, short. | CAD | High | Common interface wording — awaiting review |  |
| `viewCompletedDesign` | View Completed Design | After completing: stay on the design. | بینینی دیزاینی تەواوکراو | High | Common interface wording — awaiting review |  |
| `viewDraw` | Draw | View: the drawing. | کێشان | High | Common interface wording — awaiting review |  |
| `vmMaterial` | Material | View mode. | کەرەستە | High | Common interface wording — awaiting review |  |
| `vmMaterialHint` | Glass, panel, frame and metal as they are made. | View mode hint. | شووشە، پانێڵ، چوارچێوە و کانزا وەک چۆن دروست کراون. | High | Common interface wording — awaiting review |  |
| `vmRealistic` | Realistic | View mode. | ڕاستەقینە | High | Common interface wording — awaiting review |  |
| `vmRealisticHint` | Materials, light and shadow, as it will look. | View mode hint. | کەرەستە، ڕووناکی و سێبەر، وەک ئەوەی دەردەکەوێت. | High | Common interface wording — awaiting review |  |
| `vmShadedHint` | One colour, lit, so the form reads on its own. | View mode hint. | یەک ڕەنگ، ڕووناککراو، بۆ ئەوەی شێوەکە بە تەنها دیار بێت. | High | Common interface wording — awaiting review |  |
| `vmTechnical` | Technical | View mode. | تەکنیکی | High | Common interface wording — awaiting review |  |
| `vmTechnicalHint` | A line drawing with the overall sizes. | View mode hint. | نەخشەیەکی هێڵی لەگەڵ قەبارە گشتییەکان. | High | Common interface wording — awaiting review |  |
| `vmWireframeHint` | Every edge, including the ones behind. | View mode hint. | هەموو لێوارەکان، ئەوانەی دواوەش. | High | Common interface wording — awaiting review |  |
| `wbEveryTool` | Show every tool | Tooltip. | هەموو ئامرازەکان پیشان بدە | High | Common interface wording — awaiting review |  |
| `wbFewerTools` | Show fewer tools | Tooltip. | ئامرازی کەمتر پیشان بدە | High | Common interface wording — awaiting review |  |
| `wbLess` | Less | Button: show fewer controls. | کەمتر | High | Common interface wording — awaiting review |  |
| `wbMore` | More | Button: show every control. | زیاتر | High | Common interface wording — awaiting review |  |
| `wbSave` | Save | Tooltip. | پاشەکەوتکردن | High | Common interface wording — awaiting review |  |
| `whatGlass` | What glass is it? | Second step: the glass. | چ جۆرە شووشەیەکە؟ | High | Common interface wording — awaiting review |  |
| `whatPanelColour` | What colour is the panel? | Second step: the panel's colour. | ڕەنگی پانێڵەکە چییە؟ | High | Common interface wording — awaiting review |  |
| `whoIsThisFor` | Who is this design for? | New design from the first screen: who it is for. | ئەم دیزاینە بۆ کێیە؟ | High | Common interface wording — awaiting review |  |
| `wholeGlass` | Entire design = Glass | Choice: the whole design is glass. | هەموو دیزاینەکە = شووشە | High | Common interface wording — awaiting review |  |
| `wholeGlassDetail` | Every part is glazed. | Detail of the choice. | هەموو بەشێک شووشەی تێدایە. | High | Common interface wording — awaiting review |  |
| `wholePanel` | Entire design = Panel | Choice: the whole design is panel. | هەموو دیزاینەکە = پانێڵ | High | Common interface wording — awaiting review |  |
| `wholePanelDetail` | Every part is a solid panel. | Detail of the choice. | هەموو بەشێک پانێڵێکی پتەوە. | High | Common interface wording — awaiting review |  |
| `wsChanged` | Your drawing has changed. | Notice. | نەخشەکەت گۆڕاوە. | High | Common interface wording — awaiting review |  |
| `wsChangesNotRead` | Your drawing has changes that have not been read yet. | Notice. | نەخشەکەت گۆڕانکاری تێدایە کە هێشتا نەخوێندراونەتەوە. | High | Common interface wording — awaiting review |  |
| `wsDetails` | Details | Button: the panel of details. | وردەکارییەکان | High | Common interface wording — awaiting review |  |
| `wsEdit` | Edit | Button. | دەستکاری | High | Common interface wording — awaiting review |  |
| `wsGlassOrPanel` | Glass or panel | Tooltip. | شووشە یان پانێڵ | High | Common interface wording — awaiting review |  |
| `wsHideDrawing` | Hide my drawing | Tooltip. | نەخشەکەم بشارەوە | High | Common interface wording — awaiting review |  |
| `wsLetGo` | Let it go | Tooltip: unpick. | وازی لێبهێنە | High | Common interface wording — awaiting review |  |
| `wsMaterial` | Material | Tooltip. | کەرەستە | High | Common interface wording — awaiting review |  |
| `wsParts` | Parts | Button: the list of parts. | بەشەکان | High | Common interface wording — awaiting review |  |
| `wsReadAgain` | Read again | Button: read the drawing again. | دووبارە خوێندنەوە | High | Common interface wording — awaiting review |  |
| `wsReadIt` | Read it | Button. | بیخوێنەرەوە | High | Common interface wording — awaiting review |  |
| `wsReadMyDrawing` | Read my drawing | Button. | نەخشەکەم بخوێنەرەوە | High | Common interface wording — awaiting review |  |
| `wsRedo` | Redo | Tooltip. | دووبارەکردنەوە | High | Common interface wording — awaiting review |  |
| `wsSaved` | Design saved. | Notice. | دیزاینەکە پاشەکەوت کرا. | High | Common interface wording — awaiting review |  |
| `wsShowDrawing` | Show my drawing | Tooltip. | نەخشەکەم پیشان بدە | High | Common interface wording — awaiting review |  |
| `wsSizes` | Sizes | Tooltip. | قەبارەکان | High | Common interface wording — awaiting review |  |
| `wsUndo` | Undo | Tooltip. | گەڕاندنەوە | High | Common interface wording — awaiting review |  |
| `xAddTitle` | Add extra | Title of the extra dialog. | زیادکردنی تێچوو | High | Common interface wording — awaiting review |  |
| `xCategory` | Category | Field. | جۆر | High | Common interface wording — awaiting review |  |
| `xEditOf` | Edit {name} | Tooltip. | دەستکاریکردنی {name} | High | Common interface wording — awaiting review |  |
| `xEditTitle` | Edit extra | Title of the extra dialog. | دەستکاریکردنی تێچوو | High | Common interface wording — awaiting review |  |
| `xIsAdditional` | This is an additional charge | Tick. | ئەمە تێچوویەکی زیادەیە | High | Common interface wording — awaiting review |  |
| `xName` | Name | Field. | ناو | High | Common interface wording — awaiting review |  |
| `xNameHint` | Silicone, labour, transport… | Example extras. | سیلیکۆن، کرێی کار، گواستنەوە… | High | Common interface wording — awaiting review |  |
| `xNoteOptional` | Note (optional) | Field. | تێبینی (ئارەزوومەندانە) | High | Common interface wording — awaiting review |  |
| `xOtherUnit` | Other unit… | Choice: type a unit. | یەکەی تر… | High | Common interface wording — awaiting review |  |
| `xQuantity` | Quantity | Field. | بڕ | High | Common interface wording — awaiting review |  |
| `xRemoveAsk` | Remove "{name}" ({amount}) from {from}? | Confirmation. | "{name}" (‎{amount}‎) لە {from} لاببرێت؟ | High | Common interface wording — awaiting review |  |
| `xRemoveOf` | Remove {name} | Tooltip. | لابردنی {name} | High | Common interface wording — awaiting review |  |
| `xRemoveTitle` | Remove extra | Title. | لابردنی تێچوو | High | Common interface wording — awaiting review |  |
| `xSave` | Save extra | Button. | پاشەکەوتکردنی تێچوو | High | Common interface wording — awaiting review |  |
| `xTickAdditional` | Tick "This is an additional charge" to add it on top. | Extra dialog check. | "ئەمە تێچوویەکی زیادەیە" دیاری بکە بۆ ئەوەی بیخەیتە سەری. | High | Common interface wording — awaiting review |  |
| `xTotal` | Total | Row. | کۆ | High | Common interface wording — awaiting review |  |
| `xUnit` | Unit | Field. | یەکە | High | Common interface wording — awaiting review |  |
| `xUnitInWords` | Unit, in words | Field. | یەکە، بە وشە | High | Common interface wording — awaiting review |  |
| `xUnitPrice` | Unit price | Field. | نرخی یەکە | High | Common interface wording — awaiting review |  |
| `yesterdayAt` | Yesterday, {time} | When a design was last edited: yesterday. | دوێنێ، {time} | High | Common interface wording — awaiting review |  |
