import 'package:aaraapos_pos/sync/sync_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sync lifecycle is explicit and one-way after acknowledgement', () {
    expect(
      nextLocalSyncState(LocalSyncState.pending, 'send'),
      LocalSyncState.sending,
    );
    expect(
      nextLocalSyncState(LocalSyncState.sending, 'acknowledge'),
      LocalSyncState.acknowledged,
    );
    expect(
      () => nextLocalSyncState(LocalSyncState.acknowledged, 'retry'),
      throwsStateError,
    );
  });

  test('conflict classes preserve financial and configuration semantics', () {
    expect(
      syncConflictClassForEntity('sale'),
      SyncConflictClass.appendOnlyFinancial,
    );
    expect(
      syncConflictClassForEntity('stock_movement'),
      SyncConflictClass.inventoryMovement,
    );
    expect(
      syncConflictClassForEntity('loyalty_program'),
      SyncConflictClass.configurationSecurity,
    );
    expect(
      syncConflictClassForEntity('customer'),
      SyncConflictClass.masterData,
    );
  });
}
