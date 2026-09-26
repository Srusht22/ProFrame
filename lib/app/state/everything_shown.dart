import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the workspace shows every control, or only the few a drawing
/// needs.
///
/// The user's words: *it is so overwhelming, there are a ton of things. I
/// know they are necessary, but the app is used by people who do not know
/// much about technology; they want it clear and simple. Use a button to
/// show all those icons.* So the workspace opens simple — the drawing, the
/// three views, the handful of tools a door is drawn with — and **More**
/// beside the views shows everything else, from the layers of the technical
/// drawing to the camera's views of the model. Nothing is taken away; it is
/// one tap off. The choice is kept on the device, so someone who wants
/// everything shown has it shown next time too.
final everythingShownProvider = NotifierProvider<EverythingShown, bool>(
  EverythingShown.new,
);

class EverythingShown extends Notifier<bool> {
  /// Where the choice is kept.
  static const key = 'proframe.everything-shown';

  bool _chosen = false;

  @override
  bool build() {
    _restore();
    return false;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kept = prefs.getBool(key);
      if (_chosen || kept == null) return;
      state = kept;
    } on Object {
      // Nowhere to keep it: simple, as a first visit is.
    }
  }

  Future<void> set(bool shown) async {
    _chosen = true;
    state = shown;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, shown);
    } on Object {
      // Keeping it is a convenience; the choice stands for this session.
    }
  }

  Future<void> toggle() => set(!state);
}
