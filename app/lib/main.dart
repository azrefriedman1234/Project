import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api.dart';
import 'blur_overlay.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String baseUrl = "http://10.0.2.2:8000"; // אמולטור; בטלפון לשים כתובת שרת אמיתית

  @override
  Widget build(BuildContext context) {
    final api = Api(baseUrl);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: StartScreen(api: api, onSetBaseUrl: (v){ setState(()=>baseUrl=v); }),
    );
  }
}

class StartScreen extends StatefulWidget {
  final Api api;
  final void Function(String) onSetBaseUrl;
  const StartScreen({super.key, required this.api, required this.onSetBaseUrl});
  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  bool? authed;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getString("baseUrl");
    if (saved != null) widget.onSetBaseUrl(saved);
    final ok = await widget.api.authStatus();
    setState(() => authed = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (authed == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return authed == true
        ? LiveScreen(api: widget.api)
        : LoginScreen(api: widget.api, onLoggedIn: () => setState(()=>authed=true));
  }
}

class LoginScreen extends StatefulWidget {
  final Api api;
  final VoidCallback onLoggedIn;
  const LoginScreen({super.key, required this.api, required this.onLoggedIn});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneC = TextEditingController();
  final codeC = TextEditingController();
  final passC = TextEditingController();

  String status = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("התחברות לטלגרם")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: phoneC, decoration: const InputDecoration(labelText: "מספר טלפון כולל +972")),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              setState(()=>status="שולח קוד...");
              await widget.api.authStart(phoneC.text.trim());
              setState(()=>status="נשלח קוד. הזן קוד SMS");
            },
            child: const Text("שלח קוד"),
          ),
          const SizedBox(height: 8),
          TextField(controller: codeC, decoration: const InputDecoration(labelText: "קוד")),
          ElevatedButton(
            onPressed: () async {
              setState(()=>status="מאמת...");
              final res = await widget.api.authVerify(phoneC.text.trim(), codeC.text.trim());
              if (res["authorized"] == true) {
                widget.onLoggedIn();
              } else {
                setState(()=>status="אימות נכשל/ייתכן 2FA: ${res["error"]}");
              }
            },
            child: const Text("אמת קוד"),
          ),
          const Divider(),
          TextField(controller: passC, obscureText: true, decoration: const InputDecoration(labelText: "סיסמת 2FA (אם צריך)")),
          ElevatedButton(
            onPressed: () async {
              setState(()=>status="מאמת 2FA...");
              await widget.api.authPassword(passC.text.trim());
              widget.onLoggedIn();
            },
            child: const Text("התחבר עם 2FA"),
          ),
          const SizedBox(height: 12),
          Text(status),
        ]),
      ),
    );
  }
}

class LiveScreen extends StatefulWidget {
  final Api api;
  const LiveScreen({super.key, required this.api});
  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  WebSocketChannel? ch;
  final msgs = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    ch = widget.api.liveWs();
    ch!.stream.listen((event) {
      final j = jsonDecode(event);
      if (j["type"] == "message") {
        final m = Map<String, dynamic>.from(j["data"]);
        setState(() {
          msgs.insert(0, m); // חדש למעלה
          if (msgs.length > 200) msgs.removeLast();
        });
      }
    });
  }

  @override
  void dispose() {
    ch?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("לייב – הודעות טלגרם"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(api: widget.api))),
          )
        ],
      ),
      body: ListView.builder(
        itemCount: msgs.length,
        itemBuilder: (_, i) {
          final m = msgs[i];
          final text = (m["text_he"] ?? m["text"] ?? "").toString();
          return ListTile(
            title: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text("chat_id: ${m["chat_id"]}  msg_id: ${m["id"]}  media: ${m["media_type"] ?? '-'}"),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => MessageDetailsScreen(api: widget.api, msg: m),
            )),
          );
        },
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final Api api;
  const SettingsScreen({super.key, required this.api});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final channelC = TextEditingController(text: "@yourchannel");
  String status = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("הגדרות")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: channelC, decoration: const InputDecoration(labelText: "ערוץ יעד לשליחה (למשל @mychannel)")),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              await widget.api.setTargetChannel(channelC.text.trim());
              setState(()=>status="נשמר");
            },
            child: const Text("שמור"),
          ),
          const SizedBox(height: 8),
          Text(status),
        ]),
      ),
    );
  }
}

class MessageDetailsScreen extends StatefulWidget {
  final Api api;
  final Map<String, dynamic> msg;
  const MessageDetailsScreen({super.key, required this.api, required this.msg});

  @override
  State<MessageDetailsScreen> createState() => _MessageDetailsScreenState();
}

class _MessageDetailsScreenState extends State<MessageDetailsScreen> {
  List<RectSel> rects = [];
  String status = "";
  String? downloadedPath;
  String? outputPath;

  @override
  Widget build(BuildContext context) {
    final chatId = (widget.msg["chat_id"] ?? 0) as int;
    final msgId = (widget.msg["id"] ?? 0) as int;
    final mediaType = widget.msg["media_type"]?.toString();

    return Scaffold(
      appBar: AppBar(title: const Text("פרטי הודעה")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("טקסט:", style: Theme.of(context).textTheme.titleMedium),
          Text((widget.msg["text_he"] ?? widget.msg["text"] ?? "").toString()),
          const SizedBox(height: 12),

          if (mediaType != null) ...[
            ElevatedButton(
              onPressed: () async {
                setState(()=>status="מוריד מדיה...");
                final r = await widget.api.downloadMedia(chatId, msgId);
                setState(() {
                  downloadedPath = r["path"];
                  status = "הורד: $downloadedPath";
                });
              },
              child: const Text("הורד מדיה (שרת)"),
            ),
            const SizedBox(height: 8),

            // MVP: תצוגה מקדימה “דמו” כקופסה, כי הצגת קובץ מהשרת דורשת URL סטטי/שרת קבצים.
            // בהמשך נוסיף endpoint שמחזיר thumbnail URL
            SizedBox(
              height: 220,
              child: BlurOverlay(
                onChanged: (r) => setState(()=>rects = r),
                child: Container(
                  alignment: Alignment.center,
                  color: Colors.black12,
                  child: Text("תצוגה מקדימה (MVP)\nבחר מלבנים לטשטוש במסך מגע", textAlign: TextAlign.center),
                ),
              ),
            ),
            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: downloadedPath == null ? null : () async {
                setState(()=>status="מעבד טשטוש בשרת...");
                // המלבנים כאן הם לפי הקופסה שציירת. בשביל דיוק אמיתי צריך להמיר לקואורדינטות של המדיה המקורית.
                // ב-MVP נניח יחס 1:1 או נוסיף מיפוי בהמשך עם metadata (רוחב/גובה).
                final rectMaps = rects.map((e) => {
                  "x": e.rect.left,
                  "y": e.rect.top,
                  "w": e.rect.width,
                  "h": e.rect.height
                }).toList();

                final kind = (mediaType == "photo") ? "image" : "video";
                final res = await widget.api.blurMedia(downloadedPath!, kind, rectMaps);
                setState(() {
                  outputPath = res["output_path"];
                  status = "מוכן: $outputPath";
                });
              },
              child: const Text("החל טשטוש על המדיה"),
            ),
          ],

          const SizedBox(height: 12),
          Text(status),
        ]),
      ),
    );
  }
}
