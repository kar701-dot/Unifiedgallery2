// lib/background_scan_worker.dart
//
// Android WorkManager background task entry point.
//
// This file is responsible for running pHash duplicate detection silently in
// the background when the user is not using the app.
//
// IMPORTANT: This runs in a HEADLESS isolate — no BuildContext, no widgets,
// no UI. Only pure Dart + plugins that support headless mode.
//
// What we do:
//   1. Initialize Flutter bindings + plugin registrations
//   2. Open Isar DB (same file path as the foreground app)
//   3. Load userId from SharedPreferences (saved by foreground app on login)
//   4. Fetch device-local photos that have no pHash yet
//   5. For each photo: compute pHash → save to Isar
//   6. Count duplicate sets → show notification if any found
//
// What we DON'T do in background:
//   - ML Kit AI scan (requires Android Activity context — crashes headless)
//   - Cloud photo scanning (OAuth tokens not accessible in isolate)

import 'dart:typed_data';
import 'dart:math' as math;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; // for WidgetsFlutterBinding
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image/image.dart' as img;

import 'ai_tag.dart';
import 'data/asset_repository.dart';
import 'data/person_record.dart';
import 'data/face_record.dart';
import 'services/face_scanner.dart';
import 'services/foreground_scanner.dart' show kFaceScanTaskName;

/// The unique task name used to register and deduplicate WorkManager tasks.
const String kBackgroundScanTaskName = 'background_phash_scan';

/// The unique task identifier string passed to WorkManager.
const String kBackgroundScanTaskId =
    'com.pranav.onedrivephotos.background_phash_scan';

/// Task name for the daily "On This Day" memories notification.
const String kMemoriesTaskName = 'memories_on_this_day';

/// Task identifier for the daily memories WorkManager task.
const String kMemoriesTaskId =
    'com.pranav.onedrivephotos.memories_on_this_day';

/// SharedPreferences key where the foreground app stores the current user ID.
/// MUST stay in sync with the key used in main.dart when the user logs in.
const String kPrefUserId = 'background_scan_user_id';

/// Top-level callback dispatcher — the single entry point WorkManager calls
/// when it wakes up the background isolate.
///
/// MUST be a top-level function (not a class method), annotated with
/// @pragma('vm:entry-point') so the Dart compiler doesn't tree-shake it.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // Initialize Flutter bindings in the background isolate.
    WidgetsFlutterBinding.ensureInitialized();

    debugPrint('[BG Worker] Task started: $taskName');

    if (taskName == kBackgroundScanTaskName) {
      try {
        await _runBackgroundPHashScan();
      } catch (e, st) {
        debugPrint('[BG Worker] pHash scan error: $e\n$st');
      }
    } else if (taskName == kFaceScanTaskName) {
      // Periodic face-scan-on-charge task registered by ForegroundScanner.
      // Reuses _runBackgroundPHashScan() which already handles both pHash
      // computation AND face scanning in the headless isolate.
      try {
        debugPrint('[BG Worker] Running face scan on charge...');
        await _runBackgroundPHashScan();
      } catch (e, st) {
        debugPrint('[BG Worker] Face scan on charge error: $e\n$st');
      }
    } else if (taskName == kMemoriesTaskName) {
      try {
        await _runMemoriesCheck();
      } catch (e, st) {
        debugPrint('[BG Worker] Memories check error: $e\n$st');
      }
    } else {
      debugPrint('[BG Worker] Unknown task: $taskName — skipping.');
    }

    return true;
  });
}

