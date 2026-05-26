import 'package:kolo/domain/models/models.dart';

abstract class DashboardCacheStore {
  Future<CachedDashboardEntry?> load(String uid);

  Future<void> save({
    required String uid,
    required DashboardState dashboard,
    required CachedDashboardMetadata metadata,
  });

  Future<void> clear(String uid);
}
