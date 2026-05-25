import 'package:kolo/domain/models/models.dart';

abstract class PermissionRequester {
  Future<PermissionGrantState> status(KoloPermission permission);

  Future<PermissionGrantState> request(KoloPermission permission);
}
