import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// 網路連線狀態檢查。connectivity_plus 只回報「有無網路介面」,
/// 介面存在不代表能出網(例如 VPN 介面還掛著但底層已斷線),
/// 因此有介面時再實測輕量端點確認可達,全部失敗才視為離線。
class NetworkStatusService {
  /// 實測端點:captive-portal 檢測頁,回應極小、無 redirect。
  /// 取兩家不同供應商,涵蓋單一服務被擋或故障的情況
  /// (例如中國大陸擋 gstatic 時 Apple 端點仍可達)。
  static final _probes = [
    Uri.https('www.gstatic.com', '/generate_204'),
    Uri.https('captive.apple.com', '/hotspot-detect.html'),
  ];

  /// 單一端點的實測逾時,也是離線(如 VPN 黑洞)時使用者等待提示的上限。
  static const _probeTimeout = Duration(seconds: 3);

  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    // 完全沒有介面(飛航模式等)直接視為離線,不必等實測逾時。
    if (results.every((r) => r == ConnectivityResult.none)) return false;
    return _anyProbeReachable();
  }

  /// 並發實測所有端點:第一個成功即回 true,全部失敗 / 逾時才回 false。
  Future<bool> _anyProbeReachable() {
    final completer = Completer<bool>();
    var pending = _probes.length;
    for (final uri in _probes) {
      _probeReachable(uri).then((ok) {
        pending--;
        if (completer.isCompleted) return;
        if (ok) {
          completer.complete(true);
        } else if (pending == 0) {
          completer.complete(false);
        }
      });
    }
    return completer.future;
  }

  Future<bool> _probeReachable(Uri uri) async {
    try {
      final res = await http.head(uri).timeout(_probeTimeout);
      return res.statusCode >= 200 && res.statusCode < 400;
    } catch (_) {
      return false;
    }
  }
}

final networkStatusServiceProvider = Provider<NetworkStatusService>(
  (ref) => NetworkStatusService(),
);
