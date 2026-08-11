import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_client.dart';
import 'session_store.dart';

class AppController extends ChangeNotifier {
  AppController() {
    api = ApiClient(session);
  }

  final SessionStore session = SessionStore();
  late final ApiClient api;

  bool isArabic = true;
  bool musicEnabled = true;
  bool effectsEnabled = true;
  bool vibrationEnabled = true;
  bool initialized = false;
  bool busy = false;
  bool hasSeenOnboarding = false;
  String? errorMessage;

  Map<String, dynamic>? currentUser;
  Map<String, dynamic>? publicSettings;
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> matches = [];
  List<Map<String, dynamic>> notifications = [];
  List<Map<String, dynamic>> catalogItems = [];
  List<Map<String, dynamic>> inventory = [];
  List<Map<String, dynamic>> campaigns = [];
  List<Map<String, dynamic>> levels = [];
  List<Map<String, dynamic>> stages = [];
  List<Map<String, dynamic>> paymentMethods = [];
  List<Map<String, dynamic>> gameRules = [];
  List<Map<String, dynamic>> socialRooms = [];
  List<Map<String, dynamic>> tournaments = [];
  List<Map<String, dynamic>> achievements = [];
  List<Map<String, dynamic>> supportTickets = [];
  Map<String, dynamic>? referralOverview;
  Map<String, dynamic>? privacySettings;
  Map<String, dynamic>? identityVerification;

  double walletBalance = 0;
  double withdrawableBalance = 0;
  double rewardBalance = 0;
  double lockedBalance = 0;
  int coins = 0;
  int gems = 0;

  bool get isLoggedIn => currentUser != null;
  String? get avatarUrl => currentUser?['profile']?['avatarUrl'] as String?;
  String get displayName => (currentUser?['profile']?['displayName'] ?? currentUser?['username'] ?? '').toString();
  String get username => (currentUser?['username'] ?? '').toString();

  Future<void> initialize() async {
    final local = await Future.wait<dynamic>([
      session.getLocale(),
      session.hasCompletedOnboarding(),
      session.accessToken,
      session.getEffectsEnabled(),
      session.getVibrationEnabled(),
    ]);
    isArabic = local[0] == 'ar';
    hasSeenOnboarding = local[1] == true;
    effectsEnabled = local[3] != false;
    vibrationEnabled = local[4] != false;

    // Do not block the splash screen on public network calls.
    final storedAccessToken = local[2] as String?;
    if (storedAccessToken != null && storedAccessToken.isNotEmpty) {
      try {
        final me = await api.get('/users/me');
        if (me is Map) currentUser = me.cast<String, dynamic>();
      } catch (_) {
        // Keep startup usable even if the local test server is temporarily offline.
      }
    }

    initialized = true;
    notifyListeners();
    unawaited(_bootstrapInBackground());
  }

  Future<void> _bootstrapInBackground() async {
    await Future.wait<void>([
      _loadPublicSettings(),
      _loadCatalog(authenticated: isLoggedIn),
    ]);
    if (isLoggedIn) await refreshAll();
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    hasSeenOnboarding = true;
    await session.completeOnboarding();
    notifyListeners();
  }

  void toggleLanguage() => setArabic(!isArabic);
  Future<void> setArabic(bool value) async {
    isArabic = value;
    await session.setLocale(value ? 'ar' : 'en');
    notifyListeners();
    if (isLoggedIn) {
      try {
        await api.patch('/users/me', body: {'locale': value ? 'ar' : 'en'});
      } catch (_) {}
    }
  }

  Future<bool> login({required String identifier, required String password}) async {
    return _run(() async {
      final result = (await api.post('/auth/login', authenticated: false, body: {
        'identifier': identifier.trim(),
        'password': password,
        'deviceName': 'MAURITANIA LUDO Mobile',
      }) as Map).cast<String, dynamic>();
      await _acceptAuth(result);
      unawaited(refreshAll());
    });
  }

  Future<bool> register({
    required String displayName,
    required String username,
    String? phone,
    required String email,
    required String password,
  }) async {
    return _run(() async {
      final payload = <String, dynamic>{
        'displayName': displayName.trim(),
        'username': username.trim(),
        'password': password,
        'locale': isArabic ? 'ar' : 'en',
        'acceptedTerms': true,
      };
      if (phone != null && phone.trim().isNotEmpty) payload['phone'] = phone.trim();
      payload['email'] = email.trim();
      final result = (await api.post('/auth/register', authenticated: false, body: payload) as Map).cast<String, dynamic>();
      await _acceptAuth(result);
      unawaited(refreshAll());
    });
  }

