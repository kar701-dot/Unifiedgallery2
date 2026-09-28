// lib/ai_tag.dart
import 'package:isar/isar.dart';

// This line is required for the code generator
part 'ai_tag.g.dart';

@collection
class AITag {
  // Isar's fast 64-bit int primary key
  Id id = Isar.autoIncrement;

  // This is where we will store your 'getUniqueKey()' string.
  // We add a 'hash' index to make searching by this key extremely fast.
  @Index(type: IndexType.hash, unique: true)
  String? itemKey;

  // The list of AI-generated tags
  List<String>? tags;
}