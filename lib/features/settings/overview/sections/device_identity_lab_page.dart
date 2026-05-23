import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hiddify/features/settings/data/device_identity_service.dart';
import 'package:hiddify/features/settings/data/request_diagnostics_store.dart';
import 'package:share_plus/share_plus.dart';

class DeviceIdentityLabPage extends HookConsumerWidget {
  const DeviceIdentityLabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final service = ref.watch(deviceIdentityServiceProvider);
    final serviceNotifier = ref.read(deviceIdentityServiceProvider.notifier);
    final diagnostics = ref.watch(requestDiagnosticsProvider);
    final diagnosticsNotifier = ref.read(requestDiagnosticsProvider.notifier);

    // Robust Text Controllers using Hooks to prevent cursor jumping
    final testDeviceIdController = useTextEditingController(text: service.testDeviceId);
    final testModelController = useTextEditingController(text: service.testModel);
    final testAppInstanceIdController = useTextEditingController(text: service.testAppInstanceId);
    final customClientNameController = useTextEditingController(text: service.customClientName);
    final allowedController = useTextEditingController();

    // Active Category Filter for Logs
    final selectedCategory = useState<String?>("All");

    // Sync controllers when service updates from external action (Reset or Randomize)
    useEffect(() {
      if (testDeviceIdController.text != service.testDeviceId) {
        testDeviceIdController.text = service.testDeviceId;
      }
      if (testModelController.text != service.testModel) {
        testModelController.text = service.testModel;
      }
      if (testAppInstanceIdController.text != service.testAppInstanceId) {
        testAppInstanceIdController.text = service.testAppInstanceId;
      }
      if (customClientNameController.text != service.customClientName) {
        customClientNameController.text = service.customClientName;
      }
      return null;
    }, [service.testDeviceId, service.testModel, service.testAppInstanceId, service.customClientName]);

    final real = service.realIdentity;
    final isLoading = service.isLoading;

