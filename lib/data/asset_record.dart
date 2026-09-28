// lib/data/asset_record.dart
//
// Isar collection schema for the Centralized Asset Tracking System.
//
// IMPORTANT: After editing this file, run:
//   dart run build_runner build --delete-conflicting-outputs
//
// This regenerates lib/data/asset_record.g.dart.
// Do NOT edit the .g.dart file manually.

import 'package:isar/isar.dart';

part 'asset_record.g.dart';

// ---------------------------------------------------------------------------
// Companion constant classes (Isar cannot store Dart enums directly)
// ---------------------------------------------------------------------------

/// Source constants mirroring PhotoSource enum from main.dart.
/// Values MUST stay in sync with PhotoSource.index:
///   oneDrive=0, dropbox=1, googleDrive=2, box=3, pCloud=4, mega=5, local=6
class AssetSource {
  AssetSource._(); // prevent instantiation

  static const int oneDrive = 0;
  static const int dropbox = 1;
  static const int googleDrive = 2;
  static const int box = 3;
  static const int pCloud = 4;
  static const int mega = 5;
  static const int local = 6;

  static const List<String> names = [
    'OneDrive',
    'Dropbox',
    'Google Drive',
    'Box',
    'pCloud',
    'Mega',
    'Device',
  ];

  static String displayName(int source) =>
      (source >= 0 && source < names.length) ? names[source] : 'Unknown';
}

/// AI scan status constants for [AssetRecord.aiScanStatus].
class AiScanStatus {
  AiScanStatus._(); // prevent instantiation

  /// Asset has not been scanned yet.
  static const int pending = 0;

  /// Scan is currently running for this asset.
  static const int scanning = 1;

  /// Scan completed successfully; [AssetRecord.aiTags] is populated.
  static const int done = 2;

  /// Scan failed (network error, decode error, etc.).
  static const int failed = 3;

  /// Asset type is not supported (folder, doc, unknown format).
  static const int skipped = 4;
}

// ---------------------------------------------------------------------------
// Main schema
// ---------------------------------------------------------------------------

/// Persisted metadata record for every photo/video asset across all sources.
///
/// One row per unique asset. The primary key for lookup is [uniqueKey],
/// which is built the same way as [DriveItem.getUniqueKey()]:
///   '\${PhotoSource.name}::\${fileId}'
///
/// Design principle: this record is the single source of truth for asset
/// metadata. All future features (Cloud Hub, AI search, duplicate detection,
/// smart albums) query this collection rather than calling cloud APIs.
@collection
class AssetRecord {
  // -------------------------------------------------------------------------
  // Isar primary key (auto-increment, internal only)
  // -------------------------------------------------------------------------
  Id id = Isar.autoIncrement;

  // -------------------------------------------------------------------------
  // IDENTITY
  // -------------------------------------------------------------------------

  /// The Firebase User ID to whom this asset belongs.
  /// This ensures multi-user isolation on the same device.
  @Index()
  late String userId;

  /// Stable, unique key for this asset across the entire app.
  /// Format: '\${userId}::\${sourceName}::\${cloudFileId}'
  /// Matches DriveItem.getUniqueKey() with user prefix so existing code can look up records.
  @Index(type: IndexType.hash, unique: true)
  late String uniqueKey;

  /// Raw file/asset ID from the cloud provider (or local asset ID for device
  /// photos). Combined with [source], this uniquely identifies an asset.
  late String cloudFileId;

  /// Cloud/local source. Use [AssetSource] constants.
  /// Mirrors PhotoSource.index from main.dart — do NOT change the int values.
  @Index()
  late int source;

  // -------------------------------------------------------------------------
  // FILE METADATA
  // -------------------------------------------------------------------------

  /// File name including extension (e.g. 'IMG_2024.jpg').
  late String name;

  /// File size in bytes. Null for folders or when not provided by the API.
  int? size;

  /// MIME type string (e.g. 'image/jpeg', 'video/mp4').
  /// Null if not provided by the cloud API.
  String? mimeType;

  /// True if this is a video file.
  bool isVideo = false;

  /// True if this is a folder (not a file).
  bool isFolder = false;

  /// File creation date as reported by the cloud provider.
  DateTime? createdAt;

  // -------------------------------------------------------------------------
  // SYNC TRACKING
  // -------------------------------------------------------------------------

  /// Updated every time this asset is observed during a cloud sync pass.
  ///
  /// Usage: compare against the sync start time to detect deletions:
  ///   if lastSeenAt < syncStartedAt → asset was not found → likely deleted.
  DateTime? lastSeenAt;

