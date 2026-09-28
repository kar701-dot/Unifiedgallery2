import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final uri = Uri.parse('https://g.api.mega.co.nz/cs?id=123456');
  final reqBody = jsonEncode([{'a': 'us', 'user': 'test@example.com', 'uh': 'dummy'}]);
  final req = http.Request('POST', uri)
    ..body = reqBody
    ..headers['Content-Type'] = 'application/json';
  
  print('Sending request to Mega...');
  final res = await req.send();
  final body = await res.stream.bytesToString();
  print('HTTP ${res.statusCode}');
  print('Headers:');
  res.headers.forEach((k, v) => print('  $k: $v'));
  print('Body: $body');
}
