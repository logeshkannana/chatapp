import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../main.dart';

enum ConnectionStatus {
  connected,
  disconnected,
  reconnecting,
}

enum UserPresenceStatus {
  active,
  away,
  offline,
  doNotDisturb,
}

class ConnectionService extends ChangeNotifier {
  static final ConnectionService _instance = ConnectionService._internal();

  factory ConnectionService() {
    return _instance;
  }

  ConnectionService._internal();

  final Connectivity _connectivity = Connectivity();
  ConnectionStatus _status = ConnectionStatus.connected;
  UserPresenceStatus _presenceStatus = UserPresenceStatus.active;
  DateTime? _lastSyncTime;
  bool _isSyncing = false;
  String? _currentUserId;

  ConnectionStatus get status => _status;
  UserPresenceStatus get presenceStatus => _presenceStatus;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isSyncing => _isSyncing;
  bool get isConnected => _status == ConnectionStatus.connected;

  void init({String? userId}) {
    _currentUserId = userId;
    _connectivity.onConnectivityChanged.listen((result) async {
      _updateConnectionStatus(result as List<ConnectivityResult>);
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final wasConnected = _status == ConnectionStatus.connected;
    final isNowConnected = !result.contains(ConnectivityResult.none);

    if (isNowConnected && !wasConnected) {
      _status = ConnectionStatus.connected;
      _lastSyncTime = DateTime.now();
      _syncPresenceToDatabase();
    } else if (!isNowConnected && wasConnected) {
      _status = ConnectionStatus.disconnected;
    }

    notifyListeners();
  }

  void updateSyncStatus(bool syncing) {
    _isSyncing = syncing;
    if (!syncing) {
      _lastSyncTime = DateTime.now();
    }
    notifyListeners();
  }

  Future<void> setPresenceStatus(UserPresenceStatus status) async {
    _presenceStatus = status;
    notifyListeners();
    await _syncPresenceToDatabase();
  }

  Future<void> _syncPresenceToDatabase() async {
    if (_currentUserId == null || !isConnected) return;

    try {
      final userId = _currentUserId!;
      final presenceMap = {
        'active': 'active',
        'away': 'away',
        'offline': 'offline',
        'doNotDisturb': 'do_not_disturb',
      };

      final statusValue =
          presenceMap[_presenceStatus.toString().split('.').last];

      // Upsert user presence record
      await supabase.from('user_presence').upsert({
        'user_id': userId,
        'status': statusValue,
        'last_seen': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      // Update last_seen in users table
      await supabase.from('users').update({
        'last_seen': DateTime.now().toIso8601String(),
        'is_online': isConnected,
      }).eq('id', userId);
    } catch (e) {
      debugPrint('Error syncing presence: $e');
    }
  }

  String getStatusMessage() {
    switch (_status) {
      case ConnectionStatus.connected:
        if (_isSyncing) return 'Syncing...';
        if (_lastSyncTime != null) {
          final diff = DateTime.now().difference(_lastSyncTime!);
          if (diff.inSeconds < 60) return 'Online';
          if (diff.inMinutes < 60) return 'Last sync ${diff.inMinutes}m ago';
          return 'Last sync ${diff.inHours}h ago';
        }
        return 'Online';
      case ConnectionStatus.disconnected:
        return 'Offline';
      case ConnectionStatus.reconnecting:
        return 'Reconnecting...';
    }
  }

  String getPresenceText() {
    switch (_presenceStatus) {
      case UserPresenceStatus.active:
        return 'Active';
      case UserPresenceStatus.away:
        return 'Away';
      case UserPresenceStatus.offline:
        return 'Offline';
      case UserPresenceStatus.doNotDisturb:
        return 'Do not disturb';
    }
  }

  String getStatusIcon() {
    switch (_status) {
      case ConnectionStatus.connected:
        return '●';
      case ConnectionStatus.disconnected:
        return '○';
      case ConnectionStatus.reconnecting:
        return '◐';
    }
  }
}
