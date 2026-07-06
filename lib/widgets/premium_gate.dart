import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/premium_service.dart';
import 'paywall_sheet.dart';

/// Gate an action behind Decidr Premium.
///
/// Returns immediately with `true` when the user is already premium.
/// Otherwise shows the paywall (contextualized with [featureName]) and
/// returns the entitlement state after it closes — `true` when the
/// user purchased or restored mid-flow, so callers can complete the
/// original action in one tap:
///
///   if (await ensurePremium(context, featureName: 'Nearby places')) {
///     if (!context.mounted) return;
///     // ... do the premium thing
///   }
Future<bool> ensurePremium(
  BuildContext context, {
  required String featureName,
}) async {
  final premium = context.read<PremiumService>();
  if (premium.isPremium) return true;
  await showPaywall(context, featureName: featureName);
  return premium.isPremium;
}
