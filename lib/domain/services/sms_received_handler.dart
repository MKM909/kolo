import 'package:kolo/domain/models/models.dart';

abstract class SmsReceivedHandler {
  Future<bool> onSmsReceived({
    required String rawText,
    String? sourceEventId,
    String? sender,
    DateTime? receivedAt,
    required DashboardState context,
    String? modelName,
  });
}
