import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/money_formatter.dart';

class VaultMilestoneAdvisor {
  VaultMilestoneAdvisor._();

  static String? messageFor({
    required SavingsVault? previous,
    required SavingsVault current,
  }) {
    if (current.targetKobo <= 0) return null;

    final previousProgress = previous?.progress ?? 0;
    final currentProgress = current.progress;
    if (previousProgress < 1 && currentProgress >= 1) {
      return '${current.name} is fully funded at ${MoneyFormatter.formatKobo(current.currentKobo)}. Kolo is keeping that goal protected.';
    }
    if (previousProgress < 0.5 && currentProgress >= 0.5) {
      return '${current.name} is halfway funded at ${MoneyFormatter.formatKobo(current.currentKobo)}. Nice progress, keep this money protected.';
    }
    return null;
  }
}
