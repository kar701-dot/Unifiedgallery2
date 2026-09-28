// lib/data/asset_repository.dart
//
// Centralized data-access service for [AssetRecord].
//
// CONTRACT:
//   - Pure data layer. No HTTP, no widget state, no business logic.
//   - All Isar reads/writes go through this class.
//   - Callers (main.dart, future feature modules) import this file only.
//     They never import Isar directly (except main.dart for initialization).
//
// CIRCULAR IMPORT NOTE:
//   DriveItem and PhotoSource are defined in main.dart.
//   To avoid importing main.dart here, callers use [AssetRepository.fromFields]
//   and pass primitive values. The mapping from DriveItem → fields happens
//   at the call site inside main.dart, not here.

import 'package:isar/isar.dart';
import 'asset_record.dart';

export 'asset_record.dart' show AssetRecord, AssetRecordSchema, AssetSource, AiScanStatus;

/// Centralized service for all [AssetRecord] persistence operations.
///
/// Obtain the singleton instance via the global [assetRepository] variable
/// defined in main.dart after Isar is initialized.
///
/// Usage example (inside main.dart or any widget state):
/// ```dart
/// final record = AssetRepository.fromFields(
///   uniqueKey: item.getUniqueKey(),
///   cloudFileId: item.id,
///   source: item.source.index,
///   name: item.name,
/// );
/// await assetRepository.upsert(record);
/// ```
class AssetRepository {
  final Isar _isar;

  const AssetRepository(this._isar);

  Isar get isar => _isar;

  // ===========================================================================
  // WRITE OPERATIONS
  // ===========================================================================

  /// Insert or update a single [AssetRecord].
  ///
  /// Matching is done by [AssetRecord.uniqueKey] (the unique index).
  /// If a record with the same key exists, it is fully replaced.
  Future<void> upsert(AssetRecord record) async {
    final existing = await findByKey(record.uniqueKey);
    if (existing != null) {
      record.id = existing.id;
    }
    await _isar.writeTxn(() => _isar.assetRecords.put(record));
  }

  /// Insert or update multiple [AssetRecord]s in a single transaction.
  ///
  /// Prefer this over calling [upsert] in a loop — it's significantly faster
  /// for batches of 50+ records.
  Future<void> upsertAll(List<AssetRecord> records) async {
    if (records.isEmpty) return;
    final keys = records.map((r) => r.uniqueKey).toList();
    await _isar.writeTxn(() async {
      // Find all existing records with these keys to resolve IDs
      final existingRecords = await _isar.assetRecords
          .filter()
          .anyOf(keys, (q, key) => q.uniqueKeyEqualTo(key))
          .findAll();
      final keyToIdMap = {for (var r in existingRecords) r.uniqueKey: r.id};
      
      for (final record in records) {
        final id = keyToIdMap[record.uniqueKey];
        if (id != null) {
          record.id = id;
        }
      }
      await _isar.assetRecords.putAll(records);
    });
  }

  /// Stamp [lastSeenAt] on each key in [uniqueKeys] to the given [seenAt] time.
  ///
  /// Call this for every asset found during a sync pass. Assets whose
  /// [lastSeenAt] remains older than the sync-start time may have been
  /// deleted from the cloud — see [findStale].
  Future<void> markSeen(List<String> uniqueKeys, DateTime seenAt) async {
    if (uniqueKeys.isEmpty) return;
    await _isar.writeTxn(() async {
      final records = await _isar.assetRecords
          .filter()
          .anyOf(uniqueKeys, (q, key) => q.uniqueKeyEqualTo(key))
          .findAll();
      for (final r in records) {
        r.lastSeenAt = seenAt;
      }
      if (records.isNotEmpty) await _isar.assetRecords.putAll(records);
    });
  }

