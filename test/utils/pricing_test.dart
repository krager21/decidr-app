import 'package:flutter_test/flutter_test.dart';

import 'package:decidr_app/services/purchases_gateway.dart';
import 'package:decidr_app/utils/pricing.dart';

const monthly = PremiumPackage(
  id: r'$rc_monthly',
  label: 'Monthly',
  priceString: r'$2.99',
  periodSuffix: '/ month',
  kind: PackageKind.monthly,
  price: 2.99,
);

const annual = PremiumPackage(
  id: r'$rc_annual',
  label: 'Annual',
  priceString: r'$19.99',
  periodSuffix: '/ year',
  kind: PackageKind.annual,
  price: 19.99,
);

const lifetime = PremiumPackage(
  id: r'$rc_lifetime',
  label: 'Lifetime',
  priceString: r'$49.99',
  periodSuffix: '',
  kind: PackageKind.lifetime,
  price: 49.99,
);

void main() {
  test('sortForDisplay orders cadence-first with lifetime as anchor', () {
    final sorted = sortForDisplay([lifetime, annual, monthly]);
    expect(sorted.map((p) => p.id).toList(),
        [monthly.id, annual.id, lifetime.id]);
  });

  test('defaultSelection prefers annual', () {
    expect(defaultSelection([lifetime, monthly, annual])!.id, annual.id);
    expect(defaultSelection([lifetime, monthly])!.id, monthly.id);
    expect(defaultSelection([]), isNull);
  });

  test('currencySymbol handles prefix symbols and bare digits', () {
    expect(currencySymbol(r'$19.99'), r'$');
    expect(currencySymbol('€19,99'), '€');
    expect(currencySymbol('19,99 kr'), '');
  });

  test('perMonthEquivalent divides yearly price into months', () {
    expect(perMonthEquivalent(annual), r'≈ $1.67 / month');
    expect(perMonthEquivalent(monthly), isNull);
    expect(perMonthEquivalent(lifetime), isNull);
  });

  test('savingsVersusMonthly computes whole-percent savings', () {
    // $19.99 vs 12 × $2.99 = $35.88 → 44%
    expect(savingsVersusMonthly(annual, monthly), 44);
    expect(savingsVersusMonthly(lifetime, monthly), isNull,
        reason: 'lifetime has no comparable span');
    const pricierAnnual = PremiumPackage(
      id: 'a',
      label: 'Annual',
      priceString: r'$40.00',
      periodSuffix: '/ year',
      kind: PackageKind.annual,
      price: 40.0,
    );
    expect(savingsVersusMonthly(pricierAnnual, monthly), isNull,
        reason: 'no badge when there are no savings');
  });
}
