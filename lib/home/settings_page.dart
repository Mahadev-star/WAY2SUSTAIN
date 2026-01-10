import 'package:flutter/material.dart';
import 'package:sustainable_travel_app/home/EditProfilePage.dart';
import 'package:sustainable_travel_app/home/LanguagePage.dart';
import 'package:sustainable_travel_app/home/NotificationsPage.dart';
import 'package:sustainable_travel_app/home/PrivacySecurityPage.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationsEnabled = true;
  bool darkModeEnabled = true;
  bool biometricEnabled = true;
  bool ecoRemindersEnabled = true;

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF43A047);
    const Color backgroundColor = Color(0xFF151717);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Settings
            _buildSectionTitle("Account"),
            _buildSettingTile(
              icon: Icons.person,
              title: "Edit Profile",
              subtitle: "Update your personal information",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfilePage(),
                  ),
                );
              },
            ),
            _buildSettingTile(
              icon: Icons.security,
              title: "Privacy & Security",
              subtitle: "Manage your privacy settings",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacySecurityPage(),
                  ),
                );
              },
            ),
            _buildSettingTile(
              icon: Icons.notifications_active,
              title: "Notifications",
              trailing: Switch(
                value: notificationsEnabled,
                activeThumbColor: brandGreen,
                onChanged: (value) {
                  setState(() {
                    notificationsEnabled = value;
                  });
                },
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // App Settings
            _buildSectionTitle("App Settings"),
            _buildSettingTile(
              icon: Icons.dark_mode,
              title: "Dark Mode",
              trailing: Switch(
                value: darkModeEnabled,
                activeThumbColor: brandGreen,
                onChanged: (value) {
                  setState(() {
                    darkModeEnabled = value;
                  });
                },
              ),
            ),
            _buildSettingTile(
              icon: Icons.language,
              title: "Language",
              subtitle: "English",
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LanguagePage()),
                );
              },
            ),
            _buildSettingTile(
              icon: Icons.fingerprint,
              title: "Biometric Login",
              subtitle: "Use fingerprint or face ID",
              trailing: Switch(
                value: biometricEnabled,
                activeThumbColor: brandGreen,
                onChanged: (value) {
                  setState(() {
                    biometricEnabled = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 24),

            // Sustainability Features
            _buildSectionTitle("Sustainability Features"),
            _buildSettingTile(
              icon: Icons.eco,
              title: "Eco Reminders",
              subtitle: "Daily sustainability tips",
              trailing: Switch(
                value: ecoRemindersEnabled,
                activeThumbColor: brandGreen,
                onChanged: (value) {
                  setState(() {
                    ecoRemindersEnabled = value;
                  });
                },
              ),
            ),
            _buildSettingTile(
              icon: Icons.bar_chart,
              title: "Data & Analytics",
              subtitle: "View your environmental impact",
              onTap: () {},
            ),

            const SizedBox(height: 24),

            // Support
            _buildSectionTitle("Support"),
            _buildSettingTile(
              icon: Icons.help_outline,
              title: "Help Center",
              subtitle: "FAQs and guides",
              onTap: () {},
            ),
            _buildSettingTile(
              icon: Icons.feedback_outlined,
              title: "Send Feedback",
              subtitle: "Share your suggestions",
              onTap: () {},
            ),
            _buildSettingTile(
              icon: Icons.privacy_tip_outlined,
              title: "Privacy Policy",
              onTap: () {},
            ),
            _buildSettingTile(
              icon: Icons.description_outlined,
              title: "Terms of Service",
              onTap: () {},
            ),

            const SizedBox(height: 24),

            // Account Actions
            _buildSectionTitle("Account Actions"),
            _buildSettingTile(
              icon: Icons.logout,
              title: "Log Out",
              titleColor: Colors.orange,
              onTap: () {
                _showLogoutDialog(context);
              },
            ),
            _buildSettingTile(
              icon: Icons.delete_outline,
              title: "Delete Account",
              titleColor: Colors.red,
              onTap: () {
                _showDeleteAccountDialog(context);
              },
            ),

            const SizedBox(height: 32),

            // App Version
            Center(
              child: Column(
                children: [
                  Text(
                    "Way2Sustain v1.0.0",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Build 2024.01.01",
                    style: TextStyle(color: Colors.grey[700], fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    final Color primaryColor = titleColor ?? Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.grey[900]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        // ignore: deprecated_member_use
        leading: Icon(icon, color: primaryColor.withOpacity(0.9)),
        title: Text(
          title,
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              )
            : null,
        trailing:
            trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right, color: Colors.grey, size: 20)
                : null),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        visualDensity: const VisualDensity(vertical: 0),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Log Out",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to log out?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              // Perform logout
              Navigator.pop(context);
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text(
              "Log Out",
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Delete Account",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "This action cannot be undone. All your data will be permanently deleted including:",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 12),
            _buildBulletPoint("Your profile information"),
            _buildBulletPoint("Sustainability progress"),
            _buildBulletPoint("Challenges and achievements"),
            _buildBulletPoint("Community interactions"),
            SizedBox(height: 16),
            Text(
              "Are you absolutely sure?",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              // Delete account logic
              Navigator.pop(context);
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text(
              "Delete Account",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: camel_case_types
class _buildBulletPoint extends StatelessWidget {
  final String text;

  const _buildBulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4, right: 8),
            child: Icon(Icons.circle, size: 6, color: Colors.grey),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
