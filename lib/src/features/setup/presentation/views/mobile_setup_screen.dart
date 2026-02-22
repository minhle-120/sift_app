import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../chat/presentation/controllers/settings_controller.dart';

class MobileSetupScreen extends ConsumerStatefulWidget {
  const MobileSetupScreen({super.key});

  @override
  ConsumerState<MobileSetupScreen> createState() => _MobileSetupScreenState();
}

class _MobileSetupScreenState extends ConsumerState<MobileSetupScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final isDownloading = settings.isDownloadingMobileBundle;
    final isInstalled = settings.isMobileBundleInstalled;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.05),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon Section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_motion_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Title Section
                  Text(
                    'Local Intelligence',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You are about to set up a private, on-device AI. We will automatically download and configure the model bundle for you.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Progress / Action Section
                  if (isDownloading) ...[
                     _buildDownloadProgress(theme, settings),
                  ] else if (isInstalled) ...[
                    _buildInstalledSuccess(theme),
                  ] else ...[
                    _buildDownloadTrigger(theme),
                  ],

                  const Spacer(),
                  
                  // Footer Actions
                  if (isInstalled && !isDownloading)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final notifier = ref.read(settingsProvider.notifier);
                          await notifier.completeSetup();
                          if (mounted) {
                            // Pop all setup screens to return to the root gate, 
                            // which will now show ChatScreen because isSetupComplete is true.
                            navigator.popUntil((route) => route.isFirst);
                          }
                        },
                        icon: const Icon(Icons.rocket_launch_rounded),
                        label: const Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: isDownloading ? null : () => Navigator.of(context).pop(),
                      child: Text(
                        isDownloading ? 'Please wait for download...' : 'Back to Selection',
                        style: TextStyle(color: theme.colorScheme.primary.withValues(alpha: 0.7)),
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

  Widget _buildDownloadTrigger(ThemeData theme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton.icon(
            onPressed: () => ref.read(settingsProvider.notifier).downloadMobileModelBundle(),
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: const Text('One-Tap Automatic Setup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 4,
              shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi, size: 14, color: theme.colorScheme.secondary),
            const SizedBox(width: 8),
            Text(
              'Wi-Fi recommended for download',
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.secondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDownloadProgress(ThemeData theme, SettingsState settings) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: settings.mobileBundleProgress > 0 ? settings.mobileBundleProgress / 100 : null,
            minHeight: 12,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                settings.mobileBundleStatus,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (settings.mobileBundleProgress > 0)
              Text(
                '${settings.mobileBundleProgress.toStringAsFixed(1)}%',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, size: 18, color: theme.colorScheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'The screen will stay awake during the download.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstalledSuccess(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.check_circle_rounded, 
                color: theme.colorScheme.primary, 
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Setup Complete',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold, 
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your private Mobile AI engine is now fully configured and ready for local inference.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
