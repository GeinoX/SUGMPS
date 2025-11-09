import 'dart:async';
import 'dart:convert';
import 'package:sugmps/core/routes/routes.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class NotificationSocketService {
  WebSocketChannel? _channel;
  Function(Map<String, dynamic>)? onMessage;
  bool _isConnected = false;
  bool _manuallyClosed = false;
  int _retryAttempts = 0;

  // Stream subscription for incoming events
  StreamSubscription? _subscription;

  /// Connects to the WebSocket server with a JWT token.
  void connect(String token) {
    final uri = Uri.parse(
      "wss://${AppRoutes.socketurl}/ws/notifications/?token=$token",
    );

    print("🔌 Connecting to WebSocket: $uri");
    print(token);

    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      _manuallyClosed = false;
      _retryAttempts = 0;

      print("✅ Connected to WebSocket");

      // Listen for incoming messages
      _subscription = _channel!.stream.listen(
        (event) {
          print("📩 Received event: $event");
          try {
            final data = jsonDecode(event);
            onMessage?.call(data);
          } catch (e) {
            print("⚠️ Error decoding event: $e");
          }
        },
        onError: (error) {
          print("❌ WebSocket error: $error");
          _handleDisconnect(token);
        },
        onDone: () {
          print("🔒 WebSocket connection closed (done).");
          _handleDisconnect(token);
        },
        cancelOnError: true,
      );
    } catch (e) {
      print("🚨 Exception while connecting: $e");
      _handleDisconnect(token);
    }
  }

  /// Handles disconnection and attempts reconnection if not manually closed.
  void _handleDisconnect(String token) {
    if (_manuallyClosed) return;

    _isConnected = false;

    // Exponential backoff: wait 2^n seconds before retry (max 32s)
    final retryDelay = Duration(seconds: (2 << _retryAttempts).clamp(2, 32));
    _retryAttempts++;

    print("⏳ Reconnecting in ${retryDelay.inSeconds} seconds...");

    Future.delayed(retryDelay, () {
      if (!_manuallyClosed) {
        print("🔁 Retrying WebSocket connection...");
        connect(token);
      }
    });
  }

  /// Sends a notification message to the server.
  void sendNotification(String message, int courseId) {
    if (_isConnected && _channel != null) {
      final data = jsonEncode({"message": message, "course_id": courseId});
      _channel!.sink.add(data);
      print("📤 Sent: $data");
    } else {
      print("⚠️ WebSocket not connected, cannot send message.");
    }
  }

  /// Disconnects manually from the WebSocket.
  void disconnect() {
    print("🛑 Manually closing WebSocket connection...");
    _manuallyClosed = true;
    _isConnected = false;
    _subscription?.cancel();
    _channel?.sink.close(status.normalClosure);
  }
}
