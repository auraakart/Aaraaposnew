import 'dart:math';

import 'package:aaraapos_pos/auth/local_auth_domain.dart';
import 'package:aaraapos_pos/operations/operations_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PIN hash verifies exact PIN and changes with salt', () {
    final saltA = generateLocalPinSalt(random: Random(1));
    final saltB = generateLocalPinSalt(random: Random(2));
    final hashA = deriveLocalPinHash(
      pin: '2468',
      salt: saltA,
      iterations: 10000,
    );
    final hashB = deriveLocalPinHash(
      pin: '2468',
      salt: saltB,
      iterations: 10000,
    );

    expect(hashA, isNot(hashB));
    expect(
      verifyLocalPin(
        pin: '2468',
        salt: saltA,
        expectedHash: hashA,
        iterations: 10000,
      ),
      isTrue,
    );
    expect(
      verifyLocalPin(
        pin: '1357',
        salt: saltA,
        expectedHash: hashA,
        iterations: 10000,
      ),
      isFalse,
    );
  });

  test('PIN format and lockout policy are bounded', () {
    expect(isValidLocalPin('1234'), isTrue);
    expect(isValidLocalPin('12345678'), isTrue);
    expect(isValidLocalPin('123'), isFalse);
    expect(isValidLocalPin('12a4'), isFalse);

    final now = DateTime.utc(2026, 9, 28, 2);
    expect(
      localPinLockUntil(failedAttempts: 4, now: now),
      isNull,
    );
    expect(
      localPinLockUntil(failedAttempts: 5, now: now),
      now.add(const Duration(minutes: 5)),
    );
    expect(
      localPinLockUntil(failedAttempts: 10, now: now),
      now.add(const Duration(minutes: 30)),
    );
  });

  test('local session identity expires at its deadline', () {
    final identity = LocalSessionIdentity(
      employeeId: 'employee-1',
      employeeName: 'Cashier',
      role: EmployeeRole.cashier,
      authenticatedAt: DateTime.utc(2026, 9, 28, 2),
      expiresAt: DateTime.utc(2026, 9, 28, 14),
    );

    expect(identity.isExpired(DateTime.utc(2026, 9, 28, 13, 59)), isFalse);
    expect(identity.isExpired(DateTime.utc(2026, 9, 28, 14)), isTrue);
  });
}
