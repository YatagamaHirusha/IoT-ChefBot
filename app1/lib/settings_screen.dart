import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final bool isCookerOn;

  const SettingsScreen({super.key, required this.isCookerOn});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Local state variables for the settings page
  bool _pushNotifications = true;
  bool _gasAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Device Section ---
              _buildSectionHeader(context, "Device"),
              _buildSettingCard(
                context,
                child: ListTile(
                  leading: const Icon(Icons.wifi, color: Colors.blue),
                  title: const Text("Cooker Wi-Fi Settings"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to Wi-Fi settings page
                  },
                ),
              ),

              // --- Notifications Section ---
              const SizedBox(height: 24),
              _buildSectionHeader(context, "Notifications"),
              _buildSettingCard(
                context,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text("Push Notifications"),
                      subtitle: const Text("Allow all app notifications"),
                      value: _pushNotifications,
                      onChanged: (val) =>
                          setState(() => _pushNotifications = val),
                      secondary: const Icon(Icons.notifications),
                    ),
                    // Only show this if push notifications are on
                    if (_pushNotifications)
                      SwitchListTile(
                        title: const Text("Critical Gas Alerts"),
                        subtitle: const Text(
                          "Receive instant gas leak warnings",
                        ),
                        value: _gasAlerts,
                        onChanged: (val) => setState(() => _gasAlerts = val),
                        secondary: const Icon(
                          Icons.gas_meter,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
              ),

              // --- Account Section ---
              const SizedBox(height: 24),
              _buildSectionHeader(context, "Account"),
              _buildSettingCard(
                context,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text("Edit Profile"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // TODO: Navigate to profile edit page
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text("Log Out"),
                      onTap: () {
                        if (widget.isCookerOn) {
                          // Cooker is ON. Show a warning dialog.
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Safety Warning"),
                              content: const Text(
                                "Your cooker is still on. Please turn it off from the dashboard before logging out.",
                              ),
                              actions: [
                                TextButton(
                                  child: const Text("OK"),
                                  onPressed: () {
                                    Navigator.of(ctx).pop(); // Close the dialog
                                  },
                                ),
                              ],
                            ),
                          );
                        } else {
                          // Cooker is OFF. Safe to log out.
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/welcome',
                            (Route<dynamic> route) => false,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for section headers
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[600],
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  // Helper widget for the card-based settings
  Widget _buildSettingCard(BuildContext context, {required Widget child}) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias, // Ensures child respects card rounding
      child: child,
    );
  }
}