  /// Update the AI scan status and optionally store resulting [tags],
  /// [recognizedText] (OCR), and [detectedObjects] (Phase 1 enhancements).
  ///
  /// When [status] is [AiScanStatus.done] or [AiScanStatus.failed],
  /// [needsRescan] is automatically cleared.
  Future<void> setAiScanStatus(
    String uniqueKey,
    int status, {
    List<String>? tags,
    String? recognizedText,
    List<String>? detectedObjects,
  }) async {
    final record = await findByKey(uniqueKey);
    if (record == null) return;
    await _isar.writeTxn(() async {
      record.aiScanStatus = status;
      if (tags != null) record.aiTags = tags;
      if (recognizedText != null && recognizedText.isNotEmpty) {
        record.recognizedText = recognizedText;
      }
      if (detectedObjects != null && detectedObjects.isNotEmpty) {
        record.detectedObjects = detectedObjects;
      }
      if (status == AiScanStatus.done || status == AiScanStatus.failed) {
        record.needsRescan = false;
      }
      await _isar.assetRecords.put(record);
    });
  }

  /// Store the computed perceptual hash for an asset.
  ///
  /// [hash] is a BigInt (as computed by the existing pHash logic in main.dart).
  /// It is stored as a hex string in [AssetRecord.pHashHex].
  Future<void> setPHash(String uniqueKey, BigInt hash) async {
    final record = await findByKey(uniqueKey);
    if (record == null) return;
    await _isar.writeTxn(() async {
      record.pHashHex = hash.toRadixString(16);
      record.pHashComputedAt = DateTime.now();
      await _isar.assetRecords.put(record);
    });
  }

  /// Store the content hash (SHA-256 or MD5 hex string) for an asset.
  ///
  /// [hash] should be a lowercase hex string produced by crypto package:
  /// ```dart
  /// import 'package:crypto/crypto.dart' as crypto;
  /// final hash = crypto.sha256.convert(bytes).toString();
  /// await assetRepository.setContentHash(key, hash);
  /// ```
  Future<void> setContentHash(String uniqueKey, String hash) async {
    final record = await findByKey(uniqueKey);
    if (record == null) return;
    await _isar.writeTxn(() async {
      record.contentHash = hash;
      await _isar.assetRecords.put(record);
    });
  }

  /// Mark specific assets as requiring reprocessing.
  ///
  /// Use when a targeted change affects only certain assets
  /// (e.g., user edited metadata on one photo).
  Future<void> markNeedsRescan(List<String> uniqueKeys) async {
    if (uniqueKeys.isEmpty) return;
    await _isar.writeTxn(() async {
      final records = await _isar.assetRecords
          .filter()
          .anyOf(uniqueKeys, (q, key) => q.uniqueKeyEqualTo(key))
          .findAll();
      for (final r in records) {
        r.needsRescan = true;
      }
      if (records.isNotEmpty) await _isar.assetRecords.putAll(records);
    });
  }

  /// Mark ALL assets for a specific user as requiring reprocessing.
  ///
  /// Use when a global change invalidates all scans for this user:
  ///   - AI model updated
  ///   - Duplicate algorithm changed
  Future<void> markAllNeedsRescan(String userId) async {
    await _isar.writeTxn(() async {
      final all = await _isar.assetRecords
          .filter()
          .userIdEqualTo(userId)
          .findAll();
      for (final r in all) {
        r.needsRescan = true;
      }
      if (all.isNotEmpty) await _isar.assetRecords.putAll(all);
    });
  }

  /// Update user-state fields (bin/favorite/albums) for a single asset.
  ///
  /// These mirror the Firestore fields and are written here when Firestore
  /// data is loaded, so features can query them locally.
  Future<void> updateUserState(
    String uniqueKey, {
    bool? isInBin,
    bool? isFavorite,
    List<String>? albumIds,
  }) async {
    final record = await findByKey(uniqueKey);
    if (record == null) return;
    await _isar.writeTxn(() async {
      if (isInBin != null) record.isInBin = isInBin;
      if (isFavorite != null) record.isFavorite = isFavorite;
      if (albumIds != null) record.albumIds = albumIds;
      await _isar.assetRecords.put(record);
    });
  }

  /// Delete a single record by its [uniqueKey].
  ///
  /// Use when an asset is permanently deleted from the cloud.
  Future<void> deleteByKey(String uniqueKey) async {
    final record = await findByKey(uniqueKey);
    if (record == null) return;
    await _isar.writeTxn(() => _isar.assetRecords.delete(record.id));
  }

