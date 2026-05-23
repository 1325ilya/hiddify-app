import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentityState {
  final bool enableOverride;
  final bool allowAllDomains;
  final String testDeviceId;
  final String testModel;
  final String testAppInstanceId;
  final String customClientName;
  final List<String> allowedDomains;
  final Map<String, dynamic> realIdentity;
  final bool isLoading;

  DeviceIdentityState({
    required this.enableOverride,
    required this.allowAllDomains,
    required this.testDeviceId,
    required this.testModel,
    required this.testAppInstanceId,
    required this.customClientName,
    required this.allowedDomains,
    required this.realIdentity,
    required this.isLoading,
  });

  DeviceIdentityState copyWith({
    bool? enableOverride,
    bool? allowAllDomains,
    String? testDeviceId,
    String? testModel,
    String? testAppInstanceId,
    String? customClientName,
    List<String>? allowedDomains,
    Map<String, dynamic>? realIdentity,
    bool? isLoading,
  }) {
    return DeviceIdentityState(
      enableOverride: enableOverride ?? this.enableOverride,
      allowAllDomains: allowAllDomains ?? this.allowAllDomains,
      testDeviceId: testDeviceId ?? this.testDeviceId,
      testModel: testModel ?? this.testModel,
      testAppInstanceId: testAppInstanceId ?? this.testAppInstanceId,
      customClientName: customClientName ?? this.customClientName,
      allowedDomains: allowedDomains ?? this.allowedDomains,
      realIdentity: realIdentity ?? this.realIdentity,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DeviceIdentityService extends StateNotifier<DeviceIdentityState> {
  final SharedPreferences _prefs;
  static const _channel = MethodChannel("com.hiddify.app/device_identity");

  DeviceIdentityService(this._prefs)
      : super(DeviceIdentityState(
          enableOverride: _prefs.getBool("di_enable_override") ?? false,
          allowAllDomains: _prefs.getBool("di_allow_all_domains") ?? false,
          testDeviceId: _prefs.getString("di_test_device_id") ?? "",
          testModel: _prefs.getString("di_test_model") ?? "",
          testAppInstanceId: _prefs.getString("di_test_app_instance_id") ?? "",
          customClientName: _prefs.getString("di_custom_client_name") ?? "HAPP",
          allowedDomains: _prefs.getStringList("di_allowed_domains") ?? ["localhost", "127.0.0.1", "local"],
          realIdentity: {},
          isLoading: true,
        )) {
    loadRealIdentity();
  }

  Future<void> loadRealIdentity() async {
    state = state.copyWith(isLoading: true);
    final identity = await _fetchRealIdentity();
    state = state.copyWith(realIdentity: identity, isLoading: false);
  }

  Future<Map<String, dynamic>> _fetchRealIdentity() async {
    if (!Platform.isIOS) {
      return {
        "bundleId": "com.hiddify.app.mock",
        "appVersion": "4.1.2",
        "appBuild": "40102",
        "teamId": "MOCKTEAMID1",
        "model": "iPhone Mock",
        "systemName": "iOS",
        "systemVersion": "17.4",
        "localizedModel": "iPhone",
        "deviceName": "Mock iPhone",
        "idfv": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
        "keychainAppInstanceId": "A1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6D",
        "installUuid": "F1E2D3C4-B5A6-9788-7766-554433221100",
        "appAttestSupported": true,
      };
    }
    try {
      final result = await _channel.invokeMethod<Map>("get_device_identity");
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } catch (e) {
      // Failed to invoke native side
    }
    return {};
  }

  Future<void> setEnableOverride(bool value) async {
    await _prefs.setBool("di_enable_override", value);
    state = state.copyWith(enableOverride: value);
  }

  Future<void> setAllowAllDomains(bool value) async {
    await _prefs.setBool("di_allow_all_domains", value);
    state = state.copyWith(allowAllDomains: value);
  }

  Future<void> setTestDeviceId(String value) async {
    await _prefs.setString("di_test_device_id", value);
    state = state.copyWith(testDeviceId: value);
  }

  Future<void> setTestModel(String value) async {
    await _prefs.setString("di_test_model", value);
    state = state.copyWith(testModel: value);
  }

  Future<void> setTestAppInstanceId(String value) async {
    await _prefs.setString("di_test_app_instance_id", value);
    state = state.copyWith(testAppInstanceId: value);
  }

  Future<void> setCustomClientName(String value) async {
    await _prefs.setString("di_custom_client_name", value);
    state = state.copyWith(customClientName: value);
  }

  Future<void> addAllowedDomain(String domain) async {
    final clean = domain.trim().toLowerCase();
    if (clean.isEmpty || state.allowedDomains.contains(clean)) return;
    final newList = List<String>.from(state.allowedDomains)..add(clean);
    await _prefs.setStringList("di_allowed_domains", newList);
    state = state.copyWith(allowedDomains: newList);
  }

  Future<void> removeAllowedDomain(String domain) async {
    final newList = List<String>.from(state.allowedDomains)..remove(domain);
    await _prefs.setStringList("di_allowed_domains", newList);
    state = state.copyWith(allowedDomains: newList);
  }

  Future<void> generateRandomFakeIdentity() async {
    final fakeId = const Uuid().v4().toUpperCase();
    final fakeInstanceId = const Uuid().v4().toUpperCase();
    const fakeModels = ["iPhone15,3", "iPhone16,1", "iPad14,5", "iPhone15,2"];
    final fakeModel = (List.from(fakeModels)..shuffle()).first;

    await setTestDeviceId(fakeId);
    await setTestModel(fakeModel);
    await setTestAppInstanceId(fakeInstanceId);
    await setCustomClientName("HAPP");
  }

  Future<void> resetToRealValues() async {
    await setTestDeviceId(state.realIdentity["idfv"] ?? "");
    await setTestModel(state.realIdentity["model"] ?? "");
    await setTestAppInstanceId(state.realIdentity["keychainAppInstanceId"] ?? "");
    await setCustomClientName("HAPP");
  }
}

final deviceIdentityServiceProvider = StateNotifierProvider<DeviceIdentityService, DeviceIdentityState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).requireValue;
  return DeviceIdentityService(prefs);
});