    // Filter diagnostics
    final filteredDiagnostics = diagnostics.where((e) {
      if (selectedCategory.value == "All") return true;
      return e.category == selectedCategory.value;
    }).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.brightness == Brightness.dark 
          ? const Color(0xFF0F0F1A) 
          : const Color(0xFFF6F6FA),
      appBar: AppBar(
        title: const Text(
          "Device Identity Lab",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Export Diagnostic Report",
            icon: Icon(Icons.ios_share_rounded, color: theme.colorScheme.primary),
            onPressed: () => _exportReport(context, service, diagnostics),
          ),
          IconButton(
            tooltip: "Clear Logs",
            icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
            onPressed: () => diagnosticsNotifier.clear(),
          ),
          const Gap(8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                // 1. GORGEOUS STATUS SHIELD AT THE TOP
                _buildGlowingStatusShield(context, service.enableOverride, service.allowAllDomains),
                const Gap(24),

                // 2. MAIN APP INFO - GLASSMORPHIC CARD
                _buildGlassmorphicCard(
                  context,
                  title: "Application Environment",
                  icon: Icons.layers_outlined,
                  colors: [const Color(0xFF1E3C72), const Color(0xFF2A5298)],
                  items: {
                    "Bundle Identifier": real["bundleId"]?.toString() ?? "Loading...",
                    "App Version": real["appVersion"]?.toString() ?? "Loading...",
                    "Build Number": real["appBuild"]?.toString() ?? "Loading...",
                    "Team Signature": real["teamId"]?.toString() ?? "Legal/Standard",
                  },
                ),
                const Gap(16),

                // 3. DEVICE & HARDWARE - GLASSMORPHIC CARD
                _buildGlassmorphicCard(
                  context,
                  title: "Platform Hardware",
                  icon: Icons.developer_board_rounded,
                  colors: [const Color(0xFF9C27B0), const Color(0xFFE040FB)],
                  items: {
                    "Hardware Model": real["model"]?.toString() ?? "Loading...",
                    "OS Platform": real["systemName"]?.toString() ?? "Loading...",
                    "OS Version": real["systemVersion"]?.toString() ?? "Loading...",
                    "User Assigned Name": real["deviceName"]?.toString() ?? "Standard iPhone",
                  },
                ),
                const Gap(16),

                // 4. INSTANCE IDENTIFIERS - GLASSMORPHIC CARD
                _buildGlassmorphicCard(
                  context,
                  title: "Cryptographic Identifiers",
                  icon: Icons.fingerprint_rounded,
                  colors: [const Color(0xFF00B4DB), const Color(0xFF0083B0)],
                  items: {
                    "Identifier For Vendor (IDFV)": real["idfv"]?.toString() ?? "Loading...",
                    "Keychain Instance ID (HWID)": real["keychainAppInstanceId"]?.toString() ?? "Loading...",
                    "Install UUID": real["installUuid"]?.toString() ?? "Loading...",
                    "App Attest Support": real["appAttestSupported"] == true ? "Attestation Active" : "Hardware Not Supported",
                  },
                ),
                const Gap(24),

                // 5. TEST IDENTITY CONTROL PANEL
                _buildControlPanel(
                  context,
                  service: service,
                  serviceNotifier: serviceNotifier,
                  testDeviceIdController: testDeviceIdController,
                  testModelController: testModelController,
                  testAppInstanceIdController: testAppInstanceIdController,
                  customClientNameController: customClientNameController,
                  allowedController: allowedController,
                ),
                const Gap(24),

                // 6. OUTGOING TELEMETRY LOGS
                _buildDiagnosticsTelemetry(
                  context,
                  diagnostics: filteredDiagnostics,
                  selectedCategory: selectedCategory,
                  diagnosticsNotifier: diagnosticsNotifier,
                ),
              ],
            ),
    );
  }

  // STATUS INDICATOR WITH NEON RADIANCE
  Widget _buildGlowingStatusShield(BuildContext context, bool isActive, bool allowAll) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;
    
    final glowColor = isActive 
        ? (allowAll ? Colors.red.shade400 : Colors.green.shade400) 
        : Colors.blue.shade400;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151528) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: glowColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: glowColor.withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              isActive 
                  ? (allowAll ? Icons.gavel_rounded : Icons.shield_rounded) 
                  : Icons.shield_outlined,
              color: glowColor,
              size: 42,
            ),
          ),
          const Gap(16),
          Text(
            isActive 
                ? (allowAll ? "ACTIVE: OVERRIDE ALL DOMAINS" : "ACTIVE: FILTERED BY ALLOWLIST") 
                : "PROTECTED: REAL APP IDENTITY",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: glowColor,
            ),
          ),
          const Gap(6),
          Text(
            isActive 
                ? (allowAll 
                    ? "Overrides are sent to all public & production subscription providers." 
                    : "Overrides are active ONLY on allowed local & staging hosts.")
                : "Standard iOS identifiers and Hiddify User-Agents are being safely used.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // PREMIUM GLASSMORPHIC CARD DESIGN
  Widget _buildGlassmorphicCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Color> colors,
    required Map<String, String> items,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colors.first.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.first.withOpacity(0.08),
              colors.last.withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(colors: colors).createShader(bounds),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const Gap(12),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const Gap(16),
              ...items.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 7,
                        child: InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: entry.value));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Copied ${entry.key}"),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(milliseconds: 700),
                              ),
                            );
                          },
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white.withOpacity(0.85) : Colors.black87,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // PREMIUM CONTROL PANEL (FIXED JUMPING CURSOR BUGS)
  Widget _buildControlPanel(
    BuildContext context, {
    required DeviceIdentityState service,
    required DeviceIdentityService serviceNotifier,
    required TextEditingController testDeviceIdController,
    required TextEditingController testModelController,
    required TextEditingController testAppInstanceIdController,
    required TextEditingController customClientNameController,
    required TextEditingController allowedController,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.primary.withOpacity(0.12),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, color: theme.colorScheme.primary, size: 22),
                const Gap(12),
                Text(
                  "Configure Lab Simulator",
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text("Simulated Identity Mode", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text("Apply overrides dynamically in HTTP payloads"),
              value: service.enableOverride,
              onChanged: serviceNotifier.setEnableOverride,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text("Allow All Connections", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text("Inject custom headers to production providers"),
              value: service.allowAllDomains,
              onChanged: serviceNotifier.setAllowAllDomains,
            ),
            if (service.enableOverride) ...[
              const Gap(12),
              // NO JUMPING CURSORS & CLEAN PREMIUM FIELDS
              _buildModernTextField(
                context,
                label: "Simulated Device ID (IDFV Mock)",
                controller: testDeviceIdController,
                icon: Icons.phone_iphone_rounded,
                onChanged: serviceNotifier.setTestDeviceId,
              ),
              const Gap(12),
              _buildModernTextField(
                context,
                label: "Simulated Hardware Model",
                controller: testModelController,
                icon: Icons.devices_other_rounded,
                onChanged: serviceNotifier.setTestModel,
              ),
              const Gap(12),
              _buildModernTextField(
                context,
                label: "Simulated App Instance ID (HWID Mock)",
                controller: testAppInstanceIdController,
                icon: Icons.fingerprint_rounded,
                onChanged: serviceNotifier.setTestAppInstanceId,
              ),
              const Gap(12),
              _buildModernTextField(
                context,
                label: "Simulated VPN Client Name",
                controller: customClientNameController,
                icon: Icons.vpn_lock_rounded,
                onChanged: serviceNotifier.setCustomClientName,
              ),
              if (!service.allowAllDomains) ...[
                const Gap(20),
                Text(
                  "Target Domains Filter (Allowlist)",
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Gap(8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: allowedController,
                        decoration: InputDecoration(
                          hintText: "staging-provider.com",
                          prefixIcon: const Icon(Icons.public_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ),
                    const Gap(8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () {
                        if (allowedController.text.isNotEmpty) {
                          serviceNotifier.addAllowedDomain(allowedController.text);
                          allowedController.clear();
                        }
                      },
                      child: const Text("Add"),
                    ),
                  ],
                ),
                const Gap(8),
                Wrap(
                  spacing: 8,
                  children: service.allowedDomains.map((domain) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: InputChip(
                        label: Text(domain),
                        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.06),
                        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.12)),
                        deleteIcon: const Icon(Icons.cancel_rounded, size: 16),
                        onDeleted: () => serviceNotifier.removeAllowedDomain(domain),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const Gap(16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => serviceNotifier.generateRandomFakeIdentity(),
                      icon: const Icon(Icons.shuffle_rounded, size: 16),
                      label: const Text("Randomize Mock"),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => serviceNotifier.resetToRealValues(),
                      icon: const Icon(Icons.settings_backup_restore_rounded, size: 16),
                      label: const Text("Restore Real"),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // MODERN TEXT FIELD STYLING
  Widget _buildModernTextField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Function(String) onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: theme.colorScheme.primary.withOpacity(0.7)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  // PREMIUM DIAGNOSTICS & TELEMETRY TERMINAL WITH FILTER CHIPS
  Widget _buildDiagnosticsTelemetry(
    BuildContext context, {
    required List<RequestDiagnosticEntry> diagnostics,
    required ValueNotifier<String?> selectedCategory,
    required RequestDiagnosticsStore diagnosticsNotifier,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.primary.withOpacity(0.12),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.terminal_rounded, color: theme.colorScheme.primary, size: 22),
                    const Gap(12),
                    Text(
                      "Diagnostics Console",
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${diagnostics.length} entries",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: ["All", "Subscription", "App Update", "Config/Settings", "Auth", "General API"].map((cat) {
                  final isSelected = selectedCategory.value == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0, bottom: 8.0),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(cat),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black87),
                      ),
                      selectedColor: theme.colorScheme.primary,
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onSelected: (_) => selectedCategory.value = cat,
                    ),
                  );
                }).toList(),
              ),
            ),
            const Gap(8),
            if (diagnostics.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    "Console is clean. Trigger network activity to view telemetry.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: diagnostics.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final entry = diagnostics[index];
                  return _buildDeveloperDiagnosticTile(context, entry);
                },
              ),
          ],
        ),
      ),
    );
  }

  // GORGEOUS EXPANDABLE TILE DEVELOPER STYLE
  Widget _buildDeveloperDiagnosticTile(BuildContext context, RequestDiagnosticEntry entry) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;

    final badgeColor = entry.overrideApplied
        ? Colors.green.shade500
        : entry.allowlistWarning
            ? Colors.orange.shade500
            : Colors.blueGrey.shade500;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          entry.overrideApplied
              ? Icons.check_circle_rounded
              : entry.allowlistWarning
                  ? Icons.warning_rounded
                  : Icons.info_rounded,
          color: badgeColor,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.method,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const Gap(8),
          Expanded(
            child: Text(
              entry.host,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Text(
              entry.category,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary),
            ),
            const Spacer(),
            Text(
              "${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}",
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConsoleRow("Request URL", entry.url),
              _buildConsoleRow("Request Path", entry.path),
              _buildConsoleRow(
                "Lab Override",
                entry.overrideApplied
                    ? "Injected (HWID + UserAgent Overridden)"
                    : entry.allowlistWarning
                        ? "Ignored (Endpoint Not In Staging Allowlist)"
                        : "Bypassed (Overrides Disabled)",
                valueColor: entry.overrideApplied
                    ? Colors.green.shade600
                    : entry.allowlistWarning
                        ? Colors.orange.shade600
                        : null,
              ),
              if (entry.overrideApplied) ...[
                _buildConsoleRow("Spoofed Agent", entry.headers["User-Agent"] ?? "N/A"),
                _buildConsoleRow("Spoofed HWID", entry.appliedHwid),
              ],
              const Gap(12),
              const Text("Request Headers", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.blueGrey)),
              const Gap(6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F0F1A) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entry.headers.entries.map((header) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 11, 
                            fontFamily: 'monospace',
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          children: [
                            TextSpan(text: "${header.key}: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            TextSpan(text: header.value),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (entry.body != null) ...[
                const Gap(12),
                const Text("Payload Body", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.blueGrey)),
                const Gap(6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F0F1A) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                  ),
                  child: Text(
                    entry.body!,
                    style: TextStyle(
                      fontSize: 11, 
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConsoleRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              "$label:",
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
          ),
          Expanded(
            flex: 8,
            child: Text(
              value,
              style: TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: valueColor ?? Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  // EXPORT UTILITY
  void _exportReport(
    BuildContext context,
    DeviceIdentityState service,
    List<RequestDiagnosticEntry> diagnostics,
  ) {
    final report = {
      "exported_at": DateTime.now().toIso8601String(),
      "device_identity": {
        "bundle_id": service.realIdentity["bundleId"],
        "app_version": service.realIdentity["appVersion"],
        "app_build": service.realIdentity["appBuild"],
        "model": service.realIdentity["model"],
        "system_name": service.realIdentity["systemName"],
        "system_version": service.realIdentity["systemVersion"],
        "idfv_masked": maskToken(service.realIdentity["idfv"]?.toString() ?? ""),
        "keychain_id_masked": maskToken(service.realIdentity["keychainAppInstanceId"]?.toString() ?? ""),
        "install_uuid_masked": maskToken(service.realIdentity["installUuid"]?.toString() ?? ""),
      },
      "override_settings": {
        "active": service.enableOverride,
        "allow_all_domains": service.allowAllDomains,
        "custom_client": service.customClientName,
        "allowed_domains": service.allowedDomains,
      },
      "logged_requests": diagnostics.map((e) => e.toJson()).toList(),
    };

    final encoder = const JsonEncoder.withIndent("  ");
    final reportText = encoder.convert(report);

    Share.share(
      reportText,
      subject: "Hiddify Device Identity Lab Diagnostic Report",
    );
  }
}
