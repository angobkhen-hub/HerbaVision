import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/auth_state.dart';
import '../services/settings_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _handleLogout() async {
    final auth = context.read<AuthState>();

    // Guests have nothing to lose, so only ask signed-in users.
    if (!auth.isGuest) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Log out?'),
          content: const Text('You can sign back in at any time.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Log out'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    auth.logout();
    // Pop back to the first route; the app root watches AuthState.status
    // and will route to the Login screen once it's loggedOut.
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature isn\'t available yet.')),
    );
  }

  void _showHelp() {
    const faqs = <(String, String)>[
      (
        'How do I identify a plant?',
        'Tap "Upload a leaf photo" on the dashboard and choose a clear, '
            'well-lit photo of a single leaf. The app shows the plant name, '
            'how confident the match is, and information about the plant.'
      ),
      (
        'What do the confidence numbers mean?',
        'It is how sure the model is about the match. A high number is a '
            'good sign, but it is not a guarantee. Always double-check before '
            'using any plant.'
      ),
      (
        'Which plants can HerbaVision recognize?',
        'Herbal: Sambong, Guyabano and Sawansawan. Non-herbal: Song of '
            'India, Dumb Cane and Caladium.'
      ),
      (
        'What does Auto-save to library do?',
        'When it is on, scans with a confidence of '
            '${SettingsState.autoSaveThreshold}% or higher are saved to your '
            'library automatically.'
      ),
      (
        'Is the plant information medical advice?',
        'No. It is general information only. Do not use it in place of '
            'medical treatment, and ask a health professional before using '
            'any herbal preparation.'
      ),
    ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Help & FAQ'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final faq in faqs)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(faq.$1,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    childrenPadding: const EdgeInsets.only(bottom: 12),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(faq.$2,
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.textSecondary)),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'HerbaVision',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(Icons.eco_outlined, color: AppColors.brand, size: 36),
      children: const [
        SizedBox(height: 8),
        Text(
          'HerbaVision identifies herbal and ornamental plants from a leaf '
          'photo and shows information about each plant. The information is '
          'for general knowledge only and is not medical advice.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final settings = context.watch<SettingsState>();
    final isGuest = authState.isGuest;
    final displayName = isGuest ? 'Guest' : (authState.userName ?? 'Unknown user');
    final email = isGuest ? 'Not signed in' : (authState.userEmail ?? '');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bg, AppColors.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  _ProfileCard(
                    name: displayName,
                    email: email,
                    isGuest: isGuest,
                  ),
                  const SizedBox(height: 24),
                  if (!isGuest) ...[
                    const _SectionLabel('Account'),
                    _SettingsCard(
                      children: [
                        _NavTile(
                          icon: Icons.lock_outline,
                          title: 'Change password',
                          onTap: () => _comingSoon('Changing your password'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  const _SectionLabel('Preferences'),
                  _SettingsCard(
                    children: [
                      _ToggleTile(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: 'Show a message after each new identification',
                        value: settings.notifications,
                        onChanged: settings.setNotifications,
                      ),
                      _ToggleTile(
                        icon: Icons.bookmark_outline,
                        title: 'Auto-save to library',
                        subtitle:
                            'Automatically save matches of ${SettingsState.autoSaveThreshold}% or higher',
                        value: settings.autoSave,
                        onChanged: settings.setAutoSave,
                      ),
                      _ToggleTile(
                        icon: settings.darkMode
                            ? Icons.dark_mode
                            : Icons.dark_mode_outlined,
                        title: 'Dark mode',
                        subtitle: 'Use a darker color scheme',
                        value: settings.darkMode,
                        onChanged: settings.setDarkMode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _SectionLabel('Support'),
                  _SettingsCard(
                    children: [
                      _NavTile(
                        icon: Icons.help_outline,
                        title: 'Help & FAQ',
                        onTap: _showHelp,
                      ),
                      _NavTile(
                        icon: Icons.info_outline,
                        title: 'About HerbaVision',
                        subtitle: 'Version 1.0.0',
                        onTap: _showAbout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: Icon(
                        isGuest ? Icons.login : Icons.logout,
                        size: 18,
                        color: isGuest ? AppColors.brand : AppColors.danger,
                      ),
                      label: Text(
                        isGuest ? 'Sign in or sign up' : 'Log out',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isGuest ? AppColors.brand : AppColors.danger,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kRadius + 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final bool isGuest;

  const _ProfileCard({
    required this.name,
    required this.email,
    required this.isGuest,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandDark, AppColors.brand, AppColors.brandLight],
        ),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.brandDark,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Colors.white,
                  ),
                ),
                if (email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xDDFFFFFF),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isGuest ? 'Browsing as guest' : 'Signed in',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
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
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, indent: 68, color: AppColors.border));
      }
      rows.add(children[i]);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(children: rows),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  const _IconBadge(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.bgAccent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: AppColors.brand, size: 20),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _IconBadge(icon),
      title: Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      subtitle: subtitle != null && subtitle!.isNotEmpty
          ? Text(subtitle!,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted))
          : null,
      trailing:
          Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: _IconBadge(icon),
      title: Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted))
          : null,
      value: value,
      activeColor: AppColors.brand,
      onChanged: onChanged,
    );
  }
}