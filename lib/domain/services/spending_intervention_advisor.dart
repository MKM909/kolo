import 'package:kolo/domain/models/models.dart';

abstract class SpendingInterventionAdvisor {
  Future<String> interventionMessage({
    required DashboardState context,
    String? modelName,
  });
}
