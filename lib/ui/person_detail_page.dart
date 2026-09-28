// lib/ui/person_detail_page.dart
//
// Screen displaying all photos belonging to a specific Person cluster across all sources.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../data/person_record.dart';
import '../data/face_record.dart';
import '../main.dart' show DriveItem, PhotoSource, PhotoViewerPage;

class PersonDetailPage extends StatefulWidget {
  final PersonRecord person;
  final Isar isar;
  final String userId;
  final List<DriveItem> allDriveItems;
  final Future<String?> Function(DriveItem item) getThumbnailUrl;
  final Future<String?> Function(DriveItem item) getDownloadUrl;

  const PersonDetailPage({
    super.key,
    required this.person,
    required this.isar,
    required this.userId,
    required this.allDriveItems,
    required this.getThumbnailUrl,
    required this.getDownloadUrl,
  });

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage> {
  List<DriveItem> _personItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPersonPhotos();
  }

  bool _matchesAssetKey(DriveItem item, Set<String> targetKeys) {
    final itemKey = item.getUniqueKey(); // 'local::$id'
    final fullKey = '${widget.userId}::$itemKey'; // '$userId::local::$id'
    return targetKeys.contains(itemKey) ||
        targetKeys.contains(fullKey) ||
        targetKeys.contains(item.id) ||
        targetKeys.any((k) => k.endsWith('::${item.id}') || k == itemKey || k == fullKey);
  }

  Future<void> _loadPersonPhotos() async {
    final faces = await widget.isar.faceRecords
        .filter()
        .userIdEqualTo(widget.userId)
        .personIdEqualTo(widget.person.personId)
        .findAll();

    final assetKeys = faces.map((f) => f.assetKey).toSet();

    // 1. Find matching items from in-memory allDriveItems
    final matchedItems = widget.allDriveItems
        .where((item) => _matchesAssetKey(item, assetKeys))
        .toList();

    final matchedKeys = matchedItems.map((e) => e.getUniqueKey()).toSet();

    // 2. Load any local assets not currently loaded in allDriveItems
    for (final key in assetKeys) {
      if (key.contains('::local::') || key.startsWith('local::')) {
        final localId = key.split('::').last;
        final uniqueKey = 'local::$localId';
        if (!matchedKeys.contains(uniqueKey) && !matchedItems.any((it) => it.id == localId)) {
          try {
            final entity = await AssetEntity.fromId(localId);
            if (entity != null) {
              matchedItems.add(DriveItem(
                id: entity.id,
                name: entity.title ?? 'Photo',
                size: null,
                created: entity.createDateTime,
                source: PhotoSource.local,
                localAsset: entity,
              ));
              matchedKeys.add(uniqueKey);
            }
          } catch (_) {}
        }
      }
    }

    matchedItems.sort((a, b) =>
        (b.created ?? DateTime(1970)).compareTo(a.created ?? DateTime(1970)));

    if (mounted) {
      setState(() {
        _personItems = matchedItems;
        _isLoading = false;
      });
    }
  }

  Future<void> _renamePerson() async {
    final controller = TextEditingController(text: widget.person.name ?? '');
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
        widget.person.name = newName;
        await widget.isar.personRecords.put(widget.person);
      });
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (widget.person.name != null && widget.person.name!.trim().isNotEmpty)
                  ? widget.person.name!
                  : 'Photos',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (!_isLoading)
              Text(
                '${_personItems.length} photo${_personItems.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: textPrimary.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: textPrimary),
            tooltip: 'Add / Edit Name',
            onPressed: _renamePerson,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _personItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 64,
                        color: textPrimary.withOpacity(0.35),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No photos found for this person',
                        style: TextStyle(
                          color: textPrimary.withOpacity(0.6),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _personItems.length,
                  itemBuilder: (context, index) {
                    final item = _personItems[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PhotoViewerPage(
                              items: _personItems,
                              initialIndex: index,
                              getThumbnailUrl: widget.getThumbnailUrl,
                              getDownloadUrl: widget.getDownloadUrl,
                              favorites: const {},
                              bin: const {},
                              onFavoriteChanged: (_, __) {},
                              onMoveToBin: (_) async {},
                              onAddToAlbum: (_) async {},
                              oneDriveAccessToken: null,
                              dropboxAccessToken: null,
                              boxAccessToken: null,
                              useCaching: true,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _PersonPhotoThumbnail(
                          item: item,
                          getThumbnailUrl: widget.getThumbnailUrl,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _PersonPhotoThumbnail extends StatelessWidget {
  final DriveItem item;
  final Future<String?> Function(DriveItem item) getThumbnailUrl;

  const _PersonPhotoThumbnail({
    required this.item,
    required this.getThumbnailUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (item.source == PhotoSource.local) {
      if (item.localAsset != null) {
        return AssetEntityImage(
          item.localAsset!,
          isOriginal: false,
          thumbnailSize: const ThumbnailSize.square(250),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey[900],
            child: const Icon(Icons.broken_image_outlined, color: Colors.white24),
          ),
        );
      }
      return FutureBuilder<AssetEntity?>(
        future: AssetEntity.fromId(item.id),
        builder: (context, snap) {
          if (snap.hasData && snap.data != null) {
            return AssetEntityImage(
              snap.data!,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize.square(250),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[900],
                child: const Icon(Icons.broken_image_outlined, color: Colors.white24),
              ),
            );
          }
          return Container(color: Colors.grey[900]);
        },
      );
    }

    return FutureBuilder<String?>(
      future: getThumbnailUrl(item),
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null || snap.data!.isEmpty) {
          return Container(color: Colors.grey[900]);
        }
        final url = snap.data!;
        if (url.startsWith('data:image')) {
          try {
            return Image.memory(
              base64Decode(url.split(',').last),
              fit: BoxFit.cover,
            );
          } catch (_) {
            return Container(color: Colors.grey[900]);
          }
        }
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: Colors.grey[900]),
          errorWidget: (_, __, ___) => Container(
            color: Colors.grey[900],
            child: const Icon(Icons.broken_image_outlined, color: Colors.white24),
          ),
        );
      },
    );
  }
}
