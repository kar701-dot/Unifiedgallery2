// lib/data/person_record.dart
//
// Isar collection schema for recognized People / Face clusters.

import 'package:isar/isar.dart';

part 'person_record.g.dart';

@collection
class PersonRecord {
  /// Internal Isar primary key
  Id id = Isar.autoIncrement;

  /// Firebase user ID for multi-tenant isolation
  @Index()
  late String userId;

  /// Unique cluster ID for this person (e.g. 'person_uuid_1234')
  @Index(type: IndexType.hash, unique: true)
  late String personId;

  /// User-assigned name (e.g. "Mom", "Alex"). Null if not named yet.
  @Index(type: IndexType.hash)
  String? name;

  /// Asset uniqueKey of the best representative face cover photo
  String? coverFaceAssetKey;

  /// Bounding box of the cover face: [left, top, width, height] (normalized 0.0–1.0)
  List<double>? coverBoundingBox;

  /// Total number of photos associated with this person
  int photoCount = 0;

  /// Running-average centroid of all face embeddings in this cluster.
  /// Used for O(clusters) cosine comparison instead of O(all_faces).
  /// L2-normalized 192D vector from MobileFaceNet (or 6D geometric fallback).
  List<double>? centroidEmbedding;

  /// When this person cluster was first created
  DateTime createdAt = DateTime.now();

  /// Display label: returns assigned name or default "Person X" fallback
  String get displayName => (name != null && name!.trim().isNotEmpty) ? name! : 'Person $id';
}
