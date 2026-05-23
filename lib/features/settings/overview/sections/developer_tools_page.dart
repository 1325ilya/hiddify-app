import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeveloperToolsPage extends StatelessWidget {
  const DeveloperToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Developer Tools"),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer.withOpacity(0.4),
                    theme.colorScheme.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.fingerprint_rounded, color: theme.colorScheme.primary, size: 28),
                ),
                title: Text(
                  "Device Identity Lab",
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 4.0),
                  child: Text(
                    "Inspect unique device/app identifiers, Keychain-stored attributes, and simulate/override hardware identity variables securely.",
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.goNamed('deviceIdentityLab'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