  /// Delete multiple records by their [uniqueKeys].
  Future<void> deleteByKeys(List<String> uniqueKeys) async {
    if (uniqueKeys.isEmpty) return;
    await _isar.writeTxn(() async {
      final records = await _isar.assetRecords
          .filter()
          .anyOf(uniqueKeys, (q, key) => q.uniqueKeyEqualTo(key))
          .findAll();
      final ids = records.map((r) => r.id).toList();
      if (ids.isNotEmpty) await _isar.assetRecords.deleteAll(ids);
    });
  }

  /// Delete all records for a specific user.
  ///
  /// Use when the user logs out or deletes their account.
  Future<void> deleteAllForUser(String userId) async {
    await _isar.writeTxn(() async {
      final records = await _isar.assetRecords
          .filter()
          .userIdEqualTo(userId)
          .findAll();
      final ids = records.map((r) => r.id).toList();
      if (ids.isNotEmpty) await _isar.assetRecords.deleteAll(ids);
    });
  }

  // ===========================================================================
  // READ OPERATIONS
  // ===========================================================================

  /// Find a single record by its [uniqueKey]. Returns null if not found.
  Future<AssetRecord?> findByKey(String uniqueKey) {
    return _isar.assetRecords
        .where()
        .uniqueKeyEqualTo(uniqueKey)
        .findFirst();
  }

  /// Retrieve all records for a specific user from a specific source.
  /// [source] should be a [AssetSource] constant.
  Future<List<AssetRecord>> findBySource(String userId, int source) {
    return _isar.assetRecords
        .filter()
        .userIdEqualTo(userId)
        .sourceEqualTo(source)
        .findAll();
  }

  /// Retrieve all records for a specific user, unfiltered.
  Future<List<AssetRecord>> findAll(String userId) {
    return _isar.assetRecords
        .filter()
        .userIdEqualTo(userId)
        .findAll();
  }

  /// Retrieve all records for a specific user with a given [aiScanStatus].
  /// Pass [AiScanStatus.pending] to get the AI scan work queue.
  Future<List<AssetRecord>> findByAiStatus(String userId, int status) {
    return _isar.assetRecords
        .filter()
        .userIdEqualTo(userId)
        .aiScanStatusEqualTo(status)
        .findAll();
  }

  /// Retrieve all assets for a specific user flagged for rescanning.
  Future<List<AssetRecord>> findNeedsRescan(String userId) {
    return _isar.assetRecords
        .filter()
        .userIdEqualTo(userId)
        .needsRescanEqualTo(true)
        .findAll();
  }

  /// Find assets for a specific user not seen since [cutoff] (potential cloud deletions).
  ///
  /// Call after a full sync pass with syncStartedAt as [cutoff]:
  /// ```dart
  /// final stale = await assetRepository.findStale(userId, syncStartedAt);
  /// // stale assets were not found during this sync → may be deleted
  /// ```
  Future<List<AssetRecord>> findStale(String userId, DateTime cutoff) {
    return _isar.assetRecords
        .filter()
        .userIdEqualTo(userId)
        .lastSeenAtLessThan(cutoff)
        .findAll();
  }

  /// Find all assets for a specific user with the same [contentHash] (byte-identical duplicates).
  ///
  /// Returns an empty list if [contentHash] is null or no matches found.
  Future<List<AssetRecord>> findByContentHash(String userId, String contentHash) {
    return _isar.assetRecords
        .filter()
        .userIdEqualTo(userId)
        .contentHashEqualTo(contentHash)
        .findAll();
  }

  /// Find all assets for a specific user in a duplicate group by [groupId].
  Future<List<AssetRecord>> findDuplicateGroup(String userId, String groupId) {
    return _isar.assetRecords
        .filter()
        .userIdEqualTo(userId)
        .duplicateGroupIdEqualTo(groupId)
        .findAll();
  }

