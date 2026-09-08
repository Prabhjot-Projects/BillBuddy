import 'dart:io';

import 'package:billbuddy/processes/receipt/item_assignment_repository.dart';
import 'package:billbuddy/processes/receipt/receipt_repository.dart';
import 'package:billbuddy/processes/receipt/receipt_image_repository.dart';
import 'package:billbuddy/processes/receipt/payment_repository.dart';
import 'package:billbuddy/processes/receipt/receipt_event_repository.dart';
import 'package:billbuddy/processes/receipt/receipt_scan_pipeline.dart';
import 'package:billbuddy/processes/receipt/receipt_text_extractor.dart';
import 'package:billbuddy/processes/receipt/receipt_validator.dart';
import 'package:billbuddy/processes/social/friend_repository.dart';
import 'package:billbuddy/processes/social/group_repository.dart';
import 'package:billbuddy/services/ai/ai_receipt_parser.dart';
import 'package:billbuddy/services/ai/receipt_parser.dart';
import 'package:billbuddy/services/camera/camera.dart';
import 'package:billbuddy/services/camera/camera_service.dart';
import 'package:billbuddy/services/ocr/google_ocr_service.dart';
import 'package:billbuddy/services/ocr/native_ocr_service.dart';
import 'package:billbuddy/services/ocr/ocr_service.dart';
import 'package:billbuddy/services/storage/local/app_settings_service.dart';
import 'package:billbuddy/services/storage/local/database_service.dart';
import 'package:billbuddy/services/storage/local/data_export_service.dart';
import 'package:billbuddy/services/storage/local/image_storage_service.dart';
import 'package:billbuddy/services/storage/local/local_image_storage_service.dart';
import 'package:billbuddy/services/storage/local/shared_prefs_app_settings_service.dart';
import 'package:billbuddy/services/storage/local/shared_prefs_user_profile_service.dart';
import 'package:billbuddy/services/storage/local/sqlite_friend_repository.dart';
import 'package:billbuddy/services/storage/local/sqlite_group_repository.dart';
import 'package:billbuddy/services/storage/local/sqlite_item_assignment_repository.dart';
import 'package:billbuddy/services/storage/local/sqlite_receipt_repository.dart';
import 'package:billbuddy/services/storage/local/sqlite_receipt_image_repository.dart';
import 'package:billbuddy/services/storage/local/sqlite_payment_repository.dart';
import 'package:billbuddy/services/storage/local/sqlite_receipt_event_repository.dart';
import 'package:billbuddy/services/currency/currency_controller.dart';
import 'package:billbuddy/services/storage/local/user_profile_service.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

/// Registers services that have no async setup — must run after
/// DatabaseService.initialize() has already completed, since several
/// registrations below read `getIt<DatabaseService>()` eagerly.
void setupServiceLocator() {
  getIt.registerFactory<Camera>(() => CameraService());

  getIt.registerSingleton<OcrService>(
    Platform.isIOS ? NativeOcrService() : GoogleOcrService(),
  );

  getIt.registerSingleton<ReceiptValidator>(ReceiptValidator());

  getIt.registerSingleton<ReceiptParser>(AiReceiptParser());

  getIt.registerSingleton<ImageStorageService>(LocalImageStorageService());

  getIt.registerSingleton<ReceiptRepository>(
    SqliteReceiptRepository(databaseService: getIt<DatabaseService>()),
  );
  getIt.registerSingleton<ReceiptImageRepository>(
    SqliteReceiptImageRepository(databaseService: getIt<DatabaseService>()),
  );
  getIt.registerSingleton<PaymentRepository>(
    SqlitePaymentRepository(getIt<DatabaseService>()),
  );
  getIt.registerSingleton<ReceiptEventRepository>(
    SqliteReceiptEventRepository(getIt<DatabaseService>()),
  );

  getIt.registerSingleton<FriendRepository>(
    SqliteFriendRepository(databaseService: getIt<DatabaseService>()),
  );

  getIt.registerSingleton<GroupRepository>(
    SqliteGroupRepository(databaseService: getIt<DatabaseService>()),
  );

  getIt.registerSingleton<ItemAssignmentRepository>(
    SqliteItemAssignmentRepository(databaseService: getIt<DatabaseService>()),
  );

  getIt.registerSingleton<UserProfileService>(SharedPrefsUserProfileService());

  getIt.registerSingleton<AppSettingsService>(SharedPrefsAppSettingsService());
  getIt.registerSingleton<CurrencyController>(CurrencyController());
  getIt.registerSingleton<DataExportService>(
    DataExportService(getIt<DatabaseService>()),
  );

  getIt.registerSingleton<ReceiptTextExtractor>(
    ReceiptTextExtractor(
      ocrService: getIt<OcrService>(),
      receiptValidator: getIt<ReceiptValidator>(),
    ),
  );

  // Registered after ReceiptTextExtractor since it depends on it, plus
  // ReceiptParser, ImageStorageService, and ReceiptRepository, all of
  // which must already be registered above.
  getIt.registerSingleton<ReceiptScanPipeline>(
    ReceiptScanPipeline(
      textExtractor: getIt<ReceiptTextExtractor>(),
      parser: getIt<ReceiptParser>(),
      imageStorage: getIt<ImageStorageService>(),
      receiptRepository: getIt<ReceiptRepository>(),
      receiptImageRepository: getIt<ReceiptImageRepository>(),
    ),
  );
}
