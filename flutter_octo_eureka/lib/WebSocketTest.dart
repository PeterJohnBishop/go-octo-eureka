import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketTest extends StatefulWidget {
  const WebSocketTest({super.key});

  @override
  State<WebSocketTest> createState() => _WebSocketTestState();
}

class _WebSocketTestState extends State<WebSocketTest> {
  late WebSocketChannel channel;

  final TextEditingController _controller = TextEditingController();
  final String myName = "FlutterApp"; // The name you send to the server
  final List<Map<String, dynamic>> _messages = []; // Store full objects now

  @override
  void initState() {
    super.initState();

    // Use 10.0.2.2 for Android Emulator, localhost for iOS
    channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8080/ws'));

    _sendEvent("CLIENT_CONNECTED", "app connected");
  }

  @override
  void dispose() {
    channel.sink.close(status.goingAway);
    _controller.dispose();
    super.dispose();
  }

  void _sendEvent(String eventName, String data) {
    if (data.isNotEmpty) {
      final message = jsonEncode({
        "event": eventName,
        "data": data,
        "sender": "FlutterApp",
      });

      channel.sink.add(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Go Gin WebSocket")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StreamBuilder(
                stream: channel.stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  }

                  if (snapshot.hasData) {
                    try {
                      final dataMap = jsonDecode(snapshot.data as String);
                      final displayMsg =
                          "[${dataMap['sender']}] ${dataMap['event']}: ${dataMap['data']}";

                      _messages.insert(0, dataMap);
                    } catch (e) {
                      print("Error parsing JSON: $e");
                    }
                  }

                  return ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];

                      final bool isMe = msg['sender'] == myName;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.7,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.black : Colors.grey[300],
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: isMe
                                      ? const Radius.circular(12)
                                      : Radius.zero,
                                  bottomRight: isMe
                                      ? Radius.zero
                                      : const Radius.circular(12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Text(
                                      msg['sender'],
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                  Text(
                                    msg['data'],
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: "Send Announcement",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    _sendEvent("ANNOUNCEMENT", _controller.text);
                    _controller.clear();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
