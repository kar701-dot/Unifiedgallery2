// lib/memories_page.dart
// "On This Day" Memories Page.
// onPhotoTap is provided by main.dart which has all required tokens/callbacks.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import 'main.dart' show DriveItem, PhotoSource;

class MemoriesPage extends StatelessWidget {
  final List<DriveItem> items;
  final DateTime date;
  final Future<String?> Function(DriveItem) getThumbnailUrl;
  /// Called when user taps a photo; main.dart opens PhotoViewerPage with full context.
  final void Function(List<DriveItem> items, int index) onPhotoTap;

  const MemoriesPage({
    super.key,
    required this.items,
    required this.date,
    required this.getThumbnailUrl,
    required this.onPhotoTap,
  });

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final yearsAgo = DateTime.now().year - date.year;
    final yearsAgoText = yearsAgo == 1 ? '1 year ago' : '$yearsAgo years ago';
    final monthName = _months[date.month - 1];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            foregroundColor: textPrimary,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (items.isNotEmpty)
                    _MemoryCoverImage(
                      item: items.first,
                      getThumbnailUrl: getThumbnailUrl,
                    ),
                  // Dark gradient overlay for text readability
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.85),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$monthName ${date.day}, ${date.year}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          yearsAgoText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${items.length} photo${items.length == 1 ? "" : "s"}',
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(4),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _MemoryTile(
                  item: items[index],
                  getThumbnailUrl: getThumbnailUrl,
                  onTap: () => onPhotoTap(items, index),
                ),
                childCount: items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryCoverImage extends StatelessWidget {
  final DriveItem item;
  final Future<String?> Function(DriveItem) getThumbnailUrl;

  const _MemoryCoverImage({required this.item, required this.getThumbnailUrl});

  @override
  Widget build(BuildContext context) {
    if (item.source == PhotoSource.local) {
      if (item.localAsset != null) {
        return AssetEntityImage(
          item.localAsset!,
          isOriginal: false,
          thumbnailSize: const ThumbnailSize.square(500),
          fit: BoxFit.cover,
        );
      }
      return FutureBuilder<AssetEntity?>(
        future: AssetEntity.fromId(item.id),
        builder: (context, snap) {
          if (snap.hasData && snap.data != null) {
            return AssetEntityImage(
              snap.data!,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize.square(500),
              fit: BoxFit.cover,
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
          errorWidget: (_, __, ___) => Container(color: Colors.grey[900]),
        );
      },
    );
  }
}

class _MemoryTile extends StatelessWidget {
  final DriveItem item;
  final Future<String?> Function(DriveItem) getThumbnailUrl;
  final VoidCallback onTap;

  const _MemoryTile({
    required this.item,
    required this.getThumbnailUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: _buildTileImage(),
      ),
    );
  }

  Widget _buildTileImage() {
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
