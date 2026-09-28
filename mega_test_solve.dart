import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart' as crypto;
import 'dart:typed_data';

String solveHashcash(String token, int easiness) {
  final threshold = (((easiness & 63) << 1) + 1) << ((easiness >> 6) * 7 + 3);
  
  String padded = token.replaceAll('-', '+').replaceAll('_', '/');
  while (padded.length % 4 != 0) padded += '=';
  List<int> tokenDecoded = base64.decode(padded);
  
  final rem = tokenDecoded.length % 16;
  if (rem != 0) {
    tokenDecoded = [...tokenDecoded, ...List<int>.filled(16 - rem, 0)];
  }
  
  final numReplications = 262144;
  final tokenSlotSize = 48;
  final buffer = Uint8List(4 + numReplications * tokenSlotSize);
  
  for (var i = 0; i < numReplications; i++) {
    buffer.setRange(4 + i * tokenSlotSize, 4 + i * tokenSlotSize + tokenDecoded.length, tokenDecoded);
  }

  print('Computing hashcash...');
  final sw = Stopwatch()..start();
  for (int i = 0; i <= 0xFFFFFFFF; i++) {
    buffer[0] = i & 0xFF;
    buffer[1] = (i >> 8) & 0xFF;
    buffer[2] = (i >> 16) & 0xFF;
    buffer[3] = (i >> 24) & 0xFF;
    
    final hash = crypto.sha256.convert(buffer).bytes;
    final hashValue = (hash[0] << 24) | (hash[1] << 16) | (hash[2] << 8) | hash[3];
    
    if (hashValue <= threshold) {
      String res = base64Url.encode(buffer.sublist(0, 4)).replaceAll('=', '');
      print('Solved in ' + sw.elapsedMilliseconds.toString() + 'ms. Solution: ' + res);
      return res;
    }
  }
  return '';
}

void main() async {
  final uri = Uri.parse('https://g.api.mega.co.nz/cs?id=${DateTime.now().millisecondsSinceEpoch}');
  final reqBody = jsonEncode([{'a': 'us', 'user': 'test@example.com', 'uh': 'dummy'}]);
  
  final headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Origin': 'https://mega.nz',
    'Referer': 'https://mega.nz/',
  };

  print('1. Sending initial request to Mega (followRedirects=false)...');
  final client = http.Client();
  var req = http.Request('POST', uri)
    ..headers.addAll(headers)
    ..body = reqBody
    ..followRedirects = false;
  
  var streamed = await client.send(req);
  var statusCode = streamed.statusCode;
  var respHeaders = streamed.headers;
  var respBody = await streamed.stream.bytesToString();
  print('HTTP ' + statusCode.toString() + ' | body length: ' + respBody.length.toString());
  
  if (streamed.isRedirect || (statusCode >= 301 && statusCode <= 307)) {
    final location = respHeaders['location'];
    print('Redirecting manually to location: ' + location.toString());
    if (location != null) {
      final rResp = await client.post(
        Uri.parse(location),
        headers: headers,
        body: reqBody,
      );
      statusCode = rResp.statusCode;
      respHeaders = rResp.headers;
      respBody = rResp.body;
      print('HTTP ' + statusCode.toString() + ' (after manual redirect)');
    }
  }

  if (statusCode == 402) {
    final hc = respHeaders['x-hashcash'] ?? respHeaders['X-Hashcash'];
    if (hc != null) {
      print('Received Challenge: ' + hc);
      final parts = hc.split(':');
      final easiness = int.parse(parts[1]);
      final token = parts[3];
      
      final cashValue = solveHashcash(token, easiness);
      
      print('2. Resending request with solution...');
      final newHeader = '1:' + token + ':' + cashValue;
      print('X-Hashcash: ' + newHeader);
      
      headers['X-Hashcash'] = newHeader;
      
      // Let's call the second request
      var req2 = http.Request('POST', uri)
        ..headers.addAll(headers)
        ..body = reqBody
        ..followRedirects = false;
        
      var streamed2 = await client.send(req2);
      var statusCode2 = streamed2.statusCode;
      var respHeaders2 = streamed2.headers;
      var respBody2 = await streamed2.stream.bytesToString();
      print('HTTP ' + statusCode2.toString() + ' | body length: ' + respBody2.length.toString());

      if (streamed2.isRedirect || (statusCode2 >= 301 && statusCode2 <= 307)) {
        final location2 = respHeaders2['location'];
        print('Redirecting retry manually to location: ' + location2.toString());
        if (location2 != null) {
          final rResp2 = await client.post(
            Uri.parse(location2),
            headers: headers,
            body: reqBody,
          );
          statusCode2 = rResp2.statusCode;
          respHeaders2 = rResp2.headers;
          respBody2 = rResp2.body;
          print('HTTP ' + statusCode2.toString() + ' (after retry manual redirect)');
        }
      }
      
      print('Final Status: ' + statusCode2.toString());
      print('Body: ' + respBody2);
    }
  }
  client.close();
}
