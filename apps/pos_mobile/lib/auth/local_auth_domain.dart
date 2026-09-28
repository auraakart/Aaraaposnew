import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../operations/operations_domain.dart';
import '../sell/local_pos_database.dart';

const localPinIterations = 40000;
const localSessionHours = 12;
const localPinMaxAttemptsBeforeLock = 5;

bool isValidLocalPin(String pin) => RegExp(r'^\d{4,8}$').hasMatch(pin);

String generateLocalPinSalt({Random? random}) {
  final source = random ?? Random.secure();
  final bytes = Uint8List.fromList(
    List<int>.generate(16, (_) => source.nextInt(256)),
  );
  return base64UrlEncode(bytes);
}

String deriveLocalPinHash({
  required String pin,
  required String salt,
  int iterations = localPinIterations,
}) {
  if (!isValidLocalPin(pin)) {
    throw ArgumentError('PIN must contain 4 to 8 digits');
  }
  if (iterations < 10000 || iterations > 500000) {
    throw ArgumentError('PIN derivation iteration count is outside policy');
  }

  final saltBytes = base64Url.decode(_padBase64(salt));
  final key = utf8.encode(pin);
  final hmac = Hmac(sha256, key);
  final block = Uint8List(saltBytes.length + 4)
    ..setRange(0, saltBytes.length, saltBytes)
    ..setRange(
      saltBytes.length,
      saltBytes.length + 4,
      const [0, 0, 0, 1],
    );

  var value = Uint8List.fromList(hmac.convert(block).bytes);
  final output = Uint8List.fromList(value);
  for (var round = 1; round < iterations; round++) {
    value = Uint8List.fromList(hmac.convert(value).bytes);
    for (var index = 0; index < output.length; index++) {
      output[index] ^= value[index];
    }
  }
  return base64UrlEncode(output);
}

bool verifyLocalPin({
  required String pin,
  required String salt,
  required String expectedHash,
  required int iterations,
}) {
  if (!isValidLocalPin(pin)) return false;
  final actual = deriveLocalPinHash(
    pin: pin,
    salt: salt,
    iterations: iterations,
  );
  return _constantTimeEquals(actual, expectedHash);
}

DateTime? localPinLockUntil({
  required int failedAttempts,
  required DateTime now,
}) {
  if (failedAttempts < localPinMaxAttemptsBeforeLock) return null;
  final lockMinutes = failedAttempts >= 10 ? 30 : 5;
  return now.toUtc().add(Duration(minutes: lockMinutes));
}

class LocalDeviceSession {
  const LocalDeviceSession({
    required this.context,
    required this.employeeName,
    required this.role,
    required this.authenticatedAt,
    required this.expiresAt,
  });

  final LocalSaleContext context;
  final String employeeName;
  final EmployeeRole role;
  final DateTime authenticatedAt;
  final DateTime expiresAt;

  bool isExpired(DateTime now) =>
      !now.toUtc().isBefore(expiresAt.toUtc());
}

class LocalPinAuthException implements Exception {
  const LocalPinAuthException({
    required this.code,
    this.lockedUntil,
  });

  final String code;
  final DateTime? lockedUntil;

  @override
  String toString() => code;
}

String _padBase64(String input) {
  final remainder = input.length % 4;
  if (remainder == 0) return input;
  return input.padRight(input.length + (4 - remainder), '=');
}

bool _constantTimeEquals(String left, String right) {
  final a = utf8.encode(left);
  final b = utf8.encode(right);
  var difference = a.length ^ b.length;
  final length = max(a.length, b.length);
  for (var index = 0; index < length; index++) {
    final av = index < a.length ? a[index] : 0;
    final bv = index < b.length ? b[index] : 0;
    difference |= av ^ bv;
  }
  return difference == 0;
}