  Future<Map<String, dynamic>?> requestPasswordReset(String identifier) => _runValue(() async =>
      (await api.post('/auth/password/forgot', authenticated: false, body: {'identifier': identifier.trim()}) as Map).cast<String, dynamic>());

  Future<Map<String, dynamic>?> verifyPasswordReset(String requestId, String code) => _runValue(() async =>
      (await api.post('/auth/password/verify', authenticated: false, body: {'requestId': requestId, 'code': code.trim()}) as Map).cast<String, dynamic>());

  Future<bool> completePasswordReset(String requestId, String resetToken, String newPassword) => _run(() async {
    await api.post('/auth/password/reset', authenticated: false, body: {'requestId': requestId, 'resetToken': resetToken, 'newPassword': newPassword});
  });

  Future<void> _acceptAuth(Map<String, dynamic> result) async {
    await session.saveTokens(
      accessToken: result['accessToken'] as String,
      refreshToken: result['refreshToken'] as String,
    );
    currentUser = (result['user'] as Map).cast<String, dynamic>();
  }

  Future<void> logout() async {
    try {
      await api.post('/auth/logout');
    } catch (_) {}
    await session.clearTokens();
    currentUser = null;
    transactions = [];
    matches = [];
    notifications = [];
    inventory = [];
    tournaments = []; achievements = []; supportTickets = []; referralOverview = null; privacySettings = null; identityVerification = null;
    _clearBalances();
    notifyListeners();
  }

  Future<void> refreshAll() async {
    Future<dynamic> safe(Future<dynamic> request) async {
      try { return await request; } catch (_) { return null; }
    }
    final results = await Future.wait<dynamic>([
      safe(api.get('/users/me')),
      safe(api.get('/wallets/me')),
      safe(api.get('/wallets/me/transactions')),
      safe(api.get('/matches/me')),
      safe(api.get('/notifications')),
      safe(api.get('/catalog/bootstrap')),
    ]);
    if (results[0] is Map) currentUser = (results[0] as Map).cast<String, dynamic>();
    if (results[1] is Map) _applyWallet((results[1] as Map).cast<String, dynamic>());
    if (results[2] != null) transactions = _items(results[2]);
    if (results[3] != null) matches = _items(results[3]);
    if (results[4] != null) notifications = _items(results[4]);
    if (results[5] is Map) _applyCatalog((results[5] as Map).cast<String, dynamic>());
    notifyListeners();
  }

  Future<bool> updateProfile({String? displayName, String? countryCode, String? bio}) {
    return _run(() async {
      final result = await api.patch('/users/me', body: {
        if (displayName != null) 'displayName': displayName,
        if (countryCode != null) 'countryCode': countryCode,
        if (bio != null) 'bio': bio,
      });
      if (result is Map) {
        currentUser = {...?currentUser, 'profile': result['profile'] ?? result};
      }
      await refreshAll();
    });
  }

  Future<bool> uploadAvatarBytes(Uint8List bytes, String filename) {
    return _run(() async {
      await api.uploadBytes('/users/me/avatar', bytes, filename);
      await refreshAll();
    });
  }

