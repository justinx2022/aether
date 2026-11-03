import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/storage_service.dart';

enum PassTier {
  weekly('Weekly Pass', 50, Duration(days: 7), 'KES 50 / week (Impulse)'),
  monthly('Monthly Pass', 150, Duration(days: 30), 'KES 150 / month (⭐ Best Value)'),
  semester('Semester Pass', 400, Duration(days: 120), 'KES 400 / semester (4 Months)');

  final String title;
  final int priceKes;
  final Duration duration;
  final String subtitle;

  const PassTier(this.title, this.priceKes, this.duration, this.subtitle);
}

class VipPass {
  final PassTier tier;
  final DateTime startsAt;
  final DateTime expiresAt;
  final String mpesaReceipt;
  final String phoneNumber;
  final bool isTestPass;

  const VipPass({
    required this.tier,
    required this.startsAt,
    required this.expiresAt,
    required this.mpesaReceipt,
    required this.phoneNumber,
    this.isTestPass = false,
  });

  bool get isValid => DateTime.now().isBefore(expiresAt);

  Duration get remaining =>
      expiresAt.isAfter(DateTime.now())
          ? expiresAt.difference(DateTime.now())
          : Duration.zero;

  String get remainingFormatted {
    final d = remaining.inDays;
    if (d > 0) return '$d day${d > 1 ? 's' : ''} left';
    final h = remaining.inHours;
    if (h > 0) return '$h hour${h > 1 ? 's' : ''} left';
    final m = remaining.inMinutes;
    return '$m min${m > 1 ? 's' : ''} left';
  }

  Map<String, dynamic> toMap() {
    return {
      'tier': tier.name,
      'startsAt': startsAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'mpesaReceipt': mpesaReceipt,
      'phoneNumber': phoneNumber,
      'isTestPass': isTestPass,
    };
  }

  factory VipPass.fromMap(Map<String, dynamic> map) {
    final tierName = map['tier'] as String? ?? 'monthly';
    final tier = PassTier.values.firstWhere(
      (t) => t.name == tierName,
      orElse: () => PassTier.monthly,
    );
    return VipPass(
      tier: tier,
      startsAt: DateTime.tryParse(map['startsAt'] as String? ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(map['expiresAt'] as String? ?? '') ??
          DateTime.now().add(tier.duration),
      mpesaReceipt: map['mpesaReceipt'] as String? ?? 'TEST_MOCK_RECEIPT',
      phoneNumber: map['phoneNumber'] as String? ?? '254700000000',
      isTestPass: map['isTestPass'] as bool? ?? false,
    );
  }
}

class PassState {
  final bool isVip;
  final bool isTrial;
  final Duration trialRemaining;
  final VipPass? activePass;
  final bool isSandboxMode;

  const PassState({
    required this.isVip,
    required this.isTrial,
    required this.trialRemaining,
    this.activePass,
    this.isSandboxMode = true,
  });

  PassState copyWith({
    bool? isVip,
    bool? isTrial,
    Duration? trialRemaining,
    VipPass? activePass,
    bool? isSandboxMode,
  }) {
    return PassState(
      isVip: isVip ?? this.isVip,
      isTrial: isTrial ?? this.isTrial,
      trialRemaining: trialRemaining ?? this.trialRemaining,
      activePass: activePass ?? this.activePass,
      isSandboxMode: isSandboxMode ?? this.isSandboxMode,
    );
  }
}

final passControllerProvider =
    NotifierProvider<PassController, PassState>(PassController.new);

class PassController extends Notifier<PassState> {
  static const String _kFirstLaunchKey = 'monetization_first_launch_timestamp';
  static const String _kPassDataKey = 'monetization_active_pass_v1';
  static const String _kSandboxModeKey = 'monetization_sandbox_mode';

  @override
  PassState build() {
    return _computeState();
  }

  StorageService get _storage => ref.read(storageServiceProvider);

