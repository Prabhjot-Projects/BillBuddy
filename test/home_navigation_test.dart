import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/core/utils/result.dart';
import 'package:billbuddy/data/entities/friend.dart';
import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/presentation/screens/dashboard/home_screen.dart';
import 'package:billbuddy/processes/receipt/receipt_repository.dart';
import 'package:billbuddy/processes/social/friend_repository.dart';
import 'package:billbuddy/services/currency/currency_controller.dart';
import 'package:billbuddy/services/storage/local/user_profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReceiptRepository implements ReceiptRepository {
  @override
  Future<Result<void>> confirm(Receipt receipt) async => Result.success(null);

  @override
  Future<Result<void>> delete(String id) async => Result.success(null);

  @override
  Future<Result<int>> deleteStaleDrafts(Duration olderThan) async =>
      Result.success(0);

  @override
  Future<Result<List<Receipt>>> getAllConfirmed() async =>
      Result.success(const []);

  @override
  Future<Result<List<Receipt>>> getAllDrafts() async =>
      Result.success(const []);

  @override
  Future<Result<Receipt?>> getById(String id) async => Result.success(null);

  @override
  Future<Result<List<Receipt>>> getByGroupId(String groupId) async =>
      Result.success(const []);

  @override
  Future<Result<void>> saveDraft(Receipt receipt) async => Result.success(null);
}

class _FakeFriendRepository implements FriendRepository {
  @override
  Future<Result<void>> add(Friend friend) async => Result.success(null);

  @override
  Future<Result<void>> delete(String id) async => Result.success(null);

  @override
  Future<Result<List<Friend>>> getAll() async => Result.success(const []);
}

class _FakeUserProfileService implements UserProfileService {
  @override
  Future<Result<String?>> getDisplayName() async => Result.success('Test User');

  @override
  Future<Result<String>> getUserId() async => Result.success('test-user');

  @override
  Future<Result<void>> setDisplayName(String name) async =>
      Result.success(null);
}

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<ReceiptRepository>(_FakeReceiptRepository());
    getIt.registerSingleton<FriendRepository>(_FakeFriendRepository());
    getIt.registerSingleton<UserProfileService>(_FakeUserProfileService());
    getIt.registerSingleton<CurrencyController>(CurrencyController());
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('dashboard exposes scan and manual bill entry points', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Scan receipt'), findsNWidgets(2));
    expect(find.text('Manual bill'), findsNothing);
    expect(find.text('Balances'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Bills'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('History'), findsNothing);
  });
}
