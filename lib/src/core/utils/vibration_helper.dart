import 'package:vibration/vibration.dart';

class VibrationHelper {
  static Future<void> vibrate(double strength) async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;

    int duration;
    if (strength <= 0.2) {
      duration = 8;
    } else if (strength <= 0.4) {
      duration = 12;
    } else if (strength <= 0.6) {
      duration = 25;
    } else if (strength <= 0.8) {
      duration = 40;
    } else {
      duration = 60;
    }

    await Vibration.vibrate(duration: duration);
  }
}