  /// When this record was first created or last fully refreshed from cloud.
  DateTime? syncedAt;

  /// Cloud-provided ETag, version, or revision string.
  /// Used to detect server-side changes without re-downloading the file.
  String? cloudEtag;

  // -------------------------------------------------------------------------
  // HASHES
  // -------------------------------------------------------------------------

  /// Perceptual hash stored as a hexadecimal string.
  ///
  /// pHash detects VISUALLY SIMILAR images (rotations, crops, light edits).
  /// Null until the pHash computation worker has processed this asset.
  /// Use [pHashComputedAt] to know if it's stale.
  ///
  /// Convert back: BigInt.parse(pHashHex!, radix: 16)
  String? pHashHex;

  /// When [pHashHex] was last computed. Null if never computed.
  DateTime? pHashComputedAt;

  /// Content hash (SHA-256 hex string).
  ///
  /// contentHash detects BYTE-FOR-BYTE IDENTICAL files.
  /// Combined with pHash, this gives two levels of duplicate detection:
  ///   - contentHash match = exact duplicate (safe to delete one)
  ///   - pHash match only  = visually similar (review before deleting)
  ///
  /// Null until the file has been downloaded and hashed.
  @Index(type: IndexType.hash)
  String? contentHash;

  // -------------------------------------------------------------------------
  // AI TAGGING
  // -------------------------------------------------------------------------

  /// Tags produced by the ML Kit image labeler (e.g. ['sunset', 'beach']).
  /// Null until an AI scan has completed for this asset.
  List<String>? aiTags;

  /// Current scan state. Use [AiScanStatus] constants.
  /// Indexed so the AI scanner can efficiently query pending/failed assets.
  @Index()
  int aiScanStatus = AiScanStatus.pending;

  // -------------------------------------------------------------------------
  // PHASE 1 ENHANCEMENTS: OCR + OBJECT DETECTION
  // -------------------------------------------------------------------------

  /// Raw text extracted from the image by ML Kit Text Recognition (OCR).
  ///
  /// Populated for screenshots, receipts, documents, signboards, whiteboards.
  /// Enables searching a photo by text visible inside it
  /// (e.g. search "wifi password" → finds your sticky-note photo).
  /// Null until an OCR scan has run, or empty string if no text was found.
  String? recognizedText;

  /// Object labels from ML Kit Object Detector.
  List<String>? detectedObjects;

  // -------------------------------------------------------------------------
  // FACE DETECTION & PERSON CLUSTERING
  // -------------------------------------------------------------------------

  /// Total faces detected in this asset by Google ML Kit Face Detector.
  int faceCount = 0;

  /// Person cluster IDs associated with faces found in this photo.
  List<String>? personIds;


  // -------------------------------------------------------------------------
  // DUPLICATE TRACKING
  // -------------------------------------------------------------------------

  /// True if this asset has been identified as a duplicate of another asset.
  bool isDuplicate = false;

  /// All assets in the same duplicate cluster share this group ID.
  /// Null for assets that are not duplicates.
  @Index(type: IndexType.hash)
  String? duplicateGroupId;

  // -------------------------------------------------------------------------
  // URL / THUMBNAIL CACHE
  // -------------------------------------------------------------------------

  /// Last fetched download URL from the cloud provider.
  /// May be a short-lived signed URL — check [downloadUrlExpiresAt] before use.
  String? downloadUrlCached;

  /// When [downloadUrlCached] expires. Null = no expiry or unknown.
  DateTime? downloadUrlExpiresAt;

  /// Absolute path to a locally cached thumbnail image file on disk.
  /// Null if no local thumbnail has been saved.
  String? thumbnailLocalPath;

  // -------------------------------------------------------------------------
  // USER STATE  (local mirror of Firestore data)
  // -------------------------------------------------------------------------

  /// Whether the user has moved this asset to the Bin.
  bool isInBin = false;

  /// Whether the user has marked this asset as a Favorite.
  bool isFavorite = false;

  /// IDs of albums this asset belongs to.
  List<String>? albumIds;

  // -------------------------------------------------------------------------
  // RESCAN FLAG
  // -------------------------------------------------------------------------

  /// When true, this asset should be reprocessed on the next scan pass.
  ///
  /// Set this flag instead of wiping all scan data:
  ///   - AI model updated → mark all assets needsRescan = true
  ///   - Duplicate algorithm changed → mark all needsRescan = true
  ///   - User edits metadata → mark that one asset needsRescan = true
  ///
  /// The scan worker queries WHERE needsRescan = true, processes only those,
  /// then clears the flag on completion. Much cheaper than a full rescan.
  @Index()
  bool needsRescan = false;
}