  /// Search for asset records by name, AI tags, OCR text, or detected objects.
  /// Performs a direct substring match — prefer [searchAssetsWithSynonyms] for
  /// user-facing search to get synonym expansion and multi-word support.
  Future<List<AssetRecord>> searchAssets(String userId, String query) {
    return _isar.assetRecords
        .filter()
        .userIdEqualTo(userId)
        .group((q) => q
            .nameContains(query, caseSensitive: false)
            .or()
            .aiTagsElementContains(query, caseSensitive: false)
            .or()
            .detectedObjectsElementContains(query, caseSensitive: false)
            .or()
            .recognizedTextContains(query, caseSensitive: false))
        .findAll();
  }

  // ---------------------------------------------------------------------------
  // SYNONYM MAP
  // ---------------------------------------------------------------------------
  // Maps user-friendly search terms → ML Kit label words to look for.
  // ML Kit uses generic labels (Computer, Animal) not specific ones (Laptop, Dog),
  // so we expand the user query to hit both the specific and generic variants.
  // Add new entries here whenever users report missed searches.
  static const Map<String, List<String>> _synonyms = {
    // Electronics
    'laptop':    ['Laptop', 'Computer', 'Netbook', 'Notebook computer', 'Personal computer', 'Ultrabook'],
    'phone':     ['Mobile phone', 'Smartphone', 'Telephone', 'Communication Device', 'Iphone', 'Android'],
    'tablet':    ['Tablet computer', 'Tablet', 'Ipad', 'Computer'],
    'tv':        ['Television', 'Display device', 'Screen', 'Monitor'],
    'camera':    ['Camera', 'Digital camera', 'Photography', 'Lens', 'Mirrorless camera'],
    'keyboard':  ['Computer keyboard', 'Keyboard', 'Input device'],
    'headphone': ['Headphones', 'Earphone', 'Audio equipment'],
    'watch':     ['Watch', 'Wristwatch', 'Smartwatch', 'Clock'],
    // Animals
    'dog':       ['Dog', 'Canine', 'Puppy', 'Dog breed', 'Snout', 'Companion dog'],
    'cat':       ['Cat', 'Kitten', 'Felidae', 'Whiskers', 'Tabby cat', 'Domestic short-haired cat'],
    'bird':      ['Bird', 'Beak', 'Feather', 'Wildlife', 'Parrot', 'Seagull'],
    'horse':     ['Horse', 'Mare', 'Stallion', 'Equestrian', 'Jockey'],
    'fish':      ['Fish', 'Marine life', 'Aquarium', 'Coral reef', 'Underwater'],
    // Nature / Places
    'beach':     ['Beach', 'Sand', 'Coast', 'Ocean', 'Sea', 'Shore', 'Coastal'],
    'mountain':  ['Mountain', 'Hill', 'Peak', 'Slope', 'Alps', 'Highland', 'Summit'],
    'sunset':    ['Sunset', 'Sunrise', 'Sky', 'Orange', 'Dusk', 'Dawn', 'Horizon'],
    'forest':    ['Forest', 'Tree', 'Woods', 'Jungle', 'Nature', 'Woodland'],
    'city':      ['City', 'Cityscape', 'Skyscraper', 'Urban', 'Architecture', 'Building', 'Street'],
    'flower':    ['Flower', 'Petal', 'Plant', 'Floral', 'Blossom', 'Garden'],
    'snow':      ['Snow', 'Winter', 'Ice', 'Frost', 'Blizzard', 'Snowflake'],
    'rain':      ['Rain', 'Rainy', 'Storm', 'Drizzle', 'Umbrella', 'Wet'],
    'sky':       ['Sky', 'Cloud', 'Clouds', 'Atmosphere', 'Azure', 'Blue sky'],
    // People
    'person':    ['Person', 'Human', 'Face', 'People', 'Crowd', 'Portrait', 'Man', 'Woman'],
    'baby':      ['Baby', 'Infant', 'Child', 'Toddler', 'Newborn'],
    'wedding':   ['Wedding', 'Bride', 'Groom', 'Ceremony', 'Marriage'],
    // Food & Drink
    'food':      ['Food', 'Dish', 'Cuisine', 'Meal', 'Plate', 'Snack', 'Recipe'],
    'pizza':     ['Pizza', 'Fast food', 'Cheese', 'Italian food'],
    'coffee':    ['Coffee', 'Espresso', 'Cafe', 'Drink', 'Cup', 'Mug', 'Beverage'],
    'cake':      ['Cake', 'Dessert', 'Pastry', 'Baking', 'Bakery'],
    'fruit':     ['Fruit', 'Apple', 'Orange', 'Banana', 'Berry', 'Produce'],
    // Transport
    'car':       ['Car', 'Vehicle', 'Automobile', 'Motor vehicle', 'Automotive design', 'Sports car'],
    'bike':      ['Bicycle', 'Bike', 'Cycling', 'Mountain bike', 'Motorcycle'],
    'plane':     ['Aircraft', 'Airplane', 'Airline', 'Aviation', 'Jet'],
    'boat':      ['Boat', 'Ship', 'Watercraft', 'Vessel', 'Sailboat'],
    // Activities / Sports
    'sport':     ['Sport', 'Football', 'Soccer', 'Basketball', 'Tennis', 'Athlete'],
    'gym':       ['Gym', 'Exercise', 'Fitness', 'Workout', 'Weight training'],
    'yoga':      ['Yoga', 'Meditation', 'Exercise', 'Flexibility'],
    'music':     ['Music', 'Guitar', 'Piano', 'Concert', 'Microphone', 'Singing'],
    // Objects
    'book':      ['Book', 'Text', 'Publication', 'Reading'],
    'bag':       ['Bag', 'Handbag', 'Backpack', 'Luggage', 'Purse'],
    'glasses':   ['Glasses', 'Sunglasses', 'Eyewear', 'Vision care'],
    'furniture': ['Furniture', 'Table', 'Chair', 'Couch', 'Sofa', 'Interior design'],
    'document':  ['Document', 'Paper', 'Text', 'Letter', 'Receipt'],
    'screenshot':['Screenshot', 'Text', 'Computer', 'Display'],
  };

