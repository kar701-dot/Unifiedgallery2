// lib/services/foreground_scanner.dart
//
// Thermal-Aware On-Device Photo Scanner
//
// Scan behavior modeled after Google Photos:
//   • Smart scheduling: uses WorkManager to run scans only when CHARGING (idle/night/day)
//   • Thermal pacing: slows down when app is active (user is using phone), speeds up in background
//   • Pauses completely when user is scrolling (no jank)
//   • Runs post-scan agglomerative re-cluster pass to merge fragmented person clusters
//   • All users can benefit from face scan (no Pro gate needed for ML on local photos)

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/asset_repository.dart';
import 'face_scanner.dart';

// ---------------------------------------------------------------------------
// WorkManager task constants — registered once on app start
// ---------------------------------------------------------------------------
const String kFaceScanTaskName = 'face_scan_on_charge';
const String kFaceScanTaskId   = 'com.pranav.onedrivephotos.face_scan_on_charge';

// SharedPrefs key for throttling: timestamp of last scan start
const String kPrefLastScanTime = 'face_scanner_last_scan_epoch';

// Minimum gap between two foreground-triggered scans (30 minutes)
const Duration kMinScanInterval = Duration(minutes: 30);

class ForegroundScanner {
  // Singleton
  static final ForegroundScanner _instance = ForegroundScanner._internal();
  factory ForegroundScanner() => _instance;
  ForegroundScanner._internal();

  // State Notifiers for UI to listen to
  final ValueNotifier<bool>   isScanning = ValueNotifier(false);
  final ValueNotifier<int>    progress   = ValueNotifier(0);
  final ValueNotifier<int>    total      = ValueNotifier(0);
  final ValueNotifier<String> status     = ValueNotifier('');

  bool _cancelRequested = false;
  bool isUserScrolling  = false;

  // ---------------------------------------------------------------------------
  // WorkManager Integration — registers periodic background scan (charging only)
  // ---------------------------------------------------------------------------

  /// Call once at app startup (after WorkManager.initialize() in main()).
  /// Registers a periodic task that fires every 6 hours ONLY when charging.
  static Future<void> registerBackgroundScanTask() async {
    try {
      await Workmanager().registerPeriodicTask(
        kFaceScanTaskId,
        kFaceScanTaskName,
        frequency: const Duration(hours: 6),
        constraints: Constraints(
          requiresCharging: true,          // Only runs when plugged in
          networkType: NetworkType.not_required,
          requiresBatteryNotLow: false,
        ),
        existingWorkPolicy: ExistingWorkPolicy.keep, // FIX: workmanager 0.6.0 uses ExistingWorkPolicy (not ExistingPeriodicWorkPolicy)
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 10),
      );
      debugPrint('[ForegroundScanner] Background face scan task registered (charging only, every 6h).');
    } catch (e) {
      debugPrint('[ForegroundScanner] WorkManager registration error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Smart Throttle: prevent hammering on every lifecycle resume
  // ---------------------------------------------------------------------------

  /// Returns true if enough time has passed since the last scan to start a new one.
  static Future<bool> shouldStartScan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(kPrefLastScanTime) ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastMs;
      return elapsed >= kMinScanInterval.inMilliseconds;
    } catch (_) {
      return true;
    }
  }

  static Future<void> _markScanStarted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kPrefLastScanTime, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Main Scan Entry Point
  // ---------------------------------------------------------------------------

  /// Starts scanning all unseen/pending photos.
  /// Thermally-paced: slow when foreground, fast when background+charging.
  Future<void> startScan(String userId, AssetRepository repo) async {
    if (isScanning.value) return;

    _cancelRequested = false;
    isScanning.value = true;
    progress.value   = 0;
    total.value      = 0;
    status.value     = 'Starting scan...';

    await _markScanStarted();

    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth && !ps.hasAccess) {
        status.value    = 'Permission denied.';
        isScanning.value = false;
        return;
      }

      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      if (paths.isEmpty) {
        status.value    = 'No photos found.';
        isScanning.value = false;
        return;
      }

      final recentPath  = paths.first;
      final int totalAssets = await recentPath.assetCountAsync;

      if (totalAssets == 0) {
        status.value    = 'No photos found.';
        isScanning.value = false;
        return;
      }

      total.value = totalAssets;
      int processedCount = 0;
      int offset = 0;

