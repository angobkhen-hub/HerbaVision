import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Basic settings screen. Hook each item up to real preferences/state
/// (e.g. shared_preferences, a settings provider, or your backend).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _saveToLibraryAuto = false;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionLabel('Account'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'Profile',
                subtitle: 'Aiman',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.lock_outline,
                title: 'Change password',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 20),

          _SectionLabel('Preferences'),
          _SettingsCard(
            children: [
              _SwitchTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Get notified about new identifications',
                value: _notifications,
                onChanged: (v) => setState(() => _notifications = v),
              ),
              _SwitchTile(
                icon: Icons.bookmark_outline,
                title: 'Auto-save to library',
                subtitle: 'Automatically save high-confidence matches',
                value: _saveToLibraryAuto,
                onChanged: (v) => setState(() => _saveToLibraryAuto = v),
              ),
              _SwitchTile(
                icon: Icons.dark_mode_outlined,
                title: 'Dark mode',
                value: _darkMode,
                onChanged: (v) => setState(() => _darkMode = v),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _SectionLabel('Support'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.help_outline,
                title: 'Help & FAQ',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'About HerbaVision',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.logout, size: 18, color: Colors.red),
              label: const Text('Log out', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textAccent, size: 22),
      title: Text(title,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted))
          : null,
      trailing: const Icon(Icons.chevron_right,
          size: 18, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.textAccent, size: 22),
      title: Text(title,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted))
          : null,
      value: value,
      activeColor: AppColors.brand,
      onChanged: onChanged,
    );
  }
}