/// The main background scan logic.
Future<void> _runBackgroundPHashScan() async {
  // 1. Load userId from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString(kPrefUserId);
  if (userId == null || userId.isEmpty) {
    debugPrint('[BG Worker] No userId found — user not logged in. Skipping.');
    return;
  }
  debugPrint('[BG Worker] Running for userId: $userId');

  // 2. Open Isar DB
  late Isar isar;
  try {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [AITagSchema, AssetRecordSchema, PersonRecordSchema, FaceRecordSchema],
      directory: dir.path,
    );
  } catch (e) {
    debugPrint('[BG Worker] Failed to open Isar: $e');
    return;
  }

  final repo = AssetRepository(isar);

  try {
    // 3. Skip permission request entirely in WorkManager background isolate.
    // PhotoManager.requestPermissionExtend() always throws NullPointerException here
    // because WorkManager has no Activity context for showing the system dialog.
    // setIgnorePermissionCheck(true) tells photo_manager to bypass the permission
    // machinery entirely — the foreground app has already been granted access,
    // so getAssetPathList() works without re-requesting.
    PhotoManager.setIgnorePermissionCheck(true);

    // 4. Load all local device photos (images only)
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (paths.isEmpty) {
      debugPrint('[BG Worker] No photo paths found.');
      return;
    }

    final recentPath = paths.first;
    final int assetCount = await recentPath.assetCountAsync;
    if (assetCount == 0) {
      debugPrint('[BG Worker] No photos in library.');
      return;
    }

    // Initialize reusable FaceScannerService for the background run
    FaceScannerService? faceScanner;
    try {
      faceScanner = FaceScannerService();
    } catch (e) {
      debugPrint('[BG Worker] Could not init FaceScanner: $e');
    }

    // Load in pages of 50 to maintain low memory footprint in background
    const int pageSize = 50;
    int processed = 0;
    int newHashes = 0;

    for (int offset = 0; offset < assetCount; offset += pageSize) {
      final end = math.min(offset + pageSize, assetCount);
      final assets =
          await recentPath.getAssetListRange(start: offset, end: end);

      for (final asset in assets) {
        try {
          final uniqueKey = '$userId::local::${asset.id}';
          var record = await repo.findByKey(uniqueKey);

          // 1. Compute pHash if missing
          if (record?.pHashHex == null) {
            final bytes = await asset.thumbnailDataWithSize(
              const ThumbnailSize(200, 200),
            );
            if (bytes != null) {
              final pHashBigInt = _computePHash(bytes);
              final pHashHex = pHashBigInt.toRadixString(16);

              if (record == null) {
                final title = await asset.titleAsync;
                record = AssetRecord()
                  ..userId = userId
                  ..uniqueKey = uniqueKey
                  ..cloudFileId = asset.id
                  ..source = AssetSource.local
                  ..name = title ?? asset.id
                  ..isVideo = false
                  ..isFolder = false
                  ..createdAt = asset.createDateTime
                  ..pHashHex = pHashHex
                  ..pHashComputedAt = DateTime.now()
                  ..aiScanStatus = AiScanStatus.pending;
                await repo.upsert(record);
              } else {
                await repo.setPHash(uniqueKey, pHashBigInt);
              }
              newHashes++;
            }
          }

          // 2. Perform Face Scanning if not scanned yet
          final bool needsFaceScan = record == null ||
              (record.personIds == null &&
                  record.faceCount == 0 &&
                  record.aiScanStatus != AiScanStatus.skipped);

          if (faceScanner != null && needsFaceScan) {
            File? tempFile;
            try {
              final thumb512 = await asset.thumbnailDataWithSize(
                const ThumbnailSize(512, 512),
                quality: 85,
              );
              if (thumb512 != null && thumb512.isNotEmpty) {
                final tempDir = await getTemporaryDirectory();
                tempFile = File('${tempDir.path}/bg_face_${asset.id}.jpg');
                await tempFile.writeAsBytes(thumb512, flush: true);
                await faceScanner.processImageFile(
                  imageFile: tempFile,
                  assetKey: uniqueKey,
                  userId: userId,
                  isar: isar,
                );
              }
            } catch (e) {
              debugPrint('[BG Worker] Face scan error for ${asset.id}: $e');
            } finally {
              if (tempFile != null && await tempFile.exists()) {
                try {
                  await tempFile.delete();
                } catch (_) {}
              }
            }
          }

          processed++;

          // Gentle pause every 5 photos to keep CPU cool and thermals normal
          if (processed % 5 == 0) {
            await Future.delayed(const Duration(milliseconds: 60));
          }
        } catch (e) {
          debugPrint('[BG Worker] Failed processing ${asset.id}: $e');
        }
      }
    }

    try {
      faceScanner?.dispose();
    } catch (_) {}

    debugPrint(
        '[BG Worker] Done. $processed photos processed, $newHashes new pHashes.');

    // 5. If we computed new hashes, count duplicates and notify
    if (newHashes > 0) {
      final allRecords = await repo.findAll(userId);
      final duplicateCount = _countDuplicateSets(allRecords);

      debugPrint('[BG Worker] Found $duplicateCount duplicate sets.');

      if (duplicateCount > 0) {
        await _showDuplicateNotification(duplicateCount);
      }
    }
  } finally {
    await isar.close();
  }
}