      while (offset < totalAssets) {
        if (_cancelRequested) break;

        // Thermal pacing: tiny pages in foreground to reduce memory pressure,
        // larger batches in background (charging) for maximum throughput.
        final int pageSize = _isAppActive ? 1 : 50;
        final end = math.min(offset + pageSize, totalAssets);
        final assets = await recentPath.getAssetListRange(start: offset, end: end);

        for (final asset in assets) {
          if (_cancelRequested) break;

          status.value = 'Scanning... $processedCount / $totalAssets';

          try {
            // Pause completely while user is actively scrolling
            while (_isAppActive && isUserScrolling) {
              await Future.delayed(const Duration(milliseconds: 200));
            }
            await _processSingleAsset(asset, userId, repo);
          } catch (e) {
            debugPrint('[ForegroundScanner] Error on ${asset.id}: $e');
          }

          processedCount++;
          progress.value = processedCount;

          await _yieldForLifecycle(processedCount);
        }

        offset += pageSize;
      }

      if (!_cancelRequested) {
        // Post-scan: run agglomerative re-cluster pass to merge fragmented clusters
        status.value = 'Grouping faces...';
        try {
          final mergeCount = await FaceScannerService.reclusterAll(userId, repo.isar);
          if (mergeCount > 0) {
            debugPrint('[ForegroundScanner] Post-scan merged $mergeCount cluster pairs.');
          }
        } catch (e) {
          debugPrint('[ForegroundScanner] reclusterAll error: $e');
        }
        status.value = 'Scan complete ✓';
      } else {
        status.value = 'Scan paused';
      }

    } catch (e, st) {
      debugPrint('[ForegroundScanner] Fatal error: $e\n$st');
      status.value = 'Scan failed: $e';
    } finally {
      _faceScanner?.dispose();
      _faceScanner = null;
      await Future.delayed(const Duration(seconds: 2));
      isScanning.value = false;
    }
  }

  void cancelScan() {
    _cancelRequested = true;
  }

  // ---------------------------------------------------------------------------
  // Thermal-Aware Lifecycle Pacing
  // ---------------------------------------------------------------------------

  /// True when the app is currently in the foreground (user is looking at it).
  bool get _isAppActive {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == AppLifecycleState.resumed || state == null;
  }

  /// Thermally-paced pause between photos.
  ///
  /// • Scrolling:   wait until stopped (no jank)
  /// • Foreground:  80ms per photo, 300ms every 5 (cool-down cycle)
  /// • Background:  15ms (fast, device is idle)
  Future<void> _yieldForLifecycle(int processedIndex) async {
    while (_isAppActive && isUserScrolling) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (!_isAppActive) {
      await Future.delayed(const Duration(milliseconds: 15));
    } else {
      if (processedIndex % 5 == 0) {
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        await Future.delayed(const Duration(milliseconds: 80));
      }
    }
  }

  /// Micro-yield between ML Kit operations (image labeling → face detection → OCR).
  Future<void> _yieldInsideOperation() async {
    while (_isAppActive && isUserScrolling) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    await Future.delayed(const Duration(milliseconds: 25));
  }

  // ---------------------------------------------------------------------------
  // Per-Asset Processing
  // ---------------------------------------------------------------------------

  Future<void> _processSingleAsset(
    AssetEntity asset,
    String userId,
    AssetRepository repo,
  ) async {
    final uniqueKey = '$userId::local::${asset.id}';
    AssetRecord? record = await repo.findByKey(uniqueKey);

    // 1. Compute pHash if missing
    if (record?.pHashHex == null) {
      final bytes = await asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));
      if (bytes != null) {
        final pHashHex = await compute(_computePHashIsolated, bytes);

        if (record == null) {
          final title = await asset.titleAsync;
          record = AssetRecord()
            ..userId = userId
            ..uniqueKey = uniqueKey
            ..cloudFileId = asset.id
            ..source = AssetSource.local
            ..name = title
            ..isVideo = false
            ..isFolder = false
            ..createdAt = asset.createDateTime
            ..pHashHex = pHashHex
            ..pHashComputedAt = DateTime.now()
            ..aiScanStatus = AiScanStatus.pending;
          await repo.upsert(record);
        } else {
          await repo.setPHash(uniqueKey, BigInt.parse(pHashHex, radix: 16));
          record = await repo.findByKey(uniqueKey);
        }
      }
    }

    // 2. AI Scan if pending or face-scan not yet done
    final needsAiScan = record != null &&
        !record.isVideo &&
        !record.isFolder &&
        (record.aiScanStatus == AiScanStatus.pending ||
         record.needsRescan ||
         (record.personIds == null && record.faceCount == 0));

    if (needsAiScan) {
      await _runAiScan(asset, uniqueKey, repo, userId);
    }
  }

  FaceScannerService? _faceScanner;

  FaceScannerService _getFaceScanner() {
    return _faceScanner ??= FaceScannerService();
  }

  Future<void> _runAiScan(AssetEntity asset, String uniqueKey, AssetRepository repo, String userId) async {
    File? scanFile;
    File? tempThumbFile;

    try {
      // Fetch 512px thumbnail (hardware-cached by OS, optimal for NPU/DSP efficiency)
      final thumbBytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize(512, 512),
        quality: 85,
      );

      if (thumbBytes != null && thumbBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        tempThumbFile = File('${tempDir.path}/ai_scan_${asset.id}.jpg');
        await tempThumbFile.writeAsBytes(thumbBytes, flush: true);
        scanFile = tempThumbFile;
      }
    } catch (_) {}

    scanFile ??= await asset.file;
    if (scanFile == null) return;

    final inputImage = InputImage.fromFile(scanFile);

    List<String> tags = [];
    List<String>? detectedObjects;
    String? recognizedText;

    try {
      final labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
      final labels  = await labeler.processImage(inputImage);
      tags = labels.map((e) => e.label).toList();
      await labeler.close();
      await _yieldInsideOperation();
    } catch (e) {
      debugPrint('[ForegroundScanner] Labeling failed: $e');
    }

    try {
      final objectDetector = ObjectDetector(
        options: ObjectDetectorOptions(
          mode: DetectionMode.single,
          classifyObjects: true,
          multipleObjects: true,
        ),
      );
      final objects    = await objectDetector.processImage(inputImage);
      final objLabels  = objects.expand((o) => o.labels).map((l) => l.text).where((t) => t.isNotEmpty).toSet().toList();
      if (objLabels.isNotEmpty) detectedObjects = objLabels;
      await objectDetector.close();
      await _yieldInsideOperation();
    } catch (e) {
      debugPrint('[ForegroundScanner] Object detection failed: $e');
    }

    try {
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result         = await textRecognizer.processImage(inputImage);
      if (result.text.trim().isNotEmpty) recognizedText = result.text.trim();
      await textRecognizer.close();
      await _yieldInsideOperation();
    } catch (e) {
      debugPrint('[ForegroundScanner] OCR failed: $e');
    }

    try {
      final faceScanner = _getFaceScanner();
      await faceScanner.processImageFile(
        imageFile: scanFile,
        assetKey: uniqueKey,
        userId: userId,
        isar: repo.isar,
      );
    } catch (e) {
      debugPrint('[ForegroundScanner] Face detection failed: $e');
    } finally {
      try {
        if (tempThumbFile != null && await tempThumbFile.exists()) {
          await tempThumbFile.delete();
        }
      } catch (_) {}
    }

    await repo.setAiScanStatus(
      uniqueKey,
      AiScanStatus.done,
      tags: tags,
      recognizedText: recognizedText,
      detectedObjects: detectedObjects,
    );
  }
}

// ---------------------------------------------------------------------------
// Isolate-friendly top-level function for pHash computation
// ---------------------------------------------------------------------------
String _computePHashIsolated(Uint8List imageBytes) {
  final image = img.decodeImage(imageBytes);
  if (image == null) throw Exception('Could not decode image');

  final smallImage = img.copyResize(image, width: 8, height: 8, interpolation: img.Interpolation.linear);

  final grayscale      = List<int>.filled(64, 0);
  double totalLuminance = 0;
  for (int y = 0; y < 8; y++) {
    for (int x = 0; x < 8; x++) {
      final pixel = smallImage.getPixel(x, y);
      final lum   = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).round();
      grayscale[y * 8 + x] = lum;
      totalLuminance += lum;
    }
  }

  final avg  = totalLuminance / 64.0;
  BigInt hash = BigInt.zero;
  for (int i = 0; i < 64; i++) {
    if (grayscale[i] >= avg) {
      hash = hash | (BigInt.one << i);
    }
  }
  return hash.toRadixString(16);
}