  /// Strict smart search — only returns assets where [query] matches AI tags,
  /// detected objects, or recognized text. Filenames are NOT included in this
  /// search (that's handled separately in the UI layer for all items).
  ///
  /// Uses synonym expansion so "cat" also matches "kitten", "feline", etc.
  /// Results use INTERSECTION for multi-word queries:
  ///   "cat dog" returns items that have BOTH cat AND dog in their tags.
  Future<List<AssetRecord>> searchByTagsStrict(
    String userId,
    String query,
  ) async {
    final words = query.toLowerCase().trim().split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return [];

    // Start with all AI-scanned items for this user
    Set<int>? intersectedIds;
    final Map<int, AssetRecord> recordMap = {};


    for (final word in words) {
      // Build expanded synonym list for this word
      List<String> searchTerms = [word];
      for (final entry in _synonyms.entries) {
        if (entry.key.startsWith(word) || word.startsWith(entry.key)) {
          searchTerms = entry.value.map((s) => s.toLowerCase()).toList();
          if (!searchTerms.contains(word)) searchTerms.insert(0, word);
          break;
        }
      }

      // Find all records that match ANY of the synonym terms in AI fields only
      final Set<int> wordMatchedIds = {};
      for (final term in searchTerms) {
        final results = await _isar.assetRecords
            .filter()
            .userIdEqualTo(userId)
            .group((q) => q
                .aiTagsElementContains(term, caseSensitive: false)
                .or()
                .detectedObjectsElementContains(term, caseSensitive: false)
                .or()
                .recognizedTextContains(term, caseSensitive: false))
            .findAll();
        for (final r in results) {
          wordMatchedIds.add(r.id);
          recordMap[r.id] = r;
        }
      }

      // Intersect with previous results (AND logic across words)
      if (intersectedIds == null) {
        intersectedIds = wordMatchedIds;
      } else {
        intersectedIds = intersectedIds.intersection(wordMatchedIds);
      }
    }

    if (intersectedIds == null) return [];
    return intersectedIds.map((id) => recordMap[id]!).toList();
  }

