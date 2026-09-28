import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../main.dart'; // To access PhotoSource, DriveItem, etc.

// ─────────────────────────────────────────────
//  Brand colours & helpers for each cloud
// ─────────────────────────────────────────────
// Sources shown in the migration UI (Google Drive & MEGA are excluded app-wide)
const _kSupportedSources = [
  PhotoSource.oneDrive,
  PhotoSource.dropbox,
  PhotoSource.box,
  PhotoSource.pCloud,
  PhotoSource.local,
];

extension PhotoSourceUI on PhotoSource {
  String get displayName {
    switch (this) {
      case PhotoSource.oneDrive:    return 'OneDrive';
      case PhotoSource.dropbox:     return 'Dropbox';
      case PhotoSource.googleDrive: return 'Google Drive';
      case PhotoSource.box:         return 'Box';
      case PhotoSource.pCloud:      return 'pCloud';
      case PhotoSource.mega:        return 'MEGA';
      case PhotoSource.local:       return 'Device';
    }
  }

  Color get brandColor {
    switch (this) {
      case PhotoSource.oneDrive:    return const Color(0xFF0078D4);
      case PhotoSource.dropbox:     return const Color(0xFF0061FF);
      case PhotoSource.googleDrive: return const Color(0xFF4285F4);
      case PhotoSource.box:         return const Color(0xFF0061D5);
      case PhotoSource.pCloud:      return const Color(0xFF5BB9FE);
      case PhotoSource.mega:        return const Color(0xFFD9272E);
      case PhotoSource.local:       return const Color(0xFF34C759);
    }
  }

  IconData get icon {
    switch (this) {
      case PhotoSource.oneDrive:    return Icons.cloud;
      case PhotoSource.dropbox:     return Icons.inventory_2_rounded;
      case PhotoSource.googleDrive: return Icons.add_to_drive_rounded;
      case PhotoSource.box:         return Icons.cloud_queue_rounded;
      case PhotoSource.pCloud:      return Icons.cloud_circle_rounded;
      case PhotoSource.mega:        return Icons.storage_rounded;
      case PhotoSource.local:       return Icons.phone_android_rounded;
    }
  }

  // Quota key as stored in _storageQuotas map (matches main.dart keys)
  String get quotaKey {
    switch (this) {
      case PhotoSource.oneDrive:    return 'OneDrive';
      case PhotoSource.dropbox:     return 'Dropbox';
      case PhotoSource.box:         return 'Box';
      case PhotoSource.pCloud:      return 'pCloud';
      default:                      return '';
    }
  }
}

// ─────────────────────────────────────────────
//  Data model
// ─────────────────────────────────────────────
enum MigrationStatus { idle, running, paused, completed, error }

class MigrationJob {
  PhotoSource? source;
  PhotoSource? destination;
  bool isMove;
  String filter;       // media type: all / photos / videos / large
  String preset;       // date preset: all / last30 / lastYear / before2023 / custom
  DateTime? dateFrom;
  DateTime? dateTo;
  int totalItems;
  int processedItems;
  int successCount;
  int failedCount;
  int totalBytes;
  int processedBytes;
  MigrationStatus status;
  List<String> failedItemNames; // names of individual files that failed to transfer

  MigrationJob({
    this.source,
    this.destination,
    this.isMove = false,
    this.filter = 'all',
    this.preset = 'all',
    this.dateFrom,
    this.dateTo,
    this.totalItems = 0,
    this.processedItems = 0,
    this.successCount = 0,
    this.failedCount = 0,
    this.totalBytes = 0,
    this.processedBytes = 0,
    this.status = MigrationStatus.idle,
    List<String>? failedItemNames,
  }) : failedItemNames = failedItemNames ?? [];

  Map<String, dynamic> toJson() => {
    'source': source?.name,
    'destination': destination?.name,
    'isMove': isMove,
    'filter': filter,
    'preset': preset,
    'dateFrom': dateFrom?.toIso8601String(),
    'dateTo': dateTo?.toIso8601String(),
    'totalItems': totalItems,
    'processedItems': processedItems,
    'successCount': successCount,
    'failedCount': failedCount,
    'totalBytes': totalBytes,
    'processedBytes': processedBytes,
    'status': status.name,
    'failedItemNames': failedItemNames,
  };

