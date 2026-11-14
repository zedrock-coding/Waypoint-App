import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme/app_theme.dart';
import 'widgets/legal_dialog.dart';
import 'widgets/waypoint_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String updatesUrl = 'https://github.com/zedrock-coding/Waypoint-App';

  Future<void> _launchUpdatesUrl(BuildContext context) async {
    final uri = Uri.parse(updatesUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open updates page')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching updates: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.onSurface, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'About Waypoint',
          style: GoogleFonts.geist(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: AppTheme.surfaceVariant, height: 1),
        ),
      ),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          final versionStr = info != null
              ? 'v${info.version} (Build ${info.buildNumber})'
              : 'v0.6.1 (Build 24)';

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                children: [
                  // App Icon & Brand Branding
                  Center(
                    child: Column(
                      children: [
                        const WaypointLogo(size: 72),
                        const SizedBox(height: 16),
                        Text(
                          'Waypoint',
                          style: GoogleFonts.geist(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AI-Orchestrated Task Management Workspace',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.surfaceVariant),
                          ),
                          child: Text(
                            versionStr,
                            style: AppTheme.monoStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.mint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Actions Section
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.surfaceVariant),
                    ),
                    child: Column(
                      children: [
                        _buildActionTile(
                          icon: Icons.system_update_alt_rounded,
                          title: 'Check for Updates',
                          subtitle: 'View releases and source on GitHub',
                          trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: AppTheme.onSurfaceVariant),
                          onTap: () => _launchUpdatesUrl(context),
                        ),
                        const Divider(color: AppTheme.surfaceVariant, height: 1),
                        _buildActionTile(
                          icon: Icons.description_outlined,
                          title: 'View EULA',
                          subtitle: 'End User License Agreement',
                          trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.onSurfaceVariant),
                          onTap: () => showDialog(
                            context: context,
                            builder: (context) => const LegalDialog(isFirstLaunch: false),
                          ),
                        ),
                        const Divider(color: AppTheme.surfaceVariant, height: 1),
                        _buildActionTile(
                          icon: Icons.privacy_tip_outlined,
                          title: 'View Privacy Policy',
                          subtitle: 'Data governance and privacy terms',
                          trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.onSurfaceVariant),
                          onTap: () => showDialog(
                            context: context,
                            builder: (context) => const LegalDialog(isFirstLaunch: false),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Creator & Attribution Footer
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Made with ♥ by',
                          style: AppTheme.monoStyle(
                            fontSize: 11,
                            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lakshya Jadhav',
                          style: GoogleFonts.geist(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(icon, color: AppTheme.mint, size: 18),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.onSurface),
      ),
      subtitle: Text(
        subtitle,
        style: AppTheme.monoStyle(fontSize: 10, color: AppTheme.onSurfaceVariant),
      ),
      trailing: trailing,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }
}