  /// Search with synonym expansion and multi-word support.
  ///
  /// For each word in [query]:
  ///   1. If it matches a key in [_synonyms], we look for all synonym variants.
  ///   2. Otherwise, we do a regular substring match on name + aiTags.
  ///
  /// Results from all word searches are union-merged (any word match = result
  /// is included). This lets "beach sunset" return items tagged with either
  /// "beach" OR "sunset" (or any of their synonyms).

  Future<List<AssetRecord>> searchAssetsWithSynonyms(
    String userId,
    String query,
  ) async {
    final words = query.toLowerCase().trim().split(RegExp(r'\s+'));
    if (words.isEmpty || (words.length == 1 && words.first.isEmpty)) {
      return [];
    }

    // Build the set of expanded search terms for each word.
    // Then union-merge results across all words.
    final Set<int> matchedIds = {};
    final List<AssetRecord> allMatched = [];

    for (final word in words) {
      if (word.isEmpty) continue;

      // Find which synonym list to use (check if any key starts-with or equals the word)
      List<String>? synonymList;
      for (final entry in _synonyms.entries) {
        if (entry.key.startsWith(word) || word.startsWith(entry.key)) {
          synonymList = entry.value;
          break;
        }
      }

      List<AssetRecord> wordResults;

      if (synonymList != null) {
        // Run one Isar query per synonym term and merge
        final Set<int> wordIds = {};
        final List<AssetRecord> wordRecords = [];
        for (final term in synonymList) {
          final results = await _isar.assetRecords
              .filter()
              .userIdEqualTo(userId)
              .group((q) => q
                  .nameContains(term, caseSensitive: false)
                  .or()
                  .aiTagsElementContains(term, caseSensitive: false)
                  .or()
                  .detectedObjectsElementContains(term, caseSensitive: false)
                  .or()
                  .recognizedTextContains(term, caseSensitive: false))
              .findAll();
          for (final r in results) {
            if (!wordIds.contains(r.id)) {
              wordIds.add(r.id);
              wordRecords.add(r);
            }
          }
        }
        // Also add the raw word itself in case it IS stored verbatim
        final directResults = await _isar.assetRecords
            .filter()
            .userIdEqualTo(userId)
            .group((q) => q
                .nameContains(word, caseSensitive: false)
                .or()
                .aiTagsElementContains(word, caseSensitive: false)
                .or()
                .detectedObjectsElementContains(word, caseSensitive: false)
                .or()
                .recognizedTextContains(word, caseSensitive: false))
            .findAll();
        for (final r in directResults) {
          if (!wordIds.contains(r.id)) {
            wordIds.add(r.id);
            wordRecords.add(r);
          }
        }
        wordResults = wordRecords;
      } else {
        // No synonym mapping — direct substring match
        wordResults = await _isar.assetRecords
            .filter()
            .userIdEqualTo(userId)
            .group((q) => q
                .nameContains(word, caseSensitive: false)
                .or()
                .aiTagsElementContains(word, caseSensitive: false)
                .or()
                .detectedObjectsElementContains(word, caseSensitive: false)
                .or()
                .recognizedTextContains(word, caseSensitive: false))
            .findAll();
      }

      // Union-merge into master results
      for (final r in wordResults) {
        if (!matchedIds.contains(r.id)) {
          matchedIds.add(r.id);
          allMatched.add(r);
        }
      }
    }

    return allMatched;
  }


  /// Count total assets per source for a specific user, excluding folders and binned items.
  ///
  /// Returns a map of { AssetSource constant → count }.
  /// Used by Cloud Hub for storage insights.
  Future<Map<int, int>> countBySource(String userId) async {
    final all = await _isar.assetRecords
        .filter()
        .userIdEqualTo(userId)
        .isInBinEqualTo(false)
        .isFolderEqualTo(false)
        .findAll();
    final counts = <int, int>{};
    for (final r in all) {
      counts[r.source] = (counts[r.source] ?? 0) + 1;
    }
    return counts;
  }

  /// Total number of records in the database for a specific user.
  Future<int> count(String userId) {
    return _isar.assetRecords
        .filter()
        .userIdEqualTo(userId)
        .count();
  }

