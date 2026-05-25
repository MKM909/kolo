import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/vault_milestone_advisor.dart';

void main() {
  test('celebrates halfway and fully funded vault milestones once', () {
    const previous = SavingsVault(
      id: 'vault-phone',
      name: 'New Phone',
      targetKobo: 1000000,
      currentKobo: 400000,
    );

    final halfway = VaultMilestoneAdvisor.messageFor(
      previous: previous,
      current: const SavingsVault(
        id: 'vault-phone',
        name: 'New Phone',
        targetKobo: 1000000,
        currentKobo: 500000,
      ),
    );

    expect(halfway, contains('halfway'));
    expect(halfway, contains('New Phone'));

    final repeatedHalfway = VaultMilestoneAdvisor.messageFor(
      previous: const SavingsVault(
        id: 'vault-phone',
        name: 'New Phone',
        targetKobo: 1000000,
        currentKobo: 650000,
      ),
      current: const SavingsVault(
        id: 'vault-phone',
        name: 'New Phone',
        targetKobo: 1000000,
        currentKobo: 700000,
      ),
    );

    expect(repeatedHalfway, isNull);

    final complete = VaultMilestoneAdvisor.messageFor(
      previous: previous,
      current: const SavingsVault(
        id: 'vault-phone',
        name: 'New Phone',
        targetKobo: 1000000,
        currentKobo: 1000000,
      ),
    );

    expect(complete, contains('fully funded'));
  });
}
