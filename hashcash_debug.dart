import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:typed_data';

void main() {
  final easiness = 192;
  final token = 'UBVHERKWApo0TK_JJMEgf8w_jfVGd2Y5dP-kqlXz3DecyY3LRIin505aRhDcLrVi';
  
  final threshold = (((easiness & 63) << 1) + 1) << ((easiness >> 6) * 7 + 3);
  print('Threshold: \$threshold');

  String padded = token.replaceAll('-', '+').replaceAll('_', '/');
  while (padded.length % 4 != 0) padded += '=';
  List<int> tokenDecoded = base64.decode(padded);
  
  final numReplications = 262144;
  final tokenSlotSize = 48;
  final buffer = Uint8List(4 + numReplications * tokenSlotSize);
  
  for (var i = 0; i < numReplications; i++) {
    buffer.setRange(4 + i * tokenSlotSize, 4 + i * tokenSlotSize + tokenDecoded.length, tokenDecoded);
  }

  print('Buffer size: \${buffer.length}');

  for (int i = 0; i <= 10000; i++) { // Test up to 10000 for debug
    buffer[0] = i & 0xFF;
    buffer[1] = (i >> 8) & 0xFF;
    buffer[2] = (i >> 16) & 0xFF;
    buffer[3] = (i >> 24) & 0xFF;
    
    final hash = crypto.sha256.convert(buffer).bytes;
    final hashValue = (hash[0] << 24) | (hash[1] << 16) | (hash[2] << 8) | hash[3];
    
    if (i % 100 == 0) {
      print('Attempt \$i: hash[0..3] = \${hash.sublist(0, 4)} -> hashValue: \$hashValue');
    }

    if (hashValue <= threshold) {
      String res = base64Url.encode(buffer.sublist(0, 4)).replaceAll('=', '');
      print('Solved! \$res');
      return;
    }
  }
  print('Not solved in 10000');
}
