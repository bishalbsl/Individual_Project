import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:socket_io_client/socket_io_client.dart';

import 'environments.dart';

typedef void StreamStateCallback(Session? session, MediaStream stream);

class Session {
  // Session({required this.localId, required this.remoteId});
  // String localId;
  // String remoteId;
  RTCPeerConnection? pc;
  // RTCDataChannel dc;
  List<RTCIceCandidate> remoteCandidates = [];
}

class ConnectWebRTC {
  MediaStream? _localStream;
  Session? _session;
  Socket? _channel;
  StreamStateCallback? onAddRemoteStream;
  StreamStateCallback? onRemoveRemoteStream;

  // JsonEncoder _encoder = JsonEncoder();

  String get sdpSemantics =>
      WebRTC.platformIsWindows ? 'plan-b' : 'unified-plan';

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };

  // bool isInvite(String remoteId) {
  //   return _session?.remoteId == remoteId;
  // // }

  // void invite(String localId, String remoteId, MediaStream localStream,
  //     Socket channel,String roomName) async {
  void invite(MediaStream localStream, Socket channel, String roomName) async {
    _channel = channel;
    _localStream = localStream;
    // _session = await _createSession(localId: localId, remoteId: remoteId, roomName: roomName);
    _session = await _createSession(roomName: roomName);
    await _createOffer(roomName);
  }

  // void receiveOffer(String localId, String remoteId, MediaStream localStream,
  //     Socket channel, String sdp, String type, String roomName) async {
  void receiveOffer(MediaStream localStream, Socket channel, String sdp,
      String type, String roomName) async {
    print('inside receiveOffer');
    _channel = channel;
    _localStream = localStream;
    Session oldSession = _session!;
    // _session = await _createSession(localId: localId, remoteId: remoteId, roomName: roomName);
    _session = await _createSession(roomName: roomName);
    // print('sdp:$sdp');
    await _session!.pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
    await _createAnswer(roomName);

    if (oldSession != null) {
      if (oldSession.remoteCandidates.length > 0) {
        oldSession.remoteCandidates.forEach((candidate) async {
          await _session!.pc!.addCandidate(candidate);
        });
        oldSession.remoteCandidates.clear();
      }
    }
  }

  // void setCandidate(String localId, String remoteId, String candidate,
  //     String sdpMid, int sdpMLineIndex) async {
  void setCandidate(String candidate, String sdpMid, int sdpMLineIndex) async {
    RTCIceCandidate iceCandidate =
        RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);

    if (_session != null) {
      if (_session?.pc != null) {
        await _session!.pc?.addCandidate(iceCandidate);
      } else {
        _session?.remoteCandidates.add(iceCandidate);
      }
    } else {
      // _session = Session(localId: localId, remoteId: remoteId);
      _session = Session();
      _session = Session()..remoteCandidates.add(iceCandidate);
    }
  }

  void returnAnswer(String sdp, String type) async {
    await _session?.pc?.setRemoteDescription(RTCSessionDescription(sdp, type));
  }

  void disconnect(bool isByeReceive) async {
    // if (!isByeReceive) {
    //   Map message = {
    //     'remoteId': _session!.remoteId,
    //     'disconnect': {
    //       'localId': _session!.localId,
    //       'remoteId': _session!.remoteId
    //     }
    //   };
    //   print(message);
    //   // await _channel!.sink.add(_encoder.convert(message));
    // }
    _session?.pc?.close();
    // _session?.pc?.dispose();
    // _session?.pc == null;
  }

  // Future<Session> _createSession(
  //     {required String localId, required String remoteId, required String roomName}) async {
  Future<Session> _createSession({required String roomName}) async {
    // Session session = Session(localId: localId, remoteId: remoteId);
    Session session = Session();

    RTCPeerConnection pc = await createPeerConnection({
      ...Environments.IceServers,
      ...{'sdpSemantics': sdpSemantics}
    }, _config);
    switch (sdpSemantics) {
      case 'plan-b':
        pc.onAddStream = (MediaStream stream) {
          onAddRemoteStream?.call(session, stream);
        };
        await pc.addStream(_localStream!);
        break;
      case 'unified-plan':
        pc.onTrack = (event) {
          if (event.track.kind == 'video') {
            onAddRemoteStream?.call(session, event.streams[0]);
          }
        };
        _localStream!.getTracks().forEach((track) {
          pc.addTrack(track, _localStream!);
        });
        break;
    }

    pc.onIceCandidate = (candidate) {
      if (candidate == null) {
        print('onIceCandidate: complete!');
        return;
      }
      Map sendCandidate = {
        // 'remoteId': session.remoteId,
        // 'candidate': {
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'sdpMid': candidate.sdpMid,
        'candidate': candidate.candidate,
        // }
      };
      // print(sendCandidate);
      // _channel.sink.add(_encoder.convert(sendCandidate));
      _channel!.emit(
          "IceCandidate", {"roomId": roomName, "iceCandidate": sendCandidate});
    };

    pc.onIceConnectionState = (state) {};

    pc.onRemoveStream = (stream) {
      onRemoveRemoteStream?.call(session, stream);
    };

    session.pc = pc;
    return session;
  }

  Future<void> _createOffer(roomName) async {
    try {
      RTCSessionDescription s = await _session!.pc!.createOffer();
      await _session!.pc!.setLocalDescription(s);
      Map sendOffer = {
        // 'remoteId': _session!.remoteId,
        // 'offer': {
        'sdp': s.sdp, 'type': s.type
        // }
      };
      // final description = {'sdp': s.sdp, 'type': s.type};

      // print('inside create offfer: $sendOffer');
      // _channel.sink.add(_encoder.convert(sendOffer));
      _channel!.emit('makeCall', {"roomId": roomName, "sdpOffer": sendOffer});
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> _createAnswer(roomName) async {
    print('inside create answer');
    try {
      RTCSessionDescription s = await _session!.pc!.createAnswer();
      await _session!.pc!.setLocalDescription(s);
      Map sendAnswer = {
        // 'remoteId': _session!.remoteId,
        // 'answer': {
        'sdp': s.sdp, 'type': s.type
        // }
      };
      // final description = {'sdp': s.sdp, 'type': s.type};

      // print(sendAnswer);
      // _channel.sink.add(_encoder.convert(sendAnswer));
      _channel!.emit("answerCall", {
        "roomId": roomName,
        "sdpAnswer": sendAnswer,
      });
    } catch (e) {
      print(e.toString());
    }
  }
}
