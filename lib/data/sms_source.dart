import 'package:flutter/services.dart';

/// One SMS as read from the phone inbox.
class RawSms {
  const RawSms(
      {required this.sender, required this.body, required this.timestamp});

  final String sender;
  final String body;
  final DateTime timestamp;
}

/// Access to the phone's SMS inbox. Faked in tests.
abstract interface class SmsSource {
  Future<bool> ensurePermission();

  /// Inbox messages received at or after [since], oldest first.
  Future<List<RawSms>> readInbox({required DateTime since});
}

/// Talks to MainActivity.kt over the `masareef/sms` channel.
class PlatformSmsSource implements SmsSource {
  const PlatformSmsSource();

  static const _channel = MethodChannel('masareef/sms');

  @override
  Future<bool> ensurePermission() async =>
      await _channel.invokeMethod<bool>('ensurePermission') ?? false;

  @override
  Future<List<RawSms>> readInbox({required DateTime since}) async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
          'readInbox',
          {'since': since.millisecondsSinceEpoch},
        ) ??
        const [];
    return [
      for (final row in rows)
        RawSms(
          sender: row['address'] as String? ?? '',
          body: row['body'] as String? ?? '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(row['date']! as int),
        ),
    ];
  }
}