  PassState _computeState() {
    final now = DateTime.now();

    // 1. Check/initialize 3-day trial
    final firstLaunchRaw = _storage.getString(_kFirstLaunchKey);
    int? firstLaunchMillis = firstLaunchRaw != null ? int.tryParse(firstLaunchRaw) : null;
    if (firstLaunchMillis == null) {
      firstLaunchMillis = now.millisecondsSinceEpoch;
      _storage.setString(_kFirstLaunchKey, firstLaunchMillis.toString());
    }

    final firstLaunchDate = DateTime.fromMillisecondsSinceEpoch(firstLaunchMillis);
    final trialEndDate = firstLaunchDate.add(const Duration(days: 3));
    final isTrialActive = now.isBefore(trialEndDate);
    final trialRemaining =
        isTrialActive ? trialEndDate.difference(now) : Duration.zero;

    // 2. Check active paid / test pass
    final passRaw = _storage.getString(_kPassDataKey);
    VipPass? activePass;
    if (passRaw != null && passRaw.isNotEmpty) {
      try {
        final decoded = json.decode(passRaw) as Map<String, dynamic>;
        final pass = VipPass.fromMap(decoded);
        if (pass.isValid) {
          activePass = pass;
        }
      } catch (_) {}
    }

    final sandboxRaw = _storage.getString(_kSandboxModeKey);
    final isSandbox = sandboxRaw != null ? sandboxRaw == 'true' : true;
    final isVip = isTrialActive || (activePass != null && activePass.isValid);

    return PassState(
      isVip: isVip,
      isTrial: isTrialActive && (activePass == null),
      trialRemaining: trialRemaining,
      activePass: activePass,
      isSandboxMode: isSandbox,
    );
  }

  void toggleSandboxMode(bool enabled) {
    _storage.setString(_kSandboxModeKey, enabled.toString());
    state = state.copyWith(isSandboxMode: enabled);
  }

  /// Activate a test pass for testing without charging M-PESA.
  Future<void> activateTestPass(PassTier tier, {String phone = '254712345678'}) async {
    final now = DateTime.now();
    final pass = VipPass(
      tier: tier,
      startsAt: now,
      expiresAt: now.add(tier.duration),
      mpesaReceipt: 'DEMO_${DateTime.now().millisecondsSinceEpoch}',
      phoneNumber: phone,
      isTestPass: true,
    );

    await _storage.setString(_kPassDataKey, json.encode(pass.toMap()));

    state = state.copyWith(
      isVip: true,
      isTrial: false,
      activePass: pass,
    );
  }

  /// Simulate or execute real Daraja STK Push payment.
  Future<({bool success, String message})> requestMpesaPayment({
    required String phoneNumber,
    required PassTier tier,
    bool isDemo = true,
  }) async {
    var cleanedPhone = phoneNumber.replaceAll(RegExp(r'\s+|-|\+'), '');
    if (cleanedPhone.startsWith('0')) {
      cleanedPhone = '254${cleanedPhone.substring(1)}';
    } else if (!cleanedPhone.startsWith('254')) {
      cleanedPhone = '254$cleanedPhone';
    }

    if (cleanedPhone.length != 12) {
      return (
        success: false,
        message: 'Invalid Safaricom phone number. Format: 07XX... or 01XX...'
      );
    }

    if (isDemo || state.isSandboxMode) {
      // Simulate realistic network round-trip + user PIN entry
      await Future<void>.delayed(const Duration(seconds: 2));
      await activateTestPass(tier, phone: cleanedPhone);
      return (
        success: true,
        message: 'Test M-PESA payment simulated successfully! VIP Pass active.'
      );
    }

    return (
      success: false,
      message: 'Live Daraja backend endpoint not configured yet. Use Sandbox Demo.'
    );
  }

  Future<void> clearPass() async {
    await _storage.remove(_kPassDataKey);
    state = _computeState();
  }
}