/// Checks for "On This Day" photos and fires a memories notification if found.
///
/// Logic:
///   1. Load userId from SharedPreferences
///   2. Open Isar DB
///   3. Query photos taken on today's month+day in any prior year (>= 3 photos threshold)
///   4. Pick the year with the most photos
///   5. Show a local notification — tap opens gallery filtered to that date
Future<void> _runMemoriesCheck() async {
  // 1. Load userId
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString(kPrefUserId);
  if (userId == null || userId.isEmpty) {
    debugPrint('[Memories] No userId — skipping.');
    return;
  }

  // 2. Open Isar DB
  late Isar isar;
  try {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [AITagSchema, AssetRecordSchema, PersonRecordSchema, FaceRecordSchema],
      directory: dir.path,
    );
  } catch (e) {
    debugPrint('[Memories] Failed to open Isar: $e');
    return;
  }

  try {
    final repo = AssetRepository(isar);
    final memoriesByYear = await repo.findOnThisDay(userId, minCount: 3);

    if (memoriesByYear.isEmpty) {
      debugPrint('[Memories] No qualifying memories today — skipping notification.');
      return;
    }

    // 4. Pick the year with the most photos
    final bestEntry = memoriesByYear.entries
        .reduce((a, b) => a.value.length >= b.value.length ? a : b);
    final bestYear = bestEntry.key;
    final bestCount = bestEntry.value.length;
    final now = DateTime.now();
    final thisYear = now.year;
    final yearsAgo = thisYear - bestYear;
    final yearsAgoText = yearsAgo == 1 ? '1 year ago' : '$yearsAgo years ago';

    // Build ISO date payload so app can filter gallery to this exact day
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final isoDate = '$bestYear-$month-$day';

    debugPrint('[Memories] Notifying: $bestCount photos from $bestYear ($isoDate)');

    // 5. Initialize local notification plugin (required in background isolate)
    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: androidInit));

    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'memories_channel',
        'On This Day Memories',
        description:
            'Daily memories from your photo library — photos from this day in past years.',
        importance: Importance.defaultImportance,
      ),
    );

    final title = 'A memory from $yearsAgoText';
    final body = bestCount == 1
        ? 'You had 1 photo on this day in $bestYear — tap to relive it.'
        : 'You had $bestCount photos on this day in $bestYear — tap to relive them.';

    // Check if the top photo has a local cached image to show in notification preview
    BigPictureStyleInformation? bigPictureStyle;
    final topRecord = bestEntry.value.first;
    if (topRecord.thumbnailLocalPath != null &&
        File(topRecord.thumbnailLocalPath!).existsSync()) {
      bigPictureStyle = BigPictureStyleInformation(
        FilePathAndroidBitmap(topRecord.thumbnailLocalPath!),
        contentTitle: title,
        summaryText: body,
      );
    }

    await plugin.show(
      43, // Fixed ID: replaces previous memories notification
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'memories_channel',
          'On This Day Memories',
          channelDescription:
              'Daily memories from your photo library — photos from this day in past years.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
          styleInformation: bigPictureStyle ??
              BigTextStyleInformation(body, contentTitle: title),
        ),
      ),
      payload: 'open_memories:$isoDate',
    );

    debugPrint('[Memories] Done.');
  } finally {
    await isar.close();
  }
}

