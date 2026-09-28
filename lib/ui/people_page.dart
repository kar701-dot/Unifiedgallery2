// lib/ui/people_page.dart
//
// Google Photos-style People & Faces screen.
// 4-column circular avatar grid, named persons first, scan progress banner.

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:collection/collection.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../data/person_record.dart';
import '../data/asset_repository.dart';
import '../services/foreground_scanner.dart';
import '../main.dart' show DriveItem, PhotoSource;
import 'person_detail_page.dart';

class PeoplePage extends StatefulWidget {
  final Isar isar;
  final String userId;
  final List<DriveItem> allDriveItems;
  final Future<String?> Function(DriveItem item) getThumbnailUrl;
  final Future<String?> Function(DriveItem item) getDownloadUrl;

  const PeoplePage({
    super.key,
    required this.isar,
    required this.userId,
    required this.allDriveItems,
    required this.getThumbnailUrl,
    required this.getDownloadUrl,
  });

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  List<PersonRecord> _namedPeople   = [];
  List<PersonRecord> _unnamedPeople = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPeople();
    _autoScanFaces();
    // Refresh grid when scan completes
    ForegroundScanner().isScanning.addListener(_onScanStateChange);
    // Refresh grid progressively every 10 photos scanned (real-time face discovery)
    ForegroundScanner().progress.addListener(_onScanProgress);
  }

  @override
  void dispose() {
    ForegroundScanner().isScanning.removeListener(_onScanStateChange);
    ForegroundScanner().progress.removeListener(_onScanProgress);
    super.dispose();
  }

  void _onScanStateChange() {
    // Final refresh when scan fully finishes
    if (!ForegroundScanner().isScanning.value && mounted) {
      _loadPeople();
    }
  }

  void _onScanProgress() {
    // Show newly discovered faces every 10 photos scanned
    final p = ForegroundScanner().progress.value;
    if (p > 0 && p % 10 == 0 && mounted) {
      _loadPeople();
    }
  }

  Future<void> _autoScanFaces() async {
    try {
      // Throttled: won't fire more than once every 30 minutes
      if (await ForegroundScanner.shouldStartScan()) {
        await ForegroundScanner().startScan(widget.userId, AssetRepository(widget.isar));
        if (mounted) _loadPeople();
      }
    } catch (_) {}
  }

  Future<void> _loadPeople() async {
    final people = await widget.isar.personRecords
        .filter()
        .userIdEqualTo(widget.userId)
        .findAll();

    // Named persons first (sorted by photo count desc), unnamed after
    final named   = people.where((p) => p.name != null && p.name!.trim().isNotEmpty).toList();
    final unnamed = people.where((p) => p.name == null || p.name!.trim().isEmpty).toList();

    named.sort((a, b) => b.photoCount.compareTo(a.photoCount));
    unnamed.sort((a, b) => b.photoCount.compareTo(a.photoCount));

    if (mounted) {
      setState(() {
        _namedPeople   = named;
        _unnamedPeople = unnamed;
        _isLoading     = false;
      });
    }
  }

  Future<void> _showRenameDialog(PersonRecord person) async {
    final controller = TextEditingController(text: person.name ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name this Person'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name (e.g. Mom, Alex)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      await widget.isar.writeTxn(() async {
        person.name = newName;
        await widget.isar.personRecords.put(person);
      });
      _loadPeople();
    }
  }

  bool _matchesAssetKey(DriveItem item, String assetKey) {
    if (assetKey.isEmpty) return false;
    final itemKey = item.getUniqueKey();
    final fullKey = '${widget.userId}::$itemKey';
    return assetKey == itemKey ||
        assetKey == fullKey ||
        assetKey == item.id ||
        assetKey.endsWith('::${item.id}');
  }

  DriveItem? _findCoverItem(PersonRecord person) {
    if (widget.allDriveItems.isEmpty) return null;
    final targetKey = person.coverFaceAssetKey ?? '';
    if (targetKey.isEmpty) return null;

    return widget.allDriveItems.firstWhereOrNull(
      (item) => _matchesAssetKey(item, targetKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111111) : const Color(0xFFF5F7FA);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final allPeople = [..._namedPeople, ..._unnamedPeople];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text(
          'People & Faces',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : allPeople.isEmpty
              ? _buildEmptyState(textPrimary)
              : _buildPeopleGrid(allPeople, isDark, textPrimary),
    );
  }

  Widget _buildPeopleGrid(List<PersonRecord> people, bool isDark, Color textPrimary) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      // 4 columns — same as Google Photos, ~12 faces visible on one screen
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 6,
        mainAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemCount: people.length,
      itemBuilder: (context, index) {
        return _buildPersonCard(people[index], isDark, textPrimary);
      },
    );
  }

  Widget _buildEmptyState(Color textPrimary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.face_retouching_natural, size: 72, color: textPrimary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No Faces Detected Yet',
            style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Photos with people will appear here automatically as they are indexed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textPrimary.withValues(alpha: 0.55), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonCard(PersonRecord person, bool isDark, Color textPrimary) {
    final coverItem = _findCoverItem(person);
    final hasName   = person.name != null && person.name!.trim().isNotEmpty;
    final displayName = hasName ? person.name!.trim() : 'Unnamed';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PersonDetailPage(
              person: person,
              isar: widget.isar,
              userId: widget.userId,
              allDriveItems: widget.allDriveItems,
              getThumbnailUrl: widget.getThumbnailUrl,
              getDownloadUrl: widget.getDownloadUrl,
            ),
          ),
        ).then((_) => _loadPeople());
      },
      onLongPress: () => _showRenameDialog(person),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Circular face avatar (no border — matches Google Photos style) ──
          SizedBox(
            width: 72,
            height: 72,
            child: ClipOval(
              child: _buildFaceAvatar(person, coverItem),
            ),
          ),
          const SizedBox(height: 6),
          // ── Name label ────────────────────────────────────────────────────
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: hasName
                  ? textPrimary
                  : textPrimary.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: hasName ? FontWeight.w600 : FontWeight.normal,
              fontStyle: hasName ? FontStyle.normal : FontStyle.italic,
            ),
          ),
          const SizedBox(height: 2),
          // ── Photo count ───────────────────────────────────────────────────
          Text(
            '${person.photoCount}',
            style: TextStyle(
              color: textPrimary.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a circular avatar, cropped and zoomed onto the face bounding box.
  Widget _buildFaceAvatar(PersonRecord person, DriveItem? coverItem) {
    final bbox = person.coverBoundingBox;
    double alignX = 0.0;
    double alignY = 0.0;
    double scale  = 1.5; // default zoom

    if (bbox != null && bbox.length >= 4 && bbox[2] > 0 && bbox[3] > 0) {
      final cx = (bbox[0] + bbox[2] / 2.0).clamp(0.0, 1.0);
      final cy = (bbox[1] + bbox[3] / 2.0).clamp(0.0, 1.0);
      alignX = ((cx - 0.5) * 2.0).clamp(-1.0, 1.0);
      alignY = ((cy - 0.5) * 2.0).clamp(-1.0, 1.0);

      final faceSize = math.max(bbox[2], bbox[3]);
      if (faceSize < 0.75) {
        scale = (1.0 / faceSize.clamp(0.12, 0.60)).clamp(1.4, 4.0);
      }
    }

    return Transform.scale(
      scale: scale,
      alignment: Alignment(alignX, alignY),
      child: _buildCoverImage(person, coverItem),
    );
  }

  Widget _buildCoverImage(PersonRecord person, DriveItem? item) {
    final targetKey = person.coverFaceAssetKey ?? '';

    // Local asset
    if (item?.source == PhotoSource.local ||
        targetKey.contains('::local::') ||
        targetKey.startsWith('local::')) {
      final localId = item?.id ?? targetKey.split('::').last;

      if (item?.localAsset != null) {
        return AssetEntityImage(
          item!.localAsset!,
          isOriginal: false,
          thumbnailSize: const ThumbnailSize.square(400),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _personPlaceholder(),
        );
      }

      return FutureBuilder<AssetEntity?>(
        future: AssetEntity.fromId(localId),
        builder: (context, snap) {
          if (snap.hasData && snap.data != null) {
            return AssetEntityImage(
              snap.data!,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize.square(400),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _personPlaceholder(),
            );
          }
          return _personPlaceholder();
        },
      );
    }

    // Cloud asset
    if (item != null) {
      return FutureBuilder<String?>(
        future: widget.getThumbnailUrl(item),
        builder: (context, snap) {
          if (snap.hasData && snap.data != null && snap.data!.isNotEmpty) {
            final url = snap.data!;
            if (url.startsWith('data:image')) {
              try {
                return Image.memory(
                  base64Decode(url.split(',').last),
                  fit: BoxFit.cover,
                );
              } catch (_) {}
            }
            return CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => _personPlaceholder(),
              errorWidget: (_, __, ___) => _personPlaceholder(),
            );
          }
          return _personPlaceholder();
        },
      );
    }

    return _personPlaceholder();
  }

  Widget _personPlaceholder() {
    return Container(
      color: Colors.grey[850],
      child: const Icon(Icons.person, color: Colors.white38),
    );
  }
}
