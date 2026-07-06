import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/premium_service.dart';
import '../services/purchases_gateway.dart';
import '../utils/constants.dart';

/// The Decidr Premium paywall, shown as a modal bottom sheet from any
/// gated feature. Replaces the Phase-3 "coming soon" dialog.
///
/// Three states:
///  * **Store configured** — lists purchase packages from RevenueCat,
///    with purchase + restore actions.
///  * **Store not configured** (no API key baked into this build, or
///    an unsupported platform like web without Web Billing) — explains
///    that purchases aren't available here yet, so the sheet still
///    honestly communicates what Premium is.
///  * **Load error** — a retry affordance.
///
/// Open via [showPaywall]; it resolves once the sheet closes.
class _PaywallSheet extends StatefulWidget {
  /// The feature the user tapped to get here, e.g. "Nearby places".
  /// Shown as the lead-in so the paywall feels contextual.
  final String? featureName;

  const _PaywallSheet({this.featureName});

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  late Future<List<PremiumPackage>> _packagesFuture;
  PremiumPackage? _selected;
  bool _busy = false;

  /// Purchase/restore feedback rendered inline in the sheet — a
  /// ScaffoldMessenger snackbar would appear *behind* this modal.
  String? _notice;

  @override
  void initState() {
    super.initState();
    _packagesFuture =
        context.read<PremiumService>().loadPackages();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final premium = context.watch<PremiumService>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle.
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildHeader(theme),
            const SizedBox(height: 16),
            _buildFeatureList(theme),
            const SizedBox(height: 16),
            if (premium.isPremium)
              _buildAlreadyPremium(theme)
            else if (premium.storeAvailable)
              _buildStoreSection(theme, premium)
            else
              _buildStoreUnavailable(theme),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.tertiary,
                ],
              ),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text('Decidr Premium', style: theme.textTheme.headlineSmall),
          if (widget.featureName != null) ...[
            const SizedBox(height: 4),
            Text(
              '${widget.featureName} is part of Decidr Premium.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureList(ThemeData theme) {
    const features = [
      (Icons.place_outlined, 'Nearby places',
          'Real spots around you for every "go out" card'),
      (Icons.style_outlined, 'Themed card decks',
          'Tarot, Forest, Sunset, and Monochrome card backs'),
      (Icons.playlist_add, 'Unlimited custom cards',
          'Free tier includes ${SuggestionConstants.customSuggestionFreeMaxCount}'),
      (Icons.bookmarks_outlined, 'More saved profiles',
          'Keep a profile for every kind of day'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          for (final (icon, title, subtitle) in features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.bodyLarge),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlreadyPremium(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 32),
          const SizedBox(height: 8),
          Text("You're a Premium member — enjoy!",
              style: theme.textTheme.bodyLarge),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreUnavailable(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            kIsWeb
                ? 'Purchases aren’t available on the web yet — '
                    'Premium unlocks in the mobile app.'
                : 'Purchases aren’t available in this build yet. '
                    'Check back soon!',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSection(ThemeData theme, PremiumService premium) {
    return FutureBuilder<List<PremiumPackage>>(
      future: _packagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final packages = snapshot.data ?? const <PremiumPackage>[];
        if (packages.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  'Couldn’t load purchase options right now.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _packagesFuture = premium.loadPackages();
                  }),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        _selected ??= packages.first;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              for (final p in packages) _buildPackageTile(theme, p),
              if (_notice != null) ...[
                const SizedBox(height: 8),
                Text(
                  _notice!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : () => _purchase(premium),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Unlock Premium — '
                        '${_selected!.priceString}'
                        '${_selected!.periodSuffix.isEmpty ? '' : ' ${_selected!.periodSuffix}'}',
                      ),
              ),
              TextButton(
                onPressed: _busy ? null : () => _restore(premium),
                child: const Text('Restore purchases'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPackageTile(ThemeData theme, PremiumPackage p) {
    final isSelected = _selected?.id == p.id;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selected = p),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(p.label, style: theme.textTheme.bodyLarge),
              ),
              Text(
                '${p.priceString}'
                '${p.periodSuffix.isEmpty ? '' : ' ${p.periodSuffix}'}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _purchase(PremiumService premium) async {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    final outcome = await premium.purchase(selected);
    if (!mounted) return;
    switch (outcome) {
      case PurchaseOutcome.success:
        Navigator.of(context).pop();
      case PurchaseOutcome.cancelled:
        setState(() => _busy = false); // Backed out — no error surface.
      case PurchaseOutcome.failed:
        setState(() {
          _busy = false;
          _notice = premium.lastErrorMessage ??
              'Purchase failed. Please try again.';
        });
    }
  }

  Future<void> _restore(PremiumService premium) async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    final outcome = await premium.restore();
    if (!mounted) return;
    switch (outcome) {
      case RestoreOutcome.restored:
        Navigator.of(context).pop();
      case RestoreOutcome.noPurchases:
        setState(() {
          _busy = false;
          _notice = 'No previous purchases found.';
        });
      case RestoreOutcome.failed:
        setState(() {
          _busy = false;
          _notice = premium.lastErrorMessage ??
              'Couldn’t reach the store — please try again.';
        });
    }
  }
}

/// Show the Decidr Premium paywall. Resolves when the sheet closes;
/// read `PremiumService.isPremium` afterwards to see whether the user
/// upgraded.
Future<void> showPaywall(BuildContext context, {String? featureName}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PaywallSheet(featureName: featureName),
    routeSettings: const RouteSettings(name: 'paywall'),
  );
}
