import 'package:millicast_flutter_sdk/src/peer_connection.dart';
import 'package:millicast_flutter_sdk/src/signaling.dart';

import 'director.dart';
import 'utils/base_web_rtc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'logger.dart';

var _logger = getLogger('View');

const Map<String, dynamic> _connectOptions = {
  'disableVideo': false,
  'disableAudio': false,
  'peerConfig': null
};

/// [View] manages a webSocket connection to view a stream using Millicast.
///
/// [View] extends [BaseWebRTC] class.
/// Before you can view an active broadcast, you will need:
/// - A connection path that you can get from  [Director] module or from your
/// own implementation based on [Get a Connection Path](https://dash.millicast.com/docs.html?pg=how-to-broadcast-in-js#get-connection-paths-sect).
/// [streamName] - Millicast existing Stream Name where you want to connect.
/// [tokenGenerator] - Callback function executed when a new token is needed.
/// [mediaElement] - Target  media element to mount stream.
/// [autoReconnect] = true - Enable auto reconnect to stream.

class View extends BaseWebRTC {
  View(
      {required String streamName,
      required Function tokenGenerator,
      RTCVideoRenderer? mediaElement,
      bool autoReconnect = true})
      : super(
            streamName: streamName,
            tokenGenerator: tokenGenerator,
            autoReconnect: autoReconnect,
            logger: _logger) {
    if (mediaElement != null) {
      webRTCPeer.on(webRTCEvents['track'], this, (ev, context) {
        mediaElement.srcObject = ev.eventData as MediaStream?;
      });
    }
  }

  /// Connects to an active stream as subscriber.
  ///
  /// [Object] options - General subscriber options.
  //  ignore: lines_longer_than_80_chars
  /// [options] dtx = false - True to modify SDP for supporting dtx in opus. Otherwise False.
  //  ignore: lines_longer_than_80_chars
  /// [options] absCaptureTime = false - True to modify SDP for supporting absolute capture time header extension. Otherwise False.
  //  ignore: lines_longer_than_80_chars
  /// options disableVideo = false - Disable the opportunity to receive video stream.
  //  ignore: lines_longer_than_80_chars
  /// options disableAudio = false - Disable the opportunity to receive audio stream.
  //  ignore: lines_longer_than_80_chars
  /// options multiplexedAudioTracks - Number of audio tracks to recieve VAD multiplexed audio for secondary sources.
  //  ignore: lines_longer_than_80_chars
  /// options pinnedSourceId - Id of the main source that will be received by the default MediaStream.
  //  ignore: lines_longer_than_80_chars
  /// options excludedSourceIds - Do not receive media from the these source ids.
  //  ignore: lines_longer_than_80_chars
  /// options events - Override which events will be delivered by the server (any of "active" | "inactive" | "vad" | "layers").*
  //  ignore: lines_longer_than_80_chars
  /// options peerConfig     - Options to configure the new RTCPeerConnection.
  //  ignore: lines_longer_than_80_chars
  /// options layer - Select the simulcast encoding layer and svc layers for the main video track, leave empty for automatic layer selection based on bandwidth estimation.
  //  ignore: lines_longer_than_80_chars
  /// Returns Future object which resolves when the connection was successfully established.
  ///
  /// @example
  /// ```dart
  ///import 'package:flutter_webrtc/flutter_webrtc.dart';
  ///import 'package:millicast_flutter_sdk/millicast_flutter_sdk.dart';
  ///
  ///   ///Setting subscriber options
  /// DirectorSubscriberOptions directorSubscriberOptions =
  ///     DirectorSubscriberOptions(
  ///        streamAccountId: Constants.accountId,
  ///         streamName: Constants.streamName);

  /// /// Define callback for generate new token
  /// tokenGenerator() => Director.getSubscriber(directorSubscriberOptions);

  /// /// Create a new instance
  /// View view = View(
  ///     streamName: Constants.streamName,
  ///     tokenGenerator: tokenGenerator,
  ///     mediaElement: localRenderer);
  ///
  /// //Set track event handler to receive streams from Publisher.
  ///    view.webRTCPeer.on('track', this, (ev, context) {
  ///       _localRenderer.srcObject = ev.eventData as MediaStream?;
  // /  });

  /// /// Start connection to publisher
  /// try {
  ///   await view.connect();
  /// } catch (e) {
  ///   rethrow;
  /// }
  ///```
  @override
  connect({Map<String, dynamic> options = _connectOptions}) async {
    _logger.d('Viewer connect options values: $options');
    options = {..._connectOptions, ...options, 'setSDPToPeer': false};
    if (isActive()) {
      _logger.w('Viewer currently subscribed');
      throw Error();
    }
    MillicastDirectorResponse subscriberData;
    try {
      subscriberData = await tokenGenerator();
    } catch (e) {
      _logger.e('Error generating token.');
      throw Exception(e);
    }
    // ignore: unnecessary_null_comparison
    if (subscriberData == null) {
      _logger.e('Error while subscribing. Subscriber data required');
    }
    var signaling = Signaling({
      'streamName': streamName,
      'url': '${subscriberData.urls[0]}?token=${subscriberData.jwt}'
    });
    await webRTCPeer.createRTCPeer(options['peerConfig']);
    // reemit(webRTCPeer, this, [webRTCEvents['connectionStateChange']]);

    Future getLocalSDPFuture =
        webRTCPeer.getRTCLocalSDP(options: {'stereo': true});
    Future signalingConnectFuture = signaling.connect();

    Iterable<Future<dynamic>> iterFuture = [
      getLocalSDPFuture,
      signalingConnectFuture
    ];

    var resolvedFutures = await Future.wait(iterFuture);
    String localSdp = resolvedFutures[0];
    Future subscribeFuture = signaling.subscribe(localSdp);
    Future<void>? setLocalDescriptionFuture =
        webRTCPeer.peer?.setLocalDescription(webRTCPeer.sessionDescription!);
    iterFuture = [subscribeFuture, setLocalDescriptionFuture!];

    resolvedFutures = await Future.wait(iterFuture);
    String remoteSdp = resolvedFutures[0];

    await webRTCPeer.setRTCRemoteSDP(remoteSdp);
    _logger.i('setRemoteDescription Success! ');

    setReconnect();
    _logger.i('Connected to streamName: $streamName');
  }

  void select(Map? layer) async {}

  Future<RTCRtpTransceiver> addRemoteTrack(
      String media, List<MediaStream> streams) async {
    // ignore: null_argument_to_non_null_type
    return Future<RTCRtpTransceiver>.value();
  }

  void project(String sourceId, List<Object> mapping) async {}
  void unproject(List<String> mediaIds) async {}
}
