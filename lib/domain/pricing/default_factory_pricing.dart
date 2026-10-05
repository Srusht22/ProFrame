import '../model/elements.dart';
import '../model/materials.dart';
import 'price_list.dart';

/// The rates the application prices by until the workshop owner keeps a
/// price list of their own — **the one place they are written**.
///
/// Every figure here is an example, in US dollars: $7 a metre of uPVC
/// normal profile and $12 a metre of opening profile among them. The
/// pricing engine never reads a figure from here: it reads whatever
/// [PriceList] it is given, and the list in use is this one only while
/// nothing else has been kept (`PriceListStore.load`), which the screen
/// says ([PriceList.isStarter]). A price editor, when there is one, keeps a
/// list of the owner's own and this is no longer read — nothing in the
/// engine changes.
abstract final class DefaultFactoryPricing {
  static final PriceList list = PriceList(
    isStarter: true,
    currency: 'USD',
    profiles: {
      MaterialKind.upvc: const ProfileRate(
        normalPerMetre: 7,
        openingPerMetre: 12,
        colours: [
          ColourRate('White', 0xFFFFFFFF, ColourGrade.standard),
          ColourRate('Off white', 0xFFF3F4F2, ColourGrade.standard),
          ColourRate(
            'Cream',
            0xFFD8D5CC,
            ColourGrade.nonStandard,
            perMetre: 0.8,
          ),
          ColourRate('Grey', 0xFF6E7472, ColourGrade.nonStandard, perMetre: 1),
          ColourRate(
            'Graphite',
            0xFF3A3A38,
            ColourGrade.nonStandard,
            perMetre: 1,
          ),
          ColourRate('Black', 0xFF1C1C1C, ColourGrade.nonStandard, perMetre: 1),
          ColourRate(
            'Oak effect',
            0xFF7B4A2B,
            ColourGrade.nonStandard,
            perMetre: 1.5,
          ),
          ColourRate(
            'Walnut effect',
            0xFF4A2F1E,
            ColourGrade.nonStandard,
            perMetre: 1.5,
          ),
        ],
        special: ColourSurcharge(perMetre: 2.5),
      ),
      MaterialKind.aluminium: const ProfileRate(
        normalPerMetre: 11,
        openingPerMetre: 18,
        colours: [
          ColourRate('Silver', 0xFF9C9C9C, ColourGrade.standard),
          ColourRate('White', 0xFFFFFFFF, ColourGrade.standard),
          ColourRate('Off white', 0xFFF3F4F2, ColourGrade.standard),
          ColourRate('Black', 0xFF1C1C1C, ColourGrade.nonStandard, perMetre: 1),
          ColourRate(
            'Anthracite',
            0xFF383E42,
            ColourGrade.nonStandard,
            perMetre: 1,
          ),
          ColourRate(
            'Graphite',
            0xFF3A3A38,
            ColourGrade.nonStandard,
            perMetre: 1,
          ),
          ColourRate(
            'Oak effect',
            0xFF7B4A2B,
            ColourGrade.nonStandard,
            perMetre: 2,
          ),
        ],
        special: ColourSurcharge(perMetre: 3),
      ),
    },
    glassPerM2: const {
      GlassLook.clear: 25,
      GlassLook.frosted: 32,
      GlassLook.tinted: 34,
      GlassLook.dark: 36,
      GlassLook.blueGrey: 36,
    },
    customGlassPerM2: 40,
    // A sealed unit is two sheets, a spacer and a seal: dearer than one
    // sheet of the same glass.
    sealedGlassPerM2: const {
      GlassLook.clear: 45,
      GlassLook.frosted: 52,
      GlassLook.tinted: 54,
      GlassLook.dark: 56,
      GlassLook.blueGrey: 56,
    },
    customSealedGlassPerM2: 60,
    panelPerM2: const {
      PanelColour.white: 30,
      PanelColour.grey: 34,
      PanelColour.black: 34,
      PanelColour.brown: 36,
    },
    customPanelPerM2: 40,
    hardwareEach: const {
      HardwareKind.handle: 10,
      HardwareKind.lever: 15,
      HardwareKind.knob: 8,
      HardwareKind.lock: 22,
      HardwareKind.hinge: 3,
      HardwareKind.letterplate: 12,
      HardwareKind.peephole: 6,
      HardwareKind.closer: 28,
      HardwareKind.pull: 14,
      HardwareKind.screen: 45,
      HardwareKind.sensor: 110,
    },
    trackPerMetre: 9,
    rollerEach: 4,
    categories: const {
      'door': CategoryRate('Door', LabourRate()),
      'window': CategoryRate('Window', LabourRate()),
      'sliding': CategoryRate('Sliding', LabourRate()),
      'both': CategoryRate('Door & window', LabourRate()),
      'angled': CategoryRate('Angled / Asymmetrical', LabourRate()),
    },
    installation: const InstallationRate(fixed: 20, perSquareMetre: 8),
  );
}
