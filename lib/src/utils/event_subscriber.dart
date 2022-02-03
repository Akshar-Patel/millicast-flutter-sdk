import 'dart:async';
import 'dart:convert';

import 'package:eventify/eventify.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../logger.dart';

var _logger = getLogger('EventSubscriber');
const recordSeparator = '\x1E';

/// Initializes the web socket and subscribe Millicast Stream Event
///
/// ```dart
/// EventSubscriber eventSubscriber =
///     EventSubscriber({webSocketUrl});
/// await eventSubscriber.initializeHandshake();
/// eventSubscriber.subscribe(topicRequest);
///
class EventSubscriber extends EventEmitter {
  WebSocketChannel? webSocket;
  String eventsLocation;

  EventSubscriber(this.eventsLocation);

  /// Subscribe to Millicast Stream Event
  // ignore: lines_longer_than_80_chars
  /// [Object] topicRequest - Object that represents the event topic you want to subscribe.
  void subscribe(Object topicRequest) async {
    bool isHandshakeResponse = true;
    _logger.i('Subscribing to event topic');
    _logger.d('Topic request value: $topicRequest');
    topicRequest = jsonEncode(topicRequest) + recordSeparator;
    webSocket?.stream.listen((event) {
      _logger.i('The event is $event');
      if (isHandshakeResponse) {
        final parsedResponse = handleHandshakeResponse(event);
        _logger.i(
            // ignore: lines_longer_than_80_chars
            'Successful handshake with events WebSocket. Waiting for subscriptions...');
        _logger.d('WebSocket handshake message: ', parsedResponse);
        isHandshakeResponse = false;
      }

      List<String> responses = event.split(recordSeparator);
      _logger.i('Responses $responses');
      for (var response in responses) {
        if (response.isNotEmpty) {
          final responseParsed = parseSignalRMessage(response);
          _logger.i('Response parsed $responseParsed');
          emit('message', responseParsed);
        }
      }
    });

    webSocket?.sink.add(topicRequest);
  }

  /// Initializes the connection with the Millicast event WebSocket.
  /// Returns [Future] which represents the handshake finalization.
  initializeHandshake() async {
    if (webSocket == null) {
      _logger.i('Starting events WebSocket handshake.');
      webSocket = WebSocketChannel.connect(Uri.parse(eventsLocation));
      _logger.i('Connection established with events WebSocket.');
      final Map<String, dynamic> handshakeRequest = {
        'protocol': 'json',
        'version': 1
      };
      _logger.i(
          // ignore: lines_longer_than_80_chars
          'Sending handshakeRequest ${jsonEncode(handshakeRequest) + recordSeparator}');
      webSocket?.sink.add(jsonEncode(handshakeRequest) + recordSeparator);
    }
  }

  // ignore: lines_longer_than_80_chars
  /// Receives the event data response from the WebSocket and throw error if the response has an error.
  ///
  // ignore: lines_longer_than_80_chars
  /// [message] - WebSocket event data response from the handshake initialization.
  /// Returns incoming message into an [Object].
  String handleHandshakeResponse(String message) {
    String handshakeResponse = parseSignalRMessage(message);
    if (handshakeResponse.isEmpty) {
      _logger.e('There was an error with events WebSocket handshake: ',
          jsonDecode(handshakeResponse)['error']);
      throw Exception(jsonDecode(handshakeResponse)['error']);
    } else {
      return handshakeResponse;
    }
  }

  /// Parses incoming WebSocket event messages.
  String parseSignalRMessage(String message) {
    message = message.endsWith(recordSeparator)
        ? message.substring(0, message.length - 1)
        : message;
    return message;
  }

  /// Close WebSocket connection with Millicast stream events server.
  void close() {
    if (webSocket?.protocol != null) {
      webSocket?.sink.close();
      _logger.i('Events WebSocket closed');
    }
  }
}