/// Counts duplicate sets using Hamming-distance clustering.
/// Mirrors the foreground `_findDuplicateSets` logic exactly.
int _countDuplicateSets(List<AssetRecord> records) {
  const int kThreshold = 10;

  final hashable = records
      .where((r) => !r.isVideo && !r.isFolder && r.pHashHex != null)
      .toList();

  if (hashable.length < 2) return 0;

  final hashes =
      hashable.map((r) => BigInt.parse(r.pHashHex!, radix: 16)).toList();

  final parent = List<int>.generate(hashable.length, (i) => i);

  int findRoot(int i) {
    while (parent[i] != i) {
      parent[i] = parent[parent[i]];
      i = parent[i];
    }
    return i;
  }

  for (int i = 0; i < hashes.length; i++) {
    for (int j = i + 1; j < hashes.length; j++) {
      if (_hammingDistance(hashes[i], hashes[j]) <= kThreshold) {
        final ri = findRoot(i);
        final rj = findRoot(j);
        if (ri != rj) parent[ri] = rj;
      }
    }
  }

  final Map<int, int> clusterSizes = {};
  for (int i = 0; i < hashes.length; i++) {
    clusterSizes[findRoot(i)] = (clusterSizes[findRoot(i)] ?? 0) + 1;
  }

  return clusterSizes.values.where((size) => size > 1).length;
}

/// Hamming distance between two 64-bit perceptual hashes.
int _hammingDistance(BigInt a, BigInt b) {
  BigInt xor = a ^ b;
  int distance = 0;
  while (xor > BigInt.zero) {
    xor = xor & (xor - BigInt.one);
    distance++;
  }
  return distance;
}

/// Compute a 64-bit perceptual hash from image bytes.
/// Mirrors `_computePHashIsolate` in main.dart.
BigInt _computePHash(Uint8List imageBytes) {
  final image = img.decodeImage(imageBytes);
  if (image == null) throw Exception('Could not decode image');

  final smallImage = img.copyResize(
    image,
    width: 8,
    height: 8,
    interpolation: img.Interpolation.linear,
  );

  final grayscale = List<int>.filled(64, 0);
  double totalLuminance = 0;
  for (int y = 0; y < 8; y++) {
    for (int x = 0; x < 8; x++) {
      final pixel = smallImage.getPixel(x, y);
      final lum =
          (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).round();
      grayscale[y * 8 + x] = lum;
      totalLuminance += lum;
    }
  }

  final avg = totalLuminance / 64.0;
  BigInt hash = BigInt.zero;
  for (int i = 0; i < 64; i++) {
    if (grayscale[i] >= avg) {
      hash = hash | (BigInt.one << i);
    }
  }
  return hash;
}

/// Show a local notification informing the user about found duplicates.
Future<void> _showDuplicateNotification(int duplicateSetCount) async {
  final plugin = FlutterLocalNotificationsPlugin();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: androidInit));

  final androidPlugin = plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      'duplicate_scan_channel',
      'Duplicate Scan Results',
      description:
          'Notifies you when the background duplicate photo scan is complete.',
      importance: Importance.defaultImportance,
    ),
  );

  final String body = duplicateSetCount == 1
      ? 'Found 1 group of duplicate photos. Tap to review and free up space.'
      : 'Found $duplicateSetCount groups of duplicate photos. Tap to review and free up space.';

  await plugin.show(
    42, // Fixed ID: replaces previous notification rather than stacking
    'Duplicate Photos Found',
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'duplicate_scan_channel',
        'Duplicate Scan Results',
        channelDescription:
            'Notifies you when the background duplicate photo scan is complete.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: 'open_duplicates',
  );

  debugPrint('[BG Worker] Notification shown for $duplicateSetCount sets.');
}
