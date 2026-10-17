import 'package:network_info_plus/network_info_plus.dart';

/// Godot'taki `IP.get_local_addresses()` dongusunun (ilk gecerli IPv4'u
/// secen kisminin) Flutter karsiligi. `network_info_plus`, Wi-Fi
/// arayuzunun yerel IP'sini dogrudan verir; hucresel veri gibi diger
/// arayuzler icin genisletme YGL listesinde.
class NetworkService {
  final NetworkInfo _networkInfo = NetworkInfo();

  Future<String> localIpAddress() async {
    try {
      final ip = await _networkInfo.getWifiIP();
      return (ip == null || ip.isEmpty) ? 'Bulunamadı' : ip;
    } catch (_) {
      return 'Bulunamadı';
    }
  }
}
