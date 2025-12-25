import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class Api {
  final String baseUrl; // e.g. https://YOUR_BACKEND.onrender.com
  Api(this.baseUrl);

  Uri _u(String p) => Uri.parse('$baseUrl$p');

  Future<bool> authStatus() async {
    final r = await http.get(_u('/auth/status'));
    final j = jsonDecode(r.body);
    return j['authorized'] == true;
  }

  Future<void> authStart(String phone) async {
    final r = await http.post(_u('/auth/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}));
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<Map<String, dynamic>> authVerify(String phone, String code) async {
    final r = await http.post(_u('/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'code': code}));
    return jsonDecode(r.body);
  }

  Future<void> authPassword(String password) async {
    final r = await http.post(_u('/auth/password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': password}));
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  WebSocketChannel liveWs() {
    final wsUrl = baseUrl.replaceFirst('http', 'ws') + '/ws/live';
    return WebSocketChannel.connect(Uri.parse(wsUrl));
  }

  Future<List<dynamic>> dialogs() async {
    final r = await http.get(_u('/dialogs'));
    if (r.statusCode >= 400) throw Exception(r.body);
    return jsonDecode(r.body);
  }

  Future<List<dynamic>> messages(int chatId, {int limit=50}) async {
    final r = await http.get(_u('/messages/$chatId?limit=$limit'));
    if (r.statusCode >= 400) throw Exception(r.body);
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> downloadMedia(int chatId, int msgId) async {
    final r = await http.get(_u('/media/download/$chatId/$msgId'));
    if (r.statusCode >= 400) throw Exception(r.body);
    return jsonDecode(r.body);
  }

  Future<void> setTargetChannel(String channel) async {
    final r = await http.post(_u('/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'target_channel': channel}));
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<Map<String, dynamic>> blurMedia(String inputPath, String kind, List<Map<String, num>> rects) async {
    final r = await http.post(_u('/media/blur'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'input_path': inputPath, 'kind': kind, 'rects': rects}));
    if (r.statusCode >= 400) throw Exception(r.body);
    return jsonDecode(r.body);
  }
}
