import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/vault_protection_advisor.dart';

void main() {
  test('warns only when spending crosses into protected vault funds', () {
    const vaults = [
      SavingsVault(
        id: 'vault-phone',
        name: 'New Phone',
        targetKobo: 2000000,
        currentKobo: 1200000,
      ),
      SavingsVault(
        id: 'vault-buffer',
        name: 'Emergency',
        targetKobo: 1000000,
        currentKobo: 300000,
      ),
    ];

    final warning = VaultProtectionAdvisor.check(
      balanceKobo: 1800000,
      expenseKobo: 400000,
      vaults: vaults,
    );

    expect(warning.dipsIntoVault, isTrue);
    expect(warning.protectedKobo, 1500000);
    expect(warning.shortfallKobo, 100000);
    expect(warning.primaryVaultName, 'New Phone');

    final alreadyBelowProtection = VaultProtectionAdvisor.check(
      balanceKobo: 1400000,
      expenseKobo: 100000,
      vaults: vaults,
    );

    expect(alreadyBelowProtection.dipsIntoVault, isFalse);
  });
}