  factory MigrationJob.fromJson(Map<String, dynamic> json) {
    return MigrationJob(
      source: PhotoSource.values.firstWhereOrNull((e) => e.name == json['source']),
      destination: PhotoSource.values.firstWhereOrNull((e) => e.name == json['destination']),
      isMove: json['isMove'] ?? false,
      filter: json['filter'] ?? 'all',
      preset: json['preset'] ?? 'all',
      dateFrom: json['dateFrom'] != null ? DateTime.tryParse(json['dateFrom']) : null,
      dateTo: json['dateTo'] != null ? DateTime.tryParse(json['dateTo']) : null,
      totalItems: json['totalItems'] ?? 0,
      processedItems: json['processedItems'] ?? 0,
      successCount: json['successCount'] ?? 0,
      failedCount: json['failedCount'] ?? 0,
      totalBytes: json['totalBytes'] ?? 0,
      processedBytes: json['processedBytes'] ?? 0,
      status: MigrationStatus.values.firstWhereOrNull((e) => e.name == json['status']) ??
          MigrationStatus.idle,
      failedItemNames: (json['failedItemNames'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

typedef UploadCallback = Future<bool> Function(File file, String name, PhotoSource destination);
typedef DeleteCallback = Future<bool> Function(DriveItem item);
typedef DownloadUrlCallback = Future<String?> Function(DriveItem item);
typedef SpaceCheckCallback = Future<bool> Function(PhotoSource dest, int requiredBytes);

// ─────────────────────────────────────────────
//  Page widget
// ─────────────────────────────────────────────
// Minimal quota snapshot passed in from CloudHubPage
class CloudStorageQuota {
  final int usedBytes;
  final int totalBytes;
  const CloudStorageQuota({required this.usedBytes, required this.totalBytes});
  double get fraction =>
      totalBytes > 0 ? (usedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
  String get freeLabel => _fmt(totalBytes - usedBytes);
  String get usedLabel => _fmt(usedBytes);
  String get totalLabel => _fmt(totalBytes);
  static String _fmt(int b) {
    if (b <= 0) return '0 B';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class SmartMigrationPage extends StatefulWidget {
  final List<DriveItem> allItems;
  final UploadCallback onUpload;
  final DeleteCallback onDelete;
  final DownloadUrlCallback onGetDownloadUrl;
  final SpaceCheckCallback onCheckSpace;
  /// Optional storage quotas keyed by service name (e.g. 'OneDrive', 'Dropbox')
  final Map<String, CloudStorageQuota> storageQuotas;

  const SmartMigrationPage({
    super.key,
    required this.allItems,
    required this.onUpload,
    required this.onDelete,
    required this.onGetDownloadUrl,
    required this.onCheckSpace,
    this.storageQuotas = const {},
  });

  @override
  State<SmartMigrationPage> createState() => _SmartMigrationPageState();
}

class _SmartMigrationPageState extends State<SmartMigrationPage>
    with TickerProviderStateMixin {
  MigrationJob _job = MigrationJob();
  bool _isLoadingState = true;
  List<DriveItem> _filteredItems = [];
  bool _isCancelled = false;
  DateTime? _startTime;
  bool _showFailedItems = false; // controls expandable failed items list

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  // Accent / semantic tokens
  static const _accent        = Color(0xFF1565C0);
  static const _accentGlow    = Color(0x221565C0);
  static const _success       = Color(0xFF2E7D32);
  static const _danger        = Color(0xFFC62828);

  // Surface/text tokens — dynamic for dark/light mode
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _surface => _isDark ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _surfaceHigh => _isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
  Color get _textPrimary => _isDark ? Colors.white : const Color(0xFF111827);
  Color get _textSecondary => _isDark ? Colors.white70 : const Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );

    _loadSavedState();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // ──────────── State persistence ────────────
  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('migration_job');
    if (saved != null) {
      try {
        final job = MigrationJob.fromJson(jsonDecode(saved));
        if (job.status != MigrationStatus.completed) {
          setState(() {
            _job = job;
            _job.status = MigrationStatus.paused;
          });
          _calculateFilteredItems();
        }
      } catch (e) {
        debugPrint('Error loading saved migration job: $e');
      }
    }
    setState(() => _isLoadingState = false);
    _slideController.forward();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('migration_job', jsonEncode(_job.toJson()));
  }

  void _calculateFilteredItems() {
    if (_job.source == null) {
      _filteredItems = [];
      return;
    }
    final now = DateTime.now();

    // Resolve date window from preset
    DateTime? from;
    DateTime? to;
    switch (_job.preset) {
      case 'last30':
        from = now.subtract(const Duration(days: 30));
        to   = now;
      case 'lastYear':
        from = now.subtract(const Duration(days: 365));
        to   = now;
      case 'before2023':
        to   = DateTime(2023, 1, 1);
      case 'custom':
        from = _job.dateFrom;
        to   = _job.dateTo;
      default: // 'all'
        from = null;
        to   = null;
    }

    final sourceItems = widget.allItems
        .where((i) => i.source == _job.source)
        .toList()
      ..sort((a, b) => (a.id).compareTo(b.id));

    _filteredItems = sourceItems.where((item) {
      // Media type filter
      if (_job.filter == 'photos' && item.isVideoFile) return false;
      if (_job.filter == 'videos' && !item.isVideoFile) return false;
      if (_job.filter == 'large' && (item.size ?? 0) < 10 * 1024 * 1024) return false;
      // Date range filter
      if (from != null && item.created != null && item.created!.isBefore(from)) return false;
      if (to   != null && item.created != null && item.created!.isAfter(to))   return false;
      return true;
    }).toList();

    _job.totalItems = _filteredItems.length;
    _job.totalBytes = _filteredItems.fold(0, (s, i) => s + (i.size ?? 0));
  }

  // ──────────── Migration control ────────────
  void _startMigration() async {
    if (_job.source == null || _job.destination == null) return;

    if (_job.isMove) {
      final confirm = await _showConfirmDialog();
      if (!confirm) return;
    }

    final hasSpace = await widget.onCheckSpace(
        _job.destination!, _job.totalBytes - _job.processedBytes);
    if (!hasSpace) {
      if (mounted) {
        _showSnack('Destination does not have enough free space.', isError: true);
      }
      return;
    }

    setState(() {
      _job.status = MigrationStatus.running;
      _isCancelled = false;
      _startTime = DateTime.now();
    });
    await _saveState();
    await _runMigrationLoop();
  }

  void _pauseMigration() {
    _isCancelled = true;
    setState(() => _job.status = MigrationStatus.paused);
    _saveState();
  }

  void _clearMigration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('migration_job');
    setState(() {
      _job = MigrationJob();
      _filteredItems = [];
      _startTime = null;
    });
    _slideController
      ..reset()
      ..forward();
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: _surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _danger.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: _danger, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text('Confirm Move',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary)),
                  const SizedBox(height: 8),
                  Text(
                    'Original files will be permanently deleted from the source after upload. This cannot be undone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _surfaceHigh),
                          foregroundColor: _textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Yes, Move'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _danger : _success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _getEta() {
    if (_startTime == null || _job.processedItems == 0) return 'Estimating…';
    final elapsed = DateTime.now().difference(_startTime!);
    final avg = elapsed.inMilliseconds / _job.processedItems;
    final rem = Duration(
        milliseconds:
            (avg * (_job.totalItems - _job.processedItems)).toInt());
    if (rem.inMinutes > 60) {
      return '${rem.inHours}h ${rem.inMinutes.remainder(60)}m left';
    }
    if (rem.inMinutes > 0) {
      return '${rem.inMinutes}m ${rem.inSeconds.remainder(60)}s left';
    }
    return '${rem.inSeconds}s left';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _runMigrationLoop() async {
    for (int i = _job.processedItems; i < _filteredItems.length; i++) {
      if (_isCancelled) break;
      final item = _filteredItems[i];
      bool success = false;
      File? tempFile;

      try {
        if (item.source == PhotoSource.local) {
          final asset = item.localAsset;
          if (asset != null) tempFile = await asset.file;
        } else {
          final url = await widget.onGetDownloadUrl(item);
          if (url != null) {
            final client = http.Client();
            final req = http.Request('GET', Uri.parse(url));
            final res = await client.send(req);
            if (res.statusCode == 200) {
              final dir = await getTemporaryDirectory();
              tempFile = File('${dir.path}/migration_${item.name}');
              final sink = tempFile.openWrite();
              await res.stream.pipe(sink);
              await sink.close();
            }
          }
        }
        if (tempFile != null && await tempFile.exists()) {
          success =
              await widget.onUpload(tempFile, item.name, _job.destination!);
          if (success && _job.isMove) await widget.onDelete(item);
        }
      } catch (e) {
        debugPrint('Migration error for ${item.name}: $e');
      } finally {
        if (tempFile != null &&
            item.source != PhotoSource.local &&
            await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }
      }

      if (success) {
        _job.successCount++;
      } else {
        _job.failedCount++;
        _job.failedItemNames.add(item.name); // track which files failed
      }
      _job.processedItems++;
      _job.processedBytes += item.size ?? 0;
      if (mounted) setState(() {});
      await _saveState();
    }

    if (!_isCancelled && mounted) {
      setState(() => _job.status = MigrationStatus.completed);
      await _saveState();
    }
  }

  // ──────────── Build ────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use app's default scaffold background (white in light, dark in dark mode)
      appBar: _buildAppBar(),
      body: _isLoadingState
          ? _buildLoader()
          : FadeTransition(
              opacity: _slideAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(_slideAnimation),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_job.status == MigrationStatus.running ||
                          _job.status == MigrationStatus.paused ||
                          _job.status == MigrationStatus.completed)
                        _buildProgressSection()
                      else
                        _buildConfigSection(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      // Inherits theme's appBar colors (blue in light mode per app theme)
      elevation: 0,
      title: const Text('Cloud Transfer'),
      actions: const [],
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: _accentGlow,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(_accent),
                strokeWidth: 2.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Loading…', style: TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceHigh, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sync_alt_rounded,
                color: _accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Cloud Migration',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Transfer media directly between connected cloud storage.',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────── Config section ────────────
  Widget _buildConfigSection() {
    final canStart = _job.source != null &&
        _job.destination != null &&
        _job.totalItems > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Source picker
        _buildSectionLabel('Source Cloud', Icons.cloud_upload_rounded),
        const SizedBox(height: 10),
        _buildCloudPicker(
          selected: _job.source,
          excludes: const [],
          onSelect: (s) => setState(() {
            _job.source = s;
            if (_job.destination == s) _job.destination = null;
            _calculateFilteredItems();
          }),
        ),
        const SizedBox(height: 20),

        // Arrow connector
        Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: _accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(height: 20),

        // Destination picker
        _buildSectionLabel('Destination Cloud', Icons.cloud_download_rounded),
        const SizedBox(height: 10),
        _buildCloudPicker(
          selected: _job.destination,
          excludes: [
            if (_job.source != null) _job.source!,
            PhotoSource.local,
          ],
          onSelect: (s) => setState(() => _job.destination = s),
        ),
        const SizedBox(height: 24),

        // ── What to transfer ──
        _buildSectionLabel('What to Transfer', Icons.filter_list_rounded),
        const SizedBox(height: 10),
        _buildPresetSection(),
        const SizedBox(height: 24),

        // Media type filter
        _buildSectionLabel('Media Type', Icons.perm_media_rounded),
        const SizedBox(height: 10),
        _buildFilterChips(),
        const SizedBox(height: 24),

        // Move toggle card
        _buildMoveToggle(),
        const SizedBox(height: 24),

        // Live Transfer Summary (replaces simple item count badge)
        if (_job.source != null)
          _buildTransferSummaryCard(),
        if (_job.source != null)
          const SizedBox(height: 20),

        // Start button
        _buildStartButton(canStart),
      ],
    );
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _accent),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCloudPicker({
    required PhotoSource? selected,
    required List<PhotoSource> excludes,
    required ValueChanged<PhotoSource> onSelect,
  }) {
    // Only show supported sources; apply caller-specific exclusions on top
    final sources = _kSupportedSources
        .where((s) => !excludes.contains(s))
        .toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sources.map((s) {
        final isSelected = selected == s;
        final quota = widget.storageQuotas[s.quotaKey];
        return GestureDetector(
          onTap: () => onSelect(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minWidth: 130),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? s.brandColor.withValues(alpha: 0.10)
                  : _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? s.brandColor : _surfaceHigh,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: s.brandColor.withValues(alpha: 0.18), blurRadius: 8)]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header row: icon + name + checkmark ──
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(s.icon,
                        color: isSelected ? s.brandColor : _textSecondary,
                        size: 16),
                    const SizedBox(width: 6),
                    Text(
                      s.displayName,
                      style: TextStyle(
                        color: isSelected ? s.brandColor : _textPrimary,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check_circle_rounded,
                          color: s.brandColor, size: 13),
                    ],
                  ],
                ),
                // ── Storage info (only for cloud sources with quota data) ──
                if (quota != null) ...[
                  const SizedBox(height: 7),
                  // Mini progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: quota.fraction,
                      minHeight: 4,
                      backgroundColor: _surfaceHigh,
                      valueColor: AlwaysStoppedAnimation(
                        quota.fraction > 0.85
                            ? _danger
                            : quota.fraction > 0.65
                                ? Colors.orange
                                : s.brandColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${quota.freeLabel} free',
                    style: TextStyle(
                      fontSize: 10,
                      color: quota.fraction > 0.85
                          ? _danger
                          : _textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else if (s != PhotoSource.local) ...[
                  // Cloud source but no quota loaded yet
                  const SizedBox(height: 6),
                  Text('Loading…',
                      style: TextStyle(fontSize: 10, color: _textSecondary)),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      ('all', 'All Media', Icons.perm_media_rounded),
      ('photos', 'Photos Only', Icons.photo_rounded),
      ('videos', 'Videos Only', Icons.videocam_rounded),
      ('large', 'Large > 10MB', Icons.data_usage_rounded),
    ];

    return Row(
      children: filters.map((f) {
        final isSelected = _job.filter == f.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(
                () {
              _job.filter = f.$1;
              _calculateFilteredItems();
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color:
                    isSelected ? _accent.withValues(alpha: 0.15) : _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? _accent : _surfaceHigh,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(f.$3,
                      size: 18,
                      color: isSelected ? _accent : _textSecondary),
                  const SizedBox(height: 4),
                  Text(
                    f.$2.split(' ').first,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? _accent : _textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ──────────── Preset section ────────────
  Widget _buildPresetSection() {
    final presets = [
      ('all',        'All Data',      Icons.all_inclusive_rounded,  'Every file in source'),
      ('last30',     'Last 30 Days',  Icons.calendar_today_rounded,  'Files from past month'),
      ('lastYear',   'Last Year',     Icons.calendar_month_rounded,  'Files from past 12 months'),
      ('before2023', 'Before 2023',   Icons.history_rounded,         'Archive: files before 2023'),
      ('custom',     'Custom Range',  Icons.date_range_rounded,      'Pick your own date range'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preset chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((p) {
            final isSelected = _job.preset == p.$1;
            return GestureDetector(
              onTap: () async {
                if (p.$1 == 'custom') {
                  await _pickCustomDateRange();
                } else {
                  setState(() {
                    _job.preset  = p.$1;
                    _job.dateFrom = null;
                    _job.dateTo   = null;
                  });
                  _calculateFilteredItems();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _accent.withValues(alpha: 0.12) : _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? _accent : _surfaceHigh,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(p.$3,
                        size: 15,
                        color: isSelected ? _accent : _textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      p.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? _accent : _textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        // Custom date range display row
        if (_job.preset == 'custom') ...[
          const SizedBox(height: 12),
          _buildCustomDateRow(),
        ],

        // Description of selected preset
        const SizedBox(height: 8),
        Text(
          presets.firstWhere((p) => p.$1 == _job.preset,
              orElse: () => presets.first).$4,
          style: TextStyle(
              fontSize: 11, color: _textSecondary, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildCustomDateRow() {
    String fmtDate(DateTime? d) =>
        d == null ? 'Pick date' : '${d.day}/${d.month}/${d.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range_rounded, size: 16, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _job.dateFrom ?? DateTime.now().subtract(const Duration(days: 365)),
                  firstDate: DateTime(2010),
                  lastDate: _job.dateTo ?? DateTime.now(),
                  helpText: 'From date',
                );
                if (picked != null) {
                  setState(() => _job.dateFrom = picked);
                  _calculateFilteredItems();
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('From', style: TextStyle(fontSize: 10, color: _textSecondary)),
                  Text(fmtDate(_job.dateFrom),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _job.dateFrom == null ? _textSecondary : _textPrimary)),
                ],
              ),
            ),
          ),
          Container(
            width: 1, height: 36,
            color: _surfaceHigh,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _job.dateTo ?? DateTime.now(),
                  firstDate: _job.dateFrom ?? DateTime(2010),
                  lastDate: DateTime.now(),
                  helpText: 'To date',
                );
                if (picked != null) {
                  setState(() => _job.dateTo = picked);
                  _calculateFilteredItems();
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('To', style: TextStyle(fontSize: 10, color: _textSecondary)),
                  Text(fmtDate(_job.dateTo),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _job.dateTo == null ? _textSecondary : _textPrimary)),
                ],
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 16, color: _textSecondary),
        ],
      ),
    );
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      initialDateRange: (_job.dateFrom != null && _job.dateTo != null)
          ? DateTimeRange(start: _job.dateFrom!, end: _job.dateTo!)
          : null,
      helpText: 'Select date range to migrate',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: _accent,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _job.preset   = 'custom';
        _job.dateFrom = picked.start;
        _job.dateTo   = picked.end;
      });
      _calculateFilteredItems();
    }
  }

  Widget _buildMoveToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _job.isMove
              ? _danger.withValues(alpha: 0.4)
              : _surfaceHigh,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (_job.isMove ? _danger : _accent).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _job.isMove
                  ? Icons.drive_file_move_rounded
                  : Icons.file_copy_rounded,
              color: _job.isMove ? _danger : _accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _job.isMove
                      ? 'Move (Delete Original)'
                      : 'Copy (Keep Original)',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _job.isMove
                      ? 'Files removed from source after upload'
                      : 'Files kept intact in source cloud',
                  style: TextStyle(
                      color: _textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: _job.isMove,
            onChanged: (v) => setState(() => _job.isMove = v),
            activeThumbColor: _danger,
            inactiveThumbColor: _accent,
            inactiveTrackColor: _accent.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  // ──────────── Transfer Summary Card ────────────
  Widget _buildTransferSummaryCard() {
    final destQuota = _job.destination != null
        ? widget.storageQuotas[_job.destination!.quotaKey]
        : null;
    final freeBytes = destQuota != null
        ? destQuota.totalBytes - destQuota.usedBytes
        : null;
    final willFit = freeBytes == null || freeBytes >= _job.totalBytes;

    // Estimate: assume ~1 MB/s average upload speed
    final estimatedSecs = _job.totalBytes > 0 ? _job.totalBytes ~/ (1024 * 1024) : 0;
    String etaLabel;
    if (estimatedSecs == 0) {
      etaLabel = '—';
    } else if (estimatedSecs < 60) {
      etaLabel = '< 1 min';
    } else if (estimatedSecs < 3600) {
      etaLabel = '~${estimatedSecs ~/ 60} min';
    } else {
      etaLabel = '~${estimatedSecs ~/ 3600}h ${(estimatedSecs % 3600) ~/ 60}m';
    }

    final hasItems = _job.totalItems > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: !hasItems
              ? _surfaceHigh
              : willFit ? _accent.withValues(alpha: 0.4) : _danger.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                hasItems ? Icons.summarize_rounded : Icons.info_outline_rounded,
                color: hasItems ? _accent : _textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Transfer Summary',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          if (!hasItems) ...[
            Text(
              'Select a source cloud to see what will be transferred.',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ] else ...[
            // Stats grid
            Row(children: [
              _summaryTile(
                Icons.folder_copy_rounded, _accent,
                '${_job.totalItems}',
                'Files',
              ),
              const SizedBox(width: 10),
              _summaryTile(
                Icons.storage_rounded, const Color(0xFF0284C7),
                _formatBytes(_job.totalBytes),
                'Total Size',
              ),
              const SizedBox(width: 10),
              _summaryTile(
                Icons.timer_outlined, const Color(0xFF0EA5E9),
                etaLabel,
                'Est. Time',
              ),
            ]),
            const SizedBox(height: 12),

            // Destination space bar
            if (destQuota != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Space at ${_job.destination?.displayName ?? 'destination'}',
                    style: TextStyle(fontSize: 11, color: _textSecondary),
                  ),
                  Text(
                    '${destQuota.freeLabel} free of ${destQuota.totalLabel}',
                    style: TextStyle(
                      fontSize: 11,
                      color: willFit ? _textSecondary : _danger,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Stack(
                children: [
                  // Full bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: destQuota.fraction,
                      minHeight: 8,
                      backgroundColor: _surfaceHigh,
                      valueColor: AlwaysStoppedAnimation(
                        destQuota.fraction > 0.85 ? _danger : const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
              if (!willFit) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded, color: _danger, size: 14),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Not enough free space at destination for this transfer.',
                        style: TextStyle(color: _danger, fontSize: 11),
                      ),
                    ),
                  ]),
                ),
              ],
            ] else if (_job.destination != null) ...[
              Text(
                'Storage info unavailable for destination.',
                style: TextStyle(color: _textSecondary, fontSize: 11),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _summaryTile(IconData icon, Color color, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            Text(label,
                style: TextStyle(
                    color: _textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(bool enabled) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          disabledBackgroundColor: _surfaceHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: enabled ? _startMigration : null,
        icon: const Icon(Icons.sync_alt_rounded, size: 20, color: Colors.white),
        label: Text(
          enabled ? 'Start Migration' : 'Select Source & Destination',
          style: TextStyle(
            color: enabled ? Colors.white : _textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ──────────── Progress section ────────────
  Widget _buildProgressSection() {
    final progress =
        _job.totalItems > 0 ? _job.processedItems / _job.totalItems : 0.0;
    final isRunning   = _job.status == MigrationStatus.running;
    final isPaused    = _job.status == MigrationStatus.paused;
    final isCompleted = _job.status == MigrationStatus.completed;

    return Column(
      children: [
        _buildProgressHeaderCard(isRunning, isPaused, isCompleted),
        const SizedBox(height: 16),
        _buildProgressRing(progress, isCompleted),
        const SizedBox(height: 16),
        _buildStatsRow(),
        // Show failed items list when there are failures (collapsed by default)
        if (_job.failedCount > 0) ...[
          const SizedBox(height: 10),
          _buildFailedItemsCard(),
        ],
        const SizedBox(height: 16),
        _buildDetailCard(isRunning, isCompleted),
        const SizedBox(height: 24),
        _buildProgressActions(isRunning, isPaused, isCompleted),
      ],
    );
  }

  Widget _buildProgressHeaderCard(
      bool isRunning, bool isPaused, bool isCompleted) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isCompleted) {
      statusColor = _success;
      statusLabel = 'Completed';
      statusIcon = Icons.check_circle_rounded;
    } else if (isPaused) {
      statusColor = Colors.amber;
      statusLabel = 'Paused';
      statusIcon = Icons.pause_circle_rounded;
    } else {
      statusColor = _accent;
      statusLabel = 'Running';
      statusIcon = Icons.sync_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (_job.source != null) ...[
            _cloudBadge(_job.source!),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Icon(
                  Icons.east_rounded,
                  color: isRunning
                      ? Color.lerp(_accent, const Color(0xFF0284C7),
                          _pulseController.value)!
                      : statusColor,
                  size: 22,
                ),
              ),
            ),
          ),
          if (_job.destination != null) ...[
            _cloudBadge(_job.destination!),
            const SizedBox(width: 8),
          ],
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              Icon(statusIcon, color: statusColor, size: 13),
              const SizedBox(width: 4),
              Text(statusLabel,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _cloudBadge(PhotoSource src) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: src.brandColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: src.brandColor.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(src.icon, color: src.brandColor, size: 13),
        const SizedBox(width: 4),
        Text(src.displayName,
            style: TextStyle(
                color: src.brandColor,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildProgressRing(double progress, bool isCompleted) {
    return SizedBox(
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(180, 180),
            painter: _RingPainter(
              progress: progress,
              color: isCompleted ? _success : _accent,
              trackColor: _surfaceHigh,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: isCompleted ? _success : _textPrimary,
                  letterSpacing: -1,
                ),
              ),
              Text(
                '${_job.processedItems} / ${_job.totalItems}',
                style: TextStyle(
                    color: _textSecondary, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(children: [
      Expanded(
          child: _statCard(
              'Succeeded', '${_job.successCount}', _success, Icons.check_rounded)),
      const SizedBox(width: 10),
      Expanded(
          child: _statCard(
              'Failed', '${_job.failedCount}', _danger, Icons.close_rounded)),
      const SizedBox(width: 10),
      Expanded(
          child: _statCard('Transferred',
              _formatBytes(_job.processedBytes), _accent, Icons.data_usage_rounded)),
    ]);
  }

  Widget _statCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: _textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  /// Expandable card listing every file that failed to transfer.
  Widget _buildFailedItemsCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: _danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // ── Header / toggle ──────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _showFailedItems = !_showFailedItems),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: _danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_job.failedCount} file${_job.failedCount == 1 ? '' : 's'} failed to transfer',
                      style: const TextStyle(
                        color: _danger,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    _showFailedItems
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _danger,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // ── File list (only visible when expanded) ───────────────
          if (_showFailedItems)
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: _danger.withValues(alpha: 0.2)),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: _job.failedItemNames.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: _danger.withValues(alpha: 0.1),
                  indent: 42,
                ),
                itemBuilder: (context, index) {
                  final name = _job.failedItemNames[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file_outlined,
                            color: _danger, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(bool isRunning, bool isCompleted) {
    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _success.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.celebration_rounded,
              color: _success, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('Migration Complete!',
                  style: TextStyle(
                      color: _success,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const SizedBox(height: 2),
              Text('${_job.successCount} files transferred successfully',
                  style: TextStyle(
                      color: _textSecondary, fontSize: 12)),
            ]),
          ),
        ]),
      );
    }

    if (isRunning) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accentGlow),
        ),
        child: Row(children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Icon(
              Icons.timer_outlined,
              color: Color.lerp(_accent, const Color(0xFF0284C7),
                  _pulseController.value),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Text(_getEta(),
              style: TextStyle(
                  color: _textPrimary, fontWeight: FontWeight.w600)),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.pause_circle_outline_rounded,
            color: Colors.amber, size: 20),
        SizedBox(width: 10),
        Text('Migration paused — tap Resume to continue',
            style: TextStyle(color: _textSecondary, fontSize: 13)),
      ]),
    );
  }

  Widget _buildProgressActions(
      bool isRunning, bool isPaused, bool isCompleted) {
    return Row(children: [
      if (isRunning)
        Expanded(
            child: _actionButton(
          label: 'Pause',
          icon: Icons.pause_rounded,
          color: Colors.amber,
          onTap: _pauseMigration,
        )),
      if (isPaused) ...[
        Expanded(
            child: _actionButton(
          label: 'Resume',
          icon: Icons.play_arrow_rounded,
          color: _accent,
          onTap: _startMigration,
        )),
        const SizedBox(width: 10),
      ],
      if (isPaused || isCompleted)
        Expanded(
            child: _actionButton(
          label: 'New Migration',
          icon: Icons.add_rounded,
          color: _success,
          onTap: _clearMigration,
        )),
    ]);
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Custom painter for arc progress ring
// ─────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _RingPainter(
      {required this.progress,
      required this.color,
      required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 20) / 2;
    const strokeWidth = 10.0;

    // Track ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Glow blur
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Progress arc with sweep gradient
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [color, Color.lerp(color, Colors.white, 0.3)!],
          stops: const [0.0, 1.0],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(
            Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
