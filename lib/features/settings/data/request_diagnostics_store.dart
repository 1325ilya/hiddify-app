import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'device_identity_service.dart';

class RequestDiagnosticEntry {
  final String id;
  final DateTime timestamp;
  final String method;
  final String url;
  final String host;
  final String path;
  final String category;
  final Map<String, String> headers;
  final String? body;
  final bool overrideApplied;
  final bool allowlistWarning;
  final String appliedClient;
  final String appliedHwid;

  RequestDiagnosticEntry({
    required this.id,
    required this.timestamp,
    required this.method,
    required this.url,
    required this.host,
    required this.path,
    required this.category,
    required this.headers,
    this.body,
    required this.overrideApplied,
    required this.allowlistWarning,
    required this.appliedClient,
    required this.appliedHwid,
  });

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "timestamp": timestamp.toIso8601String(),
      "method": method,
      "url": url,
      "host": host,
      "path": path,
      "category": category,
      "headers": headers,
      "body": body,
      "overrideApplied": overrideApplied,
      "allowlistWarning": allowlistWarning,
      "appliedClient": appliedClient,
      "appliedHwid": appliedHwid,
    };
  }
}

class RequestDiagnosticsStore extends StateNotifier<List<RequestDiagnosticEntry>> {
  RequestDiagnosticsStore() : super([]);

  static const maxEntries = 50;

  void addEntry(RequestDiagnosticEntry entry) {
    final newList = List<RequestDiagnosticEntry>.from(state);
    newList.insert(0, entry);
    if (newList.length > maxEntries) {
      newList.removeRange(maxEntries, newList.length);
    }
    state = newList;
  }

  void clear() {
    state = [];
  }
}

final requestDiagnosticsProvider = StateNotifierProvider<RequestDiagnosticsStore, List<RequestDiagnosticEntry>>((ref) {
  return RequestDiagnosticsStore();
});

String maskToken(String value) {
  if (value.length <= 6) return "***";
  return "${value.substring(0, 3)}...${value.substring(value.length - 3)}";
}

String maskUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final maskedParams = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      final k = key.toLowerCase();
      if (k.contains("token") || 
          k.contains("pass") || 
          k.contains("key") ||
          k.contains("secret") ||
          k.contains("auth") ||
          k.contains("password")) {
        maskedParams[key] = maskToken(value);
      } else {
        maskedParams[key] = value;
      }
    });
    
    final pathSegments = uri.pathSegments.map((segment) {
      if (segment.length > 20 || RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}').hasMatch(segment)) {
        return maskToken(segment);
      }
      return segment;
    }).toList();
    
    final newUri = uri.replace(
      pathSegments: pathSegments,
      queryParameters: maskedParams.isEmpty ? null : maskedParams,
      userInfo: uri.userInfo.isNotEmpty ? "user:***" : "",
    );
    return newUri.toString();
  } catch (_) {
    return url;
  }
}

Map<String, String> maskHeaders(Map<String, dynamic> headers) {
  final masked = <String, String>{};
  headers.forEach((key, value) {
    final k = key.toLowerCase();
    final valStr = value.toString();
    if (k == 'authorization' || k == 'proxy-authorization') {
      masked[key] = maskToken(valStr);
    } else if (k == 'user-agent') {
      masked[key] = valStr;
    } else if (k == 'subscription-userinfo' || k == 'profile-title') {
      masked[key] = maskToken(valStr);
    } else if (k.contains("key") || k.contains("token") || k.contains("secret")) {
      masked[key] = maskToken(valStr);
    } else {
      masked[key] = valStr;
    }
  });
  return masked;
}

String getRequestCategory(String path, String url) {
  final p = path.toLowerCase();
  final u = url.toLowerCase();
  if (p.contains("sub") || p.contains("profile") || u.contains("subscription")) {
    return "Subscription";
  }
  if (p.contains("update") || p.contains("app-update")) {
    return "App Update";
  }
  if (p.contains("config") || p.contains("settings")) {
    return "Config/Settings";
  }
  if (p.contains("auth") || p.contains("login") || p.contains("token")) {
    return "Auth";
  }
  return "General API";
}

class RequestDiagnosticsInterceptor extends Interceptor {
  final Ref _ref;

  RequestDiagnosticsInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final identityState = _ref.read(deviceIdentityServiceProvider);

    bool overrideApplied = false;
    bool allowlistWarning = false;
    String appliedClient = "Hiddify";
    String appliedHwid = "";

    if (identityState.enableOverride) {
      final host = options.uri.host;
      final isAllowed = _isHostAllowed(host, identityState.allowedDomains, identityState.allowAllDomains);

      if (isAllowed) {
        overrideApplied = true;
        appliedClient = identityState.customClientName;
        appliedHwid = identityState.testAppInstanceId;

        // Apply overrides
        // 1. Override Client/User-Agent
        final appInfoVal = _ref.read(appInfoProvider).value;
        final appVersion = appInfoVal?.version ?? "4.1.2";
        final osName = appInfoVal?.operatingSystem ?? (Platform.isIOS ? "iOS" : "android");
        final newUserAgent = "$appliedClient/$appVersion ($osName) like ClashMeta v2ray sing-box";
        options.headers["User-Agent"] = newUserAgent;

        // 2. Override HWID/Device ID header if custom HWID is provided
        if (appliedHwid.isNotEmpty) {
          options.headers["X-HAPP-Hardware-ID"] = appliedHwid;
          options.headers["X-Hardware-ID"] = appliedHwid;
          options.headers["X-HWID"] = appliedHwid;
          options.headers["X-Client-Name"] = appliedClient;
        }
      } else {
        allowlistWarning = true;
      }
    }

    final timestamp = DateTime.now();
    final path = options.uri.path;
    final url = options.uri.toString();
    final category = getRequestCategory(path, url);

    final entry = RequestDiagnosticEntry(
      id: const Uuid().v4(),
      timestamp: timestamp,
      method: options.method,
      url: maskUrl(url),
      host: options.uri.host,
      path: path,
      category: category,
      headers: maskHeaders(options.headers),
      body: options.data != null ? maskBody(options.data) : null,
      overrideApplied: overrideApplied,
      allowlistWarning: allowlistWarning,
      appliedClient: appliedClient,
      appliedHwid: appliedHwid,
    );

    _ref.read(requestDiagnosticsProvider.notifier).addEntry(entry);

    super.onRequest(options, handler);
  }

  bool _isHostAllowed(String host, List<String> allowedDomains, bool allowAll) {
    if (allowAll) return true;
    final h = host.toLowerCase();
    if (h == 'localhost' || h == '127.0.0.1' || h.endsWith('.local')) {
      return true;
    }
    for (final domain in allowedDomains) {
      final d = domain.trim().toLowerCase();
      if (d.isEmpty) continue;
      if (d.startsWith('*.')) {
        final suffix = d.substring(2);
        if (h == suffix || h.endsWith('.$suffix')) return true;
      } else {
        if (h == d || h.endsWith('.$d')) return true;
      }
    }
    return false;
  }

  String maskBody(dynamic data) {
    try {
      final str = data.toString();
      if (str.length > 500) {
        return "${str.substring(0, 100)}... [Truncated due to size]";
      }
      return str;
    } catch (_) {
      return "[Unreadable body]";
    }
  }
}
