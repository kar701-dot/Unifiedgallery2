// lib/data/face_record.dart
//
// Isar collection schema for detected individual face bounding boxes and feature descriptors.

import 'package:isar/isar.dart';

part 'face_record.g.dart';

@collection
class FaceRecord {
  /// Internal Isar primary key
  Id id = Isar.autoIncrement;

  /// Firebase user ID for multi-tenant isolation
  @Index()
  late String userId;

  /// Asset uniqueKey this face belongs to (matches AssetRecord.uniqueKey)
  @Index(type: IndexType.hash)
  late String assetKey;

  /// Assigned Person cluster ID (matches PersonRecord.personId)
  @Index(type: IndexType.hash)
  late String personId;

  /// Bounding box normalized coordinates [left, top, width, height] (0.0 to 1.0)
  List<double>? boundingBox;

  /// Facial landmark features used for similarity clustering:
  /// [leftEyeX, leftEyeY, rightEyeX, rightEyeY, noseX, noseY, mouthX, mouthY]
  List<double>? landmarks;

  /// Perceptual hash or feature vector string of the face crop
  String? featureHash;

  /// When this face was detected
  DateTime createdAt = DateTime.now();
}
