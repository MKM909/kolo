import 'package:kolo/domain/models/models.dart';

class VaultProtectionAdvisor {
  VaultProtectionAdvisor._();

  static VaultProtectionWarning check({
    required int balanceKobo,
    required int expenseKobo,
    required List<SavingsVault> vaults,
  }) {
    final protectedKobo = vaults.fold<int>(
      0,
      (total, vault) => total + (vault.currentKobo > 0 ? vault.currentKobo : 0),
    );
    final balanceAfter = balanceKobo - expenseKobo;
    final dipsIntoVault =
        protectedKobo > 0 &&
        balanceKobo > protectedKobo &&
        balanceAfter < protectedKobo;

    return VaultProtectionWarning(
      dipsIntoVault: dipsIntoVault,
      protectedKobo: protectedKobo,
      shortfallKobo: dipsIntoVault ? protectedKobo - balanceAfter : 0,
      primaryVaultName: _primaryVaultName(vaults),
    );
  }

  static String? _primaryVaultName(List<SavingsVault> vaults) {
    SavingsVault? primary;
    for (final vault in vaults) {
      if (vault.currentKobo <= 0) continue;
      if (primary == null || vault.currentKobo > primary.currentKobo) {
        primary = vault;
      }
    }
    return primary?.name;
  }
}

class VaultProtectionWarning {
  const VaultProtectionWarning({
    required this.dipsIntoVault,
    required this.protectedKobo,
    required this.shortfallKobo,
    this.primaryVaultName,
  });

  final bool dipsIntoVault;
  final int protectedKobo;
  final int shortfallKobo;
  final String? primaryVaultName;
}
