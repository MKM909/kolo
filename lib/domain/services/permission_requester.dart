import 'package:kolo/domain/models/models.dart';

abstract class PermissionRequester {
  Future<PermissionGrantState> request(KoloPermission permission);
}
