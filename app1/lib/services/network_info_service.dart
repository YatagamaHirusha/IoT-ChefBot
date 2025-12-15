import 'package:network_info_plus/network_info_plus.dart';

class NetworkInfoService {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Returns the current Wi-Fi SSID (without surrounding quotes) or null.
  Future<String?> getCurrentSsid() async {
    try {
      final ssid = await _networkInfo.getWifiName();
      if (ssid == null) return null;
      // Some platforms wrap SSID in quotes.
      return ssid.replaceAll('"', '').trim();
    } catch (e) {
      return null;
    }
  }

  /// Returns true if currently connected to a ChefBot AP (SSID starts with 'ChefBot-').
  Future<bool> isChefBotAp() async {
    final ssid = await getCurrentSsid();
    if (ssid == null) return false;
    return ssid.startsWith('ChefBot-');
  }
}