  Future<Map<String, dynamic>?> uploadReceiptBytes(Uint8List bytes, String filename) async {
    errorMessage = null;
    try {
      return await api.uploadBytes('/users/me/receipt', bytes, filename);
    } catch (error) {
      errorMessage = _message(error);
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> uploadIdentityDocumentBytes(Uint8List bytes, String filename) async {
    errorMessage = null;
    try {
      return await api.uploadBytes('/users/me/identity-document', bytes, filename);
    } catch (error) {
      errorMessage = _message(error);
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> createPaymentIntent({
    required String methodCode,
    required double amount,
    String? phoneNumber,
    String? externalRef,
    String? receiptFileId,
  }) => _runValue(() async => (await api.post('/payments/deposits', body: {
    'methodCode': methodCode,
    'amount': amount,
    if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
    if (externalRef != null && externalRef.isNotEmpty) 'externalRef': externalRef,
    if (receiptFileId != null && receiptFileId.isNotEmpty) 'receiptFileId': receiptFileId,
  }) as Map).cast<String, dynamic>());

  Future<bool> createDepositRequest({required double amount, required String method, String? externalRef, String? receiptFileId}) {
    return _run(() async {
      await api.post('/wallets/me/deposits', body: {
        'amount': amount,
        'method': method,
        if (externalRef != null && externalRef.isNotEmpty) 'externalRef': externalRef,
        if (receiptFileId != null && receiptFileId.isNotEmpty) 'receiptFileId': receiptFileId,
      });
      await refreshAll();
    });
  }

  Future<bool> createWithdrawalRequest({
    required double amount,
    required String method,
    required String accountNumber,
    required String accountName,
    String note = 'Mobile withdrawal request',
  }) {
    return _run(() async {
      await api.post('/wallets/me/withdrawals', body: {
        'amount': amount,
        'method': method,
        'accountNumber': accountNumber,
        'accountName': accountName,
        'note': note,
      });
      await refreshAll();
    });
  }

  Future<Map<String, dynamic>?> createMatch({
    required String mode,
    required int maxPlayers,
    required String ruleCode,
    double stakeAmount = 0,
  }) async {
    return _runValue(() async => (await api.post('/matches', body: {
      'mode': mode,
      'maxPlayers': maxPlayers,
      'ruleCode': ruleCode,
      'stakeAmount': stakeAmount,
      'currency': 'MRU',
    }) as Map).cast<String, dynamic>());
  }

  Future<Map<String, dynamic>?> matchmake({
    required String mode,
    required int maxPlayers,
    required String ruleCode,
    double stakeAmount = 0,
  }) async {
    return _runValue(() async => (await api.post('/matchmaking/join', body: {
      'mode': mode,
      'maxPlayers': maxPlayers,
      'ruleCode': ruleCode,
      'stakeAmount': stakeAmount,
    }) as Map).cast<String, dynamic>());
  }

  Future<Map<String, dynamic>?> getTicket(String id) =>
      _runValue(() async => (await api.get('/matchmaking/$id') as Map).cast<String, dynamic>());
  Future<bool> cancelTicket(String id) =>
      _run(() async { await api.delete('/matchmaking/$id'); });
  Future<Map<String, dynamic>?> previewRoom(String code) =>
      _runValue(() async => (await api.get('/matches/code/$code') as Map).cast<String, dynamic>());
  Future<Map<String, dynamic>?> joinRoomByCode(String code) =>
      _runValue(() async => (await api.post('/matches/code/$code/join') as Map).cast<String, dynamic>());
  Future<Map<String, dynamic>?> getMatch(String id) =>
      _runValue(() async => (await api.get('/matches/$id') as Map).cast<String, dynamic>());
  Future<Map<String, dynamic>?> startMatch(String id) =>
      _runValue(() async => (await api.post('/matches/$id/start') as Map).cast<String, dynamic>());
  Future<Map<String, dynamic>?> rollMatch(String id) =>
      _runValue(() async => (await api.post('/matches/$id/roll') as Map).cast<String, dynamic>());
  Future<Map<String, dynamic>?> moveMatch(String id, int pieceId, int expectedVersion) =>
      _runValue(() async => (await api.post('/matches/$id/move', body: {'pieceId': pieceId, 'expectedVersion': expectedVersion}) as Map).cast<String, dynamic>());
  Future<Map<String, dynamic>?> forfeitMatch(String id) =>
      _runValue(() async => (await api.post('/matches/$id/forfeit') as Map).cast<String, dynamic>());
  Future<bool> cancelMatch(String id) =>
      _run(() async { await api.post('/matches/$id/cancel'); await refreshAll(); });
  Future<bool> leaveWaitingRoom(String id) =>
      _run(() async { await api.post('/matches/$id/leave'); await refreshAll(); });


  Future<void> loadSocialRooms() async {
    final result = await _runValue(() async => await api.get('/social/rooms'));
    if (result != null) { socialRooms = _items(result); notifyListeners(); }
  }

  Future<Map<String, dynamic>?> createSocialRoom({required String name, required bool voice, int maxParticipants = 12}) =>
      _runValue(() async => (await api.post('/social/rooms', body: {'name': name, 'type': voice ? 'VOICE' : 'TEXT', 'visibility': 'PUBLIC', 'maxParticipants': maxParticipants}) as Map).cast<String, dynamic>());
  Future<Map<String, dynamic>?> getSocialRoom(String id) => _runValue(() async => (await api.get('/social/rooms/$id') as Map).cast<String, dynamic>());
  Future<Map<String, dynamic>?> joinSocialRoom(String id) => _runValue(() async => (await api.post('/social/rooms/$id/join') as Map).cast<String, dynamic>());
  Future<bool> leaveSocialRoom(String id) => _run(() async { await api.delete('/social/rooms/$id/leave'); await loadSocialRooms(); });
  Future<List<Map<String, dynamic>>> socialMessages(String id) async {
    final result = await _runValue(() async => await api.get('/social/rooms/$id/messages'));
    return result == null ? <Map<String,dynamic>>[] : _items(result);
  }
  Future<Map<String, dynamic>?> sendSocialMessage(String id, String text) => _runValue(() async => (await api.post('/social/rooms/$id/messages', body: {'text': text}) as Map).cast<String, dynamic>());
  Future<Map<String, dynamic>?> requestVoiceSession(String id) => _runValue(() async => (await api.post('/social/rooms/$id/voice-session') as Map).cast<String, dynamic>());

  Future<void> loadTournaments() async {
    final result = await _runValue(() async => await api.get('/tournaments'));
    if (result != null) { tournaments = _items(result); notifyListeners(); }
  }

  Future<Map<String, dynamic>?> tournamentDetails(String id) => _runValue(() async =>
      (await api.get('/tournaments/$id') as Map).cast<String, dynamic>());
  Future<bool> joinTournament(String id) => _run(() async { await api.post('/tournaments/$id/join'); await loadTournaments(); await refreshAll(); });
  Future<bool> withdrawTournament(String id) => _run(() async { await api.delete('/tournaments/$id/join'); await loadTournaments(); await refreshAll(); });

  Future<List<Map<String, dynamic>>> loadLeaderboard() async {
    final result = await _runValue(() async => await api.get('/engagement/leaderboard'));
    return result == null ? <Map<String,dynamic>>[] : _items(result);
  }

  Future<void> loadAchievements() async {
    final result = await _runValue(() async => await api.get('/engagement/achievements'));
    if (result != null) { achievements = _items(result); notifyListeners(); }
  }
  Future<bool> claimAchievement(String id) => _run(() async { await api.post('/engagement/achievements/$id/claim'); await loadAchievements(); await refreshAll(); });

  Future<Map<String, dynamic>?> loadReferralOverview() async {
    final result = await _runValue(() async => (await api.get('/engagement/referral') as Map).cast<String, dynamic>());
    if (result != null) { referralOverview = result; notifyListeners(); }
    return result;
  }
  Future<bool> applyReferralCode(String code) => _run(() async { await api.post('/engagement/referral/apply', body: {'code': code.trim()}); await loadReferralOverview(); await refreshAll(); });

  Future<Map<String, dynamic>?> loadPrivacySettings() async {
    final result = await _runValue(() async => (await api.get('/users/me/privacy') as Map).cast<String, dynamic>());
    if (result != null) { privacySettings = result; notifyListeners(); }
    return result;
  }
  Future<bool> savePrivacySettings({required bool showOnlineStatus, required bool allowDirectMessages, required bool allowInvites}) => _run(() async {
    privacySettings = (await api.patch('/users/me/privacy', body: {'showOnlineStatus': showOnlineStatus, 'allowDirectMessages': allowDirectMessages, 'allowInvites': allowInvites}) as Map).cast<String, dynamic>();
  });

  Future<Map<String, dynamic>?> loadIdentityVerification() async {
    final result = await _runValue(() async => (await api.get('/users/me/identity') as Map).cast<String, dynamic>());
    if (result != null) { identityVerification = result; notifyListeners(); }
    return result;
  }
  Future<bool> submitIdentity({
    required String legalName, required DateTime dateOfBirth, required String countryCode,
    required String documentFrontFileId, String? documentBackFileId, required String selfieFileId,
  }) => _run(() async {
    identityVerification = (await api.post('/users/me/identity', body: {
      'legalName': legalName.trim(),
      'dateOfBirth': dateOfBirth.toUtc().toIso8601String(),
      'countryCode': countryCode.trim().toUpperCase(),
      'documentFrontFileId': documentFrontFileId,
      if (documentBackFileId != null && documentBackFileId.isNotEmpty) 'documentBackFileId': documentBackFileId,
      'selfieFileId': selfieFileId,
    }) as Map).cast<String, dynamic>();
  });

  Future<void> loadSupportTickets() async {
    final result = await _runValue(() async => await api.get('/support/tickets'));
    if (result != null) { supportTickets = _items(result); notifyListeners(); }
  }
  Future<Map<String, dynamic>?> createSupportTicket({required String subject, required String category, required String message, int priority = 2}) => _runValue(() async {
    final result = (await api.post('/support/tickets', body: {'subject': subject.trim(), 'category': category, 'message': message.trim(), 'priority': priority}) as Map).cast<String, dynamic>();
    await loadSupportTickets();
    return result;
  });
  Future<Map<String, dynamic>?> supportTicket(String id) => _runValue(() async => (await api.get('/support/tickets/$id') as Map).cast<String, dynamic>());
  Future<bool> sendSupportMessage(String id, String text) => _run(() async { await api.post('/support/tickets/$id/messages', body: {'text': text.trim()}); });
  Future<bool> closeSupportTicket(String id) => _run(() async { await api.post('/support/tickets/$id/close'); await loadSupportTickets(); });

  Future<bool> markNotificationsRead() => _run(() async {
    await api.patch('/notifications/read-all');
    await refreshAll();
  });

  Future<bool> markNotificationRead(String id) => _run(() async {
    await api.patch('/notifications/$id/read');
    await refreshAll();
  });


  Future<void> _loadCatalog({required bool authenticated}) async {
    try {
      final result = await api.get(authenticated ? '/catalog/bootstrap' : '/catalog/public', authenticated: authenticated);
      if (result is Map) _applyCatalog(result.cast<String, dynamic>());
    } catch (_) {
      catalogItems = [];
      campaigns = [];
      levels = [];
      stages = [];
      paymentMethods = [];
      gameRules = [];
    }
  }

  void _applyCatalog(Map<String, dynamic> result) {
    catalogItems = _mapList(result['items']);
    campaigns = _mapList(result['campaigns']);
    levels = _mapList(result['levels']);
    stages = _mapList(result['stages']);
    paymentMethods = _mapList(result['paymentMethods']);
    gameRules = _mapList(result['rules']);
    inventory = _mapList(result['inventory']);
  }



  Map<String, dynamic>? nextLevelDefinition([int? level]) {
    final resolved = level ?? int.tryParse('${currentUser?['profile']?['level'] ?? 1}') ?? 1;
    for (final definition in levels) {
      final value = int.tryParse('${definition['level'] ?? 0}') ?? 0;
      if (value > resolved) return definition;
    }
    return null;
  }

  double levelProgress({int? level, int? xp}) {
    final resolvedLevel = level ?? int.tryParse('${currentUser?['profile']?['level'] ?? 1}') ?? 1;
    final resolvedXp = xp ?? int.tryParse('${currentUser?['profile']?['xp'] ?? 0}') ?? 0;
    Map<String, dynamic>? current;
    for (final definition in levels) {
      if ((int.tryParse('${definition['level'] ?? 0}') ?? 0) == resolvedLevel) {
        current = definition;
        break;
      }
    }
    final next = nextLevelDefinition(resolvedLevel);
    if (next == null) return 1;
    final startXp = int.tryParse('${current?['xpRequired'] ?? 0}') ?? 0;
    final endXp = int.tryParse('${next['xpRequired'] ?? startXp + 1}') ?? (startXp + 1);
    if (endXp <= startXp) return 1;
    return ((resolvedXp - startXp) / (endXp - startXp)).clamp(0, 1).toDouble();
  }

  Map<String, dynamic>? currentStage([int? level]) {
    final resolved = level ?? int.tryParse('${currentUser?['profile']?['level'] ?? 1}') ?? 1;
    for (final stage in stages) {
      final min = int.tryParse('${stage['minLevel'] ?? 1}') ?? 1;
      final rawMax = stage['maxLevel'];
      final max = rawMax == null ? null : int.tryParse('$rawMax');
      if (resolved >= min && (max == null || resolved <= max)) return stage;
    }
    return null;
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList();
  }

  Map<String, dynamic>? activeCampaign(String surface) {
    for (final campaign in campaigns) {
      if ('${campaign['surface']}' == surface && campaign['enabled'] != false) return campaign;
    }
    return null;
  }

  String _inventoryItemId(Map<String, dynamic> entry) {
    final item = entry['item'];
    return item is Map ? '${item['id'] ?? entry['itemId'] ?? ''}' : '${entry['itemId'] ?? ''}';
  }
  bool ownsItem(String itemId) => inventory.any((x) => _inventoryItemId(x) == itemId);
  bool isEquipped(String itemId) => inventory.any((x) => _inventoryItemId(x) == itemId && x['equipped'] == true);
  Map<String, dynamic>? equippedItem(String type) {
    for (final entry in inventory) {
      final item = entry['item'];
      if (entry['equipped'] == true && item is Map && '${item['type']}' == type) return item.cast<String, dynamic>();
    }
    for (final item in catalogItems) {
      if ('${item['type']}' == type && item['isDefault'] == true) return item;
    }
    return null;
  }

  Future<bool> purchaseCatalogItem(String itemId, {int quantity = 1}) => _run(() async {
    await api.post('/catalog/items/$itemId/purchase', body: {'quantity': quantity});
    await refreshAll();
  });

  Future<bool> equipCatalogItem(String itemId) => _run(() async {
    await api.post('/catalog/items/$itemId/equip');
    await refreshAll();
  });

  Future<void> _loadPublicSettings() async {
    try {
      publicSettings = (await api.get('/settings/public') as Map).cast<String, dynamic>();
    } catch (_) {
      publicSettings = {};
    }
  }

  void _applyWallet(Map<String, dynamic> result) {
    final balances = (result['balances'] as Map?)?.cast<String, dynamic>() ?? const {};
    walletBalance = _number(balances['cash']);
    withdrawableBalance = walletBalance;
    rewardBalance = _number(balances['bonus']);
    lockedBalance = _number(balances['locked']);
    coins = _number(balances['coins']).round();
    gems = _number(balances['gems']).round();
  }

  List<Map<String, dynamic>> _items(dynamic response) {
    final raw = response is Map ? response['items'] : response;
    if (raw is! List) return [];
    return raw.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList();
  }

  double _number(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

  Future<bool> _run(Future<void> Function() operation) async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } catch (error) {
      errorMessage = _message(error);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<T?> _runValue<T>(Future<T> Function() operation) async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await operation();
    } catch (error) {
      errorMessage = _message(error);
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String _message(Object error) {
    if (error is ApiException) {
      if (error.message == 'NETWORK_TIMEOUT') {
        return isArabic
            ? 'انتهت مهلة الاتصال بالخادم. تحقق من اتصال الإنترنت ثم أعد المحاولة.'
            : 'Server connection timed out. Check your internet connection and try again.';
      }
      if (error.message == 'NETWORK_UNREACHABLE') {
        return isArabic
            ? 'تعذر الوصول إلى الخادم. تحقق من اتصال الإنترنت وحاول مرة أخرى.'
            : 'Cannot reach the server. Check your internet connection and try again.';
      }
      return error.message;
    }
    return error.toString();
  }

  void _clearBalances() {
    walletBalance = 0;
    withdrawableBalance = 0;
    rewardBalance = 0;
    lockedBalance = 0;
    coins = 0;
    gems = 0;
  }

  void toggleMusic(bool value) { musicEnabled = value; notifyListeners(); }
  Future<void> toggleEffects(bool value) async { effectsEnabled = value; notifyListeners(); await session.setEffectsEnabled(value); }
  Future<void> toggleVibration(bool value) async { vibrationEnabled = value; notifyListeners(); await session.setVibrationEnabled(value); }

  Future<void> interactionFeedback({bool strong = false}) async {
    if (effectsEnabled) await SystemSound.play(SystemSoundType.click);
    if (vibrationEnabled) {
      if (strong) { await HapticFeedback.mediumImpact(); } else { await HapticFeedback.selectionClick(); }
    }
  }


}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);
  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }
}