  /// Find photos taken on today's month+day in any previous year.
  ///
  /// Used by the "On This Day" memories notification.
  /// Returns a map of { year → [AssetRecord] } for years that have >= [minCount] photos.
  /// Only includes non-folder, non-video, non-binned items with a known [createdAt].
  Future<Map<int, List<AssetRecord>>> findOnThisDay(
    String userId, {
    int minCount = 3,
  }) async {
    final now = DateTime.now();
    final todayMonth = now.month;
    final todayDay = now.day;
    final thisYear = now.year;

    // Pull all records that have a createdAt date (excludes cloud items with no date)
    final all = await _isar.assetRecords
        .filter()
        .userIdEqualTo(userId)
        .isFolderEqualTo(false)
        .isVideoEqualTo(false)
        .isInBinEqualTo(false)
        .createdAtIsNotNull()
        .findAll();

    // Group by year, keeping only items matching today's month+day in a prior year
    final Map<int, List<AssetRecord>> byYear = {};
    for (final record in all) {
      final date = record.createdAt!;
      if (date.month == todayMonth &&
          date.day == todayDay &&
          date.year < thisYear) {
        byYear.putIfAbsent(date.year, () => []).add(record);
      }
    }

    // Remove years below the minimum threshold
    byYear.removeWhere((_, records) => records.length < minCount);
    return byYear;
  }

  /// Count assets for a specific user that have a given [aiScanStatus].
  ///
  /// Common calls:
  ///   - `countByAiStatus(userId, AiScanStatus.done)`    → indexed photos
  ///   - `countByAiStatus(userId, AiScanStatus.pending)` → queue length
  ///
  /// Excludes folders; videos are counted since they may be tagged in future.
  Future<int> countByAiStatus(String userId, int status) {
    return _isar.assetRecords
        .filter()
        .userIdEqualTo(userId)
        .isFolderEqualTo(false)
        .aiScanStatusEqualTo(status)
        .count();
  }

  /// Count assets for a specific user that have a valid pHash (already scanned for duplicates).
  Future<int> countByPHashNotNull(String userId) {
    return _isar.assetRecords
        .filter()
        .userIdEqualTo(userId)
        .isFolderEqualTo(false)
        .pHashHexIsNotNull()
        .count();
  }

  /// Find all AssetRecords belonging to a specific person ID.
  Future<List<AssetRecord>> findByPersonId(String userId, String personId) {
    return _isar.assetRecords
        .filter()
        .userIdEqualTo(userId)
        .isInBinEqualTo(false)
        .personIdsElementEqualTo(personId)
        .findAll();
  }

  /// Find all AssetRecords that contain 1 or more recognized faces.
  Future<List<AssetRecord>> findWithFaces(String userId) {
    return _isar.assetRecords
        .filter()
        .userIdEqualTo(userId)
        .isInBinEqualTo(false)
        .faceCountGreaterThan(0)
        .findAll();
  }

  // ===========================================================================
  // FACTORY / ADAPTER
  // ===========================================================================

  /// Create an [AssetRecord] from primitive field values (no DriveItem import).
  ///
  /// This avoids a circular import between this file and main.dart.
  /// The caller (in main.dart) extracts the values from a DriveItem and passes
  /// them as primitives.
  ///
  /// This does NOT write to Isar — call [upsert] separately.
  static AssetRecord fromFields({
    required String userId,
    required String uniqueKey,
    required String cloudFileId,
    required int source, // PhotoSource.index
    required String name,
    int? size,
    String? mimeType,
    bool isVideo = false,
    bool isFolder = false,
    DateTime? createdAt,
    String? cloudEtag,
  }) {
    final now = DateTime.now();
    return AssetRecord()
      ..userId = userId
      ..uniqueKey = uniqueKey
      ..cloudFileId = cloudFileId
      ..source = source
      ..name = name
      ..size = size
      ..mimeType = mimeType
      ..isVideo = isVideo
      ..isFolder = isFolder
      ..createdAt = createdAt
      ..cloudEtag = cloudEtag
      ..lastSeenAt = now
      ..syncedAt = now
      ..aiScanStatus = AiScanStatus.pending
      ..needsRescan = false;
  }
}
