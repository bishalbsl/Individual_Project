import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:online_communication/webrtc_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:permission_handler/permission_handler.dart' as permission;
import 'package:device_info_plus/device_info_plus.dart';
import 'login_screen.dart';
import 'screen_capture.dart';

import 'environments.dart';
import 'webrtc_unit.dart';

// JsonEncoder _encoder = JsonEncoder();
// JsonDecoder _decoder = JsonDecoder();

int? loginUserNo = 1;
String _roomName = '';
List roomDataList = [];
String? dropdownValue, selectedRoomCd, loginKengenKbn;

class Room {
  final String roomId, roomName, roomCD;

  Room({required this.roomId, required this.roomName, required this.roomCD});

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      roomId: json['roomId'],
      roomName: json['roomName'],
      roomCD: json['roomCD'],
    );
  }
}

class Rooms {
  final List<Room> roomList;
  Rooms({required this.roomList});

  factory Rooms.fromJson(Map<String, dynamic> json) {
    var roomListJson = json['roomList'] as List;
    List<Room> rooms = roomListJson.map((roomJson) {
      return Room.fromJson(roomJson);
    }).toList();

    if (roomListJson.length == 1) {
      _roomName = roomListJson[0]['roomId'];
      dropdownValue = roomListJson[0]['roomId'];
    }
    roomDataList = rooms;
    return Rooms(roomList: rooms);
  }
}

class User {
  final int userNo;
  final String userName;

  User({
    required this.userNo,
    required this.userName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userNo: json['userNo'],
      userName: json['userName'],
    );
  }
}

// typedef void StreamStateCallback(Session session, MediaStream stream);

// class Session {
//   Session({required this.localId, required this.remoteId});
//   String localId;
//   String remoteId;
//   RTCPeerConnection? pc;
//   // RTCDataChannel dc;
//   List<RTCIceCandidate> remoteCandidates = [];
// }

class WebRTCStatus {
  // bool isUserName = false;
  bool isCall = false;
  bool isReceive = false;
  // String myId = '';
  // String myUserName = '';
}

class CallP2pMeshScreen extends StatefulWidget {
  const CallP2pMeshScreen(this.loginToken, {super.key, required this.title});

  final String title;
  final String loginToken;

  @override
  // ignore: library_private_types_in_public_api
  _CallP2pMeshScreenState createState() => _CallP2pMeshScreenState();
}

class _CallP2pMeshScreenState extends State<CallP2pMeshScreen>
    with WidgetsBindingObserver {
  // static final WebrtcState _initialState = WebrtcState();

  // _CallP2pMeshScreenState(this.) : super(_initialState);

  // signalling server url
  // final String websocketUrl = "http://10.100.9.7:5555";
  final String websocketUrl = "http://192.168.11.3:3500";

  // socket instance
  Socket? socket;

  ConnectWebRTC _connectWebRTC = ConnectWebRTC();
  WebRTCStatus _status = WebRTCStatus();
  List<dynamic> _users = [];
  StreamStateCallback? _onLocalStream;

  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  // Socket? _channel;

  // videoRenderer for localPeer
  RTCVideoRenderer _localRTCVideoRenderer = RTCVideoRenderer();
  // videoRenderer for remotePeer
  RTCVideoRenderer _remoteRTCVideoRenderer = RTCVideoRenderer();

  bool isConnected = false;

  // mediaStream for localPeer
  MediaStream? _localStream;

  // mediaStream for localPeer
  MediaStream? _remoteStream;

  // RTC peer connection
  RTCPeerConnection? peerConnection;

  // list of rtcCandidates to be sent over signalling
  List<RTCIceCandidate> remoteCandidates = [];

  List<MediaStream> _remoteStreams = <MediaStream>[];

  List<RTCRtpSender> _senders = <RTCRtpSender>[];

  // final WebrtcInteractor _interactor;

  // media status
  bool isAudioOn = true, isVideoOn = true, isFrontCameraSelected = true;

  static const String baseUrl =
      "https://10.100.9.7:6443/OnlineCommunicationAPI";
  // static const String baseUrl = "http://172.16.18.107/OnlineCommunicationAPI";
  // static const String baseUrl = "https://smartmedical-tm.jp/TELEMEDICINE_API";

  final GlobalKey _popupMenuKey = GlobalKey();

  int? myUserNo, tantoNo;
  String? machineId;

  // connection
  int? newConnectionNo, waitUserNo, secondUserNo;

  bool _endFlg = false, _disconnectUser = false, isLandscape = false;
  bool cameraMicGranted = false;

  bool _hasRemoteStream = false;
  bool _hideRemoteVideo = false;

  String _systemName = "", _googleMapConfig = '';

  // 接続ボタン
  bool isCallButtonEnabled = true;
  int callButtonState = 1;
  String callButtonText = '接続開始';
  Color callButtonBackgroundColor = const Color(0xFF00698D);
  //画面共有ボタン
  int shareScreenButtonState = 1;
  String shareScreenButtonText = '画面共有';
  Color screenShareBackgroundColor = const Color(0xFF00698D);

  late Future<Rooms> futureRooms;
  final List<User> userList = [];

  DateTime? startTime, examStartTime, examEndTime;

  //Google Mapボタン
  int mapButtonState = 1;
  String mapButtonText = 'マップ表示';
  Color mapButtonBackgroundColor = const Color(0xFF00698D);

  // Location
  final Location location = Location();
  late LocationData _locationData;
  late bool _serviceEnabled;
  late PermissionStatus _permissionGranted;
  double ownLat = 0;
  double ownLng = 0;
  StreamSubscription<LocationData>? locationSubscription;

  //Google Map
  late GoogleMapController mapController;
  late final Uint8List customMarker;
  double userLat = 0;
  double userLng = 0;

  CapturePeer? _peer;
  double versionNumber = 0, screenSizeWidth = 0;

  //Partner Info
  int? partnerUserNo, updateLogNo;
  String? partnerMachineId;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    //Androidのみ、アプリが前進するとローカルビデオを再開
    if (state == AppLifecycleState.resumed &&
        isConnected &&
        shareScreenButtonState != 2 &&
        WebRTC.platformIsAndroid) {
      resumeLocalStream();
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    init();

    _onLocalStream = ((_, stream) {
      setState(() {
        _localRenderer.srcObject = stream;
      });
    });
    // initRenderers1();
  }

  initRenderers1() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    _connectWebRTC.onAddRemoteStream = ((_, stream) {
      setState(() {
        _remoteRenderer.srcObject = stream;
      });
    });

    _connectWebRTC.onRemoveRemoteStream = ((_, stream) {
      setState(() {
        _remoteRenderer.srcObject = null;
      });
    });

    // _channel = socket;

    // _channel = io(websocketUrl, {
    //   "transports": ['websocket'],
    //   "auth": {"key": "kOvEFJ3pBzvj8="},
    //   'cors': {
    //     'origin': 'localhost',
    //     'credentials': true,
    //   },
    // });
    socket = io(
      Environments.WsServer, // websocketUrl,
      OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew() //close and reconnect
          .build(),
    );

    // listen onConnect event
    socket!.on('connect', (data) async {
      print('open socket:');
      //Make an initial call
      // if (mounted) startCall();

      // 接続開始時間
      startTime = DateTime.now();
      // await _checkLocationPermission();

      MediaStream stream = await _createStream();
      _onLocalStream?.call(null, stream);
      // _connectWebRTC.invite(_status.myId, id, stream, _channel!, _roomName);
      _connectWebRTC.invite(stream, socket!, _roomName);
      setState(() {
        _status.isCall = true;
      });
    });

    // create and join room
    socket!.emit("createRoom", {
      "roomId": _roomName,
    });

    socket!.on('newCall', (data) async {
      Map messageMap = data['sdpOffer'];
      // print('newCall data : $messageMap');
      //if (messageMap.containsKey('offer')) {
      MediaStream stream = await _createStream();
      _onLocalStream?.call(null, stream);
      // Map offer = messageMap['offer'];
      Map offer = messageMap;
      // _connectWebRTC.receiveOffer(_status.myId, messageMap['requestId'],
      //     stream, socket!, offer['sdp'], offer['type'], _roomName);
      print('inside newcall');

      _connectWebRTC.receiveOffer(
          stream, socket!, offer['sdp'], offer['type'], _roomName);
      setState(() {
        _status.isReceive = true;
      });
      //}
    });

    socket!.on('callAnswered', (data) async {
      Map messageMap = data['sdpAnswer'];
      //if (messageMap.containsKey('answer')) {
      // Map answer = messageMap['answer'];
      Map answer = messageMap;
      _connectWebRTC.returnAnswer(answer['sdp'], answer['type']);
      //}
    });

    socket!.on("IceCandidate", (data) async {
      Map messageMap = data['iceCandidate'];

      // var candidateMap = data['iceCandidate'];
      //if (messageMap.containsKey('candidate')) {
      // Map candidate = messageMap['iceCandidate'];
      Map candidate = messageMap;
      // print("GOT ICE candidate");
      // print('candidate: $candidate');
      _connectWebRTC.setCandidate(
          // _status.myId,
          // messageMap['requestId'],
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMLineIndex']);
      //}
    });

    socket!.on('receivedData', (data) {
      if (mounted) {
        _onDataReceived(data);
      }
    });

    // _channel!.on('leaveRoom',(data) async {
    //         print('inside disconnect user');

    //   _showCallLog();
    //   _resetState();
    //   _disconnect1(true);

    // });

    socket!.on('disconnectUser', (data) async {
      print('inside disconnect user');
      //if (messageMap.containsKey('disconnect')) {
      _disconnect1(true);
      _leaveRoom();
      // _channel!.emit('leaveRoom', {"roomId": _roomName});

      // _disconnect();
      // endFlgUpdate(widget.loginToken, selectedRoomCd!);
      _showCallLog();
      _resetState();
      //}
    });

    socket!.connect();
  }

  // @override
  // void dispose() {
  //   super.dispose();
  //   _localRenderer.srcObject = null;
  //   _remoteRenderer.srcObject = null;
  //   _localRenderer.dispose();
  //   _remoteRenderer.dispose();
  // }

  Future<MediaStream> _createStream() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': true,
      // {
      //   'mandatory': {
      //     'minWidth': '640',
      //     'minHeight': '480',
      //     'minFrameRate': '30',
      //   },
      //   ...WebRTC.platformIsDesktop ? {} : {'facingMode': 'user'},
      //   // 'optional': [],
      // }
    };

    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
    return stream;
  }

  void _onCall(id) async {
    await initRenderers1();

    // MediaStream stream = await _createStream();
    // _onLocalStream?.call(null, stream);
    // // _connectWebRTC.invite(_status.myId, id, stream, _channel!, _roomName);
    // _connectWebRTC.invite(stream, _channel!, _roomName);
    // setState(() {
    //   _status.isCall = true;
    // });
  }

  void _disconnect1(bool isByeReceive) async {
    // await _connectWebRTC.disconnect(isByeReceive);
    _connectWebRTC.disconnect(isByeReceive);
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    close();

    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    _localRenderer.initialize();
    _remoteRenderer.initialize();
    setState(() {
      _status.isCall = false;
      _status.isReceive = false;
    });
    _connectWebRTC = ConnectWebRTC();
  }

  close() {
    try {
      socket!.disconnect();
      socket!.close();
      socket!.destroy();
      socket = null;
      print('SOCKET DISCONNECTED');
    } catch (e) {
      print(e);
    }
  }

  init() async {
    _loadPrefs();
    futureRooms = fetchRoom(widget.loginToken);
    loadMyInfo(widget.loginToken);
    // _initCustomMarkerIcon();
    // _checkLocationPermission();
    if (WebRTC.platformIsAndroid) {
      _getDeviceInfo();
    }
  }

  initRenderers() async {
    // _localRTCVideoRenderer = RTCVideoRenderer();
    // _remoteRTCVideoRenderer = RTCVideoRenderer();
    await _localRTCVideoRenderer.initialize();
    await _remoteRTCVideoRenderer.initialize();
  }

  Future<void> _checkLocationPermission() async {
    // 位置情報をリクエストするには、常に位置情報サービスのステータスと許可ステータスを手動で確認する必要
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }
    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }
    _locationData = await location.getLocation();
    if (_hasRemoteStream && mounted) {
      setState(() {
        ownLat = _locationData.latitude!;
        ownLng = _locationData.longitude!;
        //if (_hasRemoteStream) {
        // 位置情報を送信する
        _sendRealTimeMapInfo();
        //}
      });
    }
    // Start listening to location changes and store the subscription
    locationSubscription =
        location.onLocationChanged.listen((LocationData currentLocation) {
      if (_hasRemoteStream && mounted) {
        setState(() {
          ownLat = currentLocation.latitude!;
          ownLng = currentLocation.longitude!;
          //if (_hasRemoteStream) {
          // 位置情報を送信する
          _sendRealTimeMapInfo();
          //}
        });
      }
    });
  }

  // Add a method to stop listening to location updates
  Future<void> stopListeningToLocation() async {
    await locationSubscription?.cancel();
  }

  void _getDeviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo info = await deviceInfo.androidInfo;
    versionNumber = double.parse(info.version.release);
  }

  void _sendRealTimeMapInfo() async {
    Map<String, dynamic> latLng = {
      "isRecievedMapData": true,
      "myUserNo": loginUserNo,
      "latLng": {"lat": ownLat, "lng": ownLng}
    };
    String jsonStringlatLng = jsonEncode(latLng);
    // debugPrint('send mapinfo:$jsonStringlatLng');
    if (socket != null) {
      socket!.emit('sendData', {
        "roomId": _roomName,
        "data": jsonStringlatLng,
      });
    }
  }

  Future<void> _initCustomMarkerIcon() async {
    customMarker = await getBytesFromAsset(
        path: "images/custom-marker-people.png", width: 100);
  }

  Future<Uint8List> getBytesFromAsset(
      {required String path, required int width}) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  // 相手のuserLat、userLng通りMapのpositionを更新
  Future<void> _updateCameraPosition() async {
    CameraPosition newPosition = CameraPosition(
      target: LatLng(userLat, userLng),
      zoom: 15,
    );
    mapController.animateCamera(CameraUpdate.newCameraPosition(newPosition));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 戻るのを防ぐ
        return false;
      },
      child: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            isLandscape = true;
          } else {
            isLandscape = false;
          }
          return Stack(
            children: [
              Scaffold(
                appBar: AppBar(
                  centerTitle: false,
                  title: Text(
                    _systemName,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  automaticallyImplyLeading: false,
                  actions: <Widget>[
                    if (isLandscape)
                      // 画面共有ボタン
                      if (_hasRemoteStream)
                        ElevatedButton(
                          onPressed: () {
                            changeScreenShareState();
                          },
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all(
                                screenShareBackgroundColor),
                          ),
                          child: Text(
                            shareScreenButtonText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    if (isLandscape)
                      // GoogleMapボタン
                      if (_hasRemoteStream && _googleMapConfig == '1')
                        ElevatedButton(
                          onPressed: () {
                            changeMapButtonState();
                          },
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all(
                                mapButtonBackgroundColor),
                          ),
                          child: Text(
                            mapButtonText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () {
                        onLogout();
                      },
                    ),
                  ],
                ),
                body: orientation == Orientation.portrait
                    ? buildPortraitLayout()
                    : buildLandscapeLayout(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildPortraitLayout() {
    final Size screenSz = MediaQuery.of(context).size;
    final double w = (screenSz.width - 8) / 2.0;
    final double h = w / 3.0 * 4.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      key: _popupMenuKey,
      children: [
        Row(
          children: [
            // Dropdown メニュー
            Expanded(
                flex: 2,
                child: Align(
                  // alignment: Alignment.topCenter,
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: 8.0), // Add the desired left padding
                    child: Column(
                      children: [
                        FutureBuilder<Rooms>(
                          future: futureRooms,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Column(
                                children: [
                                  DropdownButton<String>(
                                    value: dropdownValue,
                                    elevation: 8,
                                    style: const TextStyle(color: Colors.black),
                                    underline: Container(
                                      height: 2,
                                      color:
                                          const Color.fromARGB(255, 23, 22, 25),
                                    ),
                                    onChanged: (newValue) {
                                      setState(() {
                                        if (newValue != 'placeholder') {
                                          dropdownValue = newValue;
                                          _setRoomName(newValue!,
                                              snapshot.data!.roomList);
                                        }
                                      });
                                    },
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: 'placeholder',
                                        child: Text('ルームを選択'),
                                      ),
                                      ...snapshot.data!.roomList.map((room) {
                                        return DropdownMenuItem<String>(
                                          value: room.roomId,
                                          child: Text(room.roomName),
                                        );
                                      }),
                                    ],
                                    hint: dropdownValue == null
                                        ? const Text('ルームを選択',
                                            style:
                                                TextStyle(color: Colors.grey))
                                        : null,
                                  ),
                                ],
                              );
                            } else if (snapshot.hasError) {
                              return Text('${snapshot.error}');
                            }
                            return const CircularProgressIndicator(
                              strokeWidth: 1,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                )),
            // // Cameraボタン
            // if (isConnected)
            //   Expanded(
            //     flex: 1,
            //     child: IconButton(
            //       icon: const Icon(Icons.cameraswitch),
            //       onPressed: _switchCamera,
            //     ),
            //   ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Dropdown メニュー
              Expanded(
                  flex: 1,
                  child: Column(children: [
                    // FutureBuilder<Rooms>(
                    //   future: futureRooms,
                    //   builder: (context, snapshot) {
                    //     if (snapshot.hasData) {
                    //       return Column(
                    //         children: [
                    //           DropdownButton<String>(
                    //             value: dropdownValue,
                    //             elevation: 8,
                    //             style: const TextStyle(color: Colors.black),
                    //             underline: Container(
                    //               height: 2,
                    //               color: const Color.fromARGB(255, 23, 22, 25),
                    //             ),
                    //             onChanged: (newValue) {
                    //               setState(() {
                    //                 if (newValue != 'placeholder') {
                    //                   dropdownValue = newValue;
                    //                   _setRoomName(
                    //                       newValue!, snapshot.data!.roomList);
                    //                 }
                    //               });
                    //             },
                    //             items: [
                    //               const DropdownMenuItem<String>(
                    //                 value: 'placeholder',
                    //                 child: Text('ルームを選択'),
                    //               ),
                    //               ...snapshot.data!.roomList.map((room) {
                    //                 return DropdownMenuItem<String>(
                    //                   value: room.roomId,
                    //                   child: Text(room.roomName),
                    //                 );
                    //               }),
                    //             ],
                    //             hint: dropdownValue == null
                    //                 ? const Text('ルームを選択',
                    //                     style: TextStyle(color: Colors.grey))
                    //                 : null,
                    //           ),
                    //         ],
                    //       );
                    //     } else if (snapshot.hasError) {
                    //       return Text('${snapshot.error}');
                    //     }
                    //     return const CircularProgressIndicator(
                    //       strokeWidth: 1,
                    //     );
                    //   },
                    // ),
                    // GoogleMapボタン
                    if (_hasRemoteStream && _googleMapConfig == '1')
                      ElevatedButton(
                        onPressed: () {
                          changeMapButtonState();
                        },
                        style: ButtonStyle(
                          padding: MaterialStateProperty.all(
                              const EdgeInsets.all(4)),
                          backgroundColor: MaterialStateProperty.all(
                              mapButtonBackgroundColor),
                        ),
                        child: Text(
                          mapButtonText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ])),
              // ボタン
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    // Cameraボタン
                    if (isConnected)
                      IconButton(
                        icon: const Icon(Icons.cameraswitch),
                        onPressed: _switchCamera,
                      ),
                    // 接続ボタン
                    ElevatedButton(
                      onPressed: isCallButtonEnabled
                          ? () {
                              changeCallState();
                            }
                          : null,
                      style: ButtonStyle(
                        padding:
                            MaterialStateProperty.all(const EdgeInsets.all(4)),
                        backgroundColor: MaterialStateProperty.all(
                            callButtonBackgroundColor),
                      ),
                      child: Text(
                        callButtonText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // 画面共有ボタン
                    if (_hasRemoteStream)
                      ElevatedButton(
                        onPressed: () {
                          changeScreenShareState();
                        },
                        style: ButtonStyle(
                          padding: MaterialStateProperty.all(
                              const EdgeInsets.all(4)),
                          backgroundColor: MaterialStateProperty.all(
                              screenShareBackgroundColor),
                        ),
                        child: Text(
                          shareScreenButtonText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
              // ロカルvideo
              // if (isConnected)
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(4.0),
                  width: w * 0.6,
                  height: h * 0.6,
                  child: RTCVideoView(
                    _localRTCVideoRenderer,
                    // _localRenderer,
                    mirror: isFrontCameraSelected,
                    // objectFit:
                    //     RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              )
              // else
              //   Expanded(
              //     flex: 1,
              //     child: Container(),
              //   ),
            ],
          ),
        ),
        // Google map
        if (_hideRemoteVideo && _hasRemoteStream && _googleMapConfig == '1')
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(4.0),
              width: w * 1.95,
              height: h * 1.9,
              child: GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  mapController = controller;
                },
                initialCameraPosition: CameraPosition(
                  target: LatLng(userLat, userLng),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('userMarker'),
                    position: LatLng(ownLat, ownLng),
                    infoWindow: const InfoWindow(title: '現在位置'),
                  ),
                  Marker(
                      markerId: const MarkerId('customUserMarker'),
                      position: LatLng(userLat, userLng),
                      infoWindow: const InfoWindow(title: '相手の現在位置'),
                      icon: BitmapDescriptor.fromBytes(customMarker)),
                },
              ),
            ),
          )
        else
          // リモートVideo
          Expanded(
            flex: 1,
            child: RTCVideoView(
              _remoteRTCVideoRenderer,
              // _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
      ],
    );
  }

  Widget buildLandscapeLayout() {
    final Size screenSz = MediaQuery.of(context).size;
    screenSizeWidth = screenSz.width;

    final double w = (screenSz.width - 8) / 2.0;
    final double h = w / 3.0 * 4.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      key: _popupMenuKey,
      children: [
        Container(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // ボタン
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    FutureBuilder<Rooms>(
                      future: futureRooms,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Column(
                            children: [
                              DropdownButton<String>(
                                value: dropdownValue,
                                elevation: 8,
                                style: const TextStyle(color: Colors.black),
                                underline: Container(
                                  height: 2,
                                  color: const Color.fromARGB(255, 23, 22, 25),
                                ),
                                onChanged: (newValue) {
                                  setState(() {
                                    if (newValue != 'placeholder') {
                                      dropdownValue = newValue;
                                      _setRoomName(
                                          newValue!, snapshot.data!.roomList);
                                    }
                                  });
                                },
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: 'placeholder',
                                    child: Text('ルームを選択'),
                                  ),
                                  ...snapshot.data!.roomList.map((room) {
                                    return DropdownMenuItem<String>(
                                      value: room.roomId,
                                      child: Text(room.roomName),
                                    );
                                  }),
                                ],
                                hint: dropdownValue == null
                                    ? const Text('ルームを選択',
                                        style: TextStyle(color: Colors.grey))
                                    : null,
                              ),
                            ],
                          );
                        } else if (snapshot.hasError) {
                          return Text('${snapshot.error}');
                        }
                        return const CircularProgressIndicator(
                          strokeWidth: 1,
                        );
                      },
                    ),
                    // Cameraボタン
                    if (isConnected)
                      IconButton(
                        icon: const Icon(Icons.cameraswitch),
                        onPressed: _switchCamera,
                      ),
                    // 接続ボタン
                    ElevatedButton(
                      onPressed: isCallButtonEnabled
                          ? () {
                              changeCallState();
                            }
                          : null,
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(
                            callButtonBackgroundColor),
                      ),
                      child: Text(
                        callButtonText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // ロカルvideo
                    if (isConnected)
                      Container(
                        padding: const EdgeInsets.all(1.0),
                        width: w * 1.95,
                        // height: h * 0.23,
                        height: h * 0.23,
                        child: RTCVideoView(
                          _localRTCVideoRenderer,
                          // mirror: isFrontCameraSelected,
                          // objectFit:
                          //     RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      )
                    else
                      Container(),
                  ],
                ),
              ),
              // Google map
              if (_hideRemoteVideo &&
                  _hasRemoteStream &&
                  _googleMapConfig == '1')
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(1.0),
                    // width: w * 1.95,
                    // height: h * 0.48,
                    width: w * 1.95,
                    // height: screenSizeWidth < 600 ? h * 0.67 : h * 0.48,
                    height: screenSizeWidth < 600
                        ? h * 0.67
                        : (screenSizeWidth < 1000 ? h * 0.48 : h * 0.76),
                    child: GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        mapController = controller;
                      },
                      initialCameraPosition: CameraPosition(
                        target: LatLng(userLat, userLng),
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('userMarker'),
                          position: LatLng(ownLat, ownLng),
                          infoWindow: const InfoWindow(title: '現在位置'),
                        ),
                        Marker(
                            markerId: const MarkerId('customUserMarker'),
                            position: LatLng(userLat, userLng),
                            infoWindow: const InfoWindow(title: '相手の現在位置'),
                            icon: BitmapDescriptor.fromBytes(customMarker)),
                      },
                    ),
                  ),
                )
              else
                // リモートVideo
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(1.0),
                    width: w * 1.95,
                    // height: h * 0.48,
                    // height: screenSizeWidth < 600 ? h * 0.67 : h * 0.48,
                    height: screenSizeWidth < 600
                        ? h * 0.67
                        : (screenSizeWidth < 1000 ? h * 0.48 : h * 0.76),
                    child: RTCVideoView(
                      _remoteRTCVideoRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                )
            ],
          ),
        ),
      ],
    );
  }

//--------------------------------------------------------------------------------
  /// SharedPreferencesから前回の設定を読み込む
  void _loadPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    loginKengenKbn = prefs.getString('KENGEN') ?? '';
    loginUserNo = prefs.getInt('USERNO');
    _systemName = prefs.getString('SYSTEM-NAME') ?? '';
    _googleMapConfig = prefs.getString('MAP-CONFIG') ?? '';
    if (loginKengenKbn != '3') {
      fetchAndSetUsers(widget.loginToken);
    }
  }

  void _showCallLog() async {
    DateTime endTime = DateTime.now();
    Duration timeDifference = endTime.difference(startTime!);
    String hour = timeDifference.inHours.toString().padLeft(2, "0");
    String inMinutes = timeDifference.inMinutes.toString().padLeft(2, "0");
    String inSeconds = timeDifference.inSeconds.toString().padLeft(2, "0");
    String totalCallDuration = '$hour:$inMinutes:$inSeconds';
    //診療時間
    Duration timeDifferenceDiagnosis = examEndTime!.difference(examStartTime!);
    String diagnosisHour =
        timeDifferenceDiagnosis.inHours.toString().padLeft(2, "0");
    String diagnosisMinutes =
        timeDifferenceDiagnosis.inMinutes.toString().padLeft(2, "0");
    String diagnosisSeconds =
        timeDifferenceDiagnosis.inSeconds.toString().padLeft(2, "0");
    String totalDiagnosisDuration =
        '$diagnosisHour:$diagnosisMinutes:$diagnosisSeconds';

    String formattedStartTime =
        DateFormat('yyyy/MM/dd HH:mm:ss').format(startTime!);
    String formattedDiagnosisStartTime =
        DateFormat('yyyy/MM/dd HH:mm:ss').format(examStartTime!);
    String formattedDiagnosisEndTime =
        DateFormat('yyyy/MM/dd HH:mm:ss').format(examEndTime!);
    String formattedEndTime = DateFormat('yyyy/MM/dd HH:mm:ss').format(endTime);

    String message = "接続開始時刻：$formattedStartTime";
    message += "\n監査開始時刻： $formattedDiagnosisStartTime";
    message += "\n監査終了時刻： $formattedDiagnosisEndTime";
    message += "\n監査時間： $totalDiagnosisDuration";
    message += "\n接続終了時刻： $formattedEndTime";
    message += "\n通話時間： $totalCallDuration";

    if (partnerUserNo != null || partnerMachineId != null) {
      message += partnerUserNo != null
          ? ("\n対応端末ID：${partnerMachineId != "" ? partnerMachineId : "登録なし"}")
          : "";
    }
    // ログを追加
    // await messageLog(endTime, widget.loginToken);
    if (mounted) {
      setState(() {
        partnerUserNo = null;
        partnerMachineId = null;
        updateLogNo = null;
      });
    }
    // ignore: use_build_context_synchronously
    showCustomAlertDialog(context, '情報', message);
  }

  /// 必要なパーミッション(CAMERA, RECORD_AUDIO)を保持しているかを
  /// 確認し保持していない場合にはパーミッションを要求する
  Future<void> checkPermission() async {
    // Request permissions
    Map<permission.Permission, permission.PermissionStatus> statuses = await [
      permission.Permission.camera,
      permission.Permission.microphone,
    ].request();
    // Now, check the permission status and set the state accordingly.
    if (statuses[permission.Permission.camera]!.isGranted &&
        statuses[permission.Permission.microphone]!.isGranted) {
      if (mounted) {
        setState(() {
          cameraMicGranted = true;
        });
      }
    }
  }

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'}
    ]
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  final Map<String, dynamic> _displayMediaConstraints = {
    'audio': true,
    'video': {'deviceId': 'broadcast'},
  };

  Future<void> _connect() async {
    debugPrint("_connect:");
    // await checkPermission();
    // if (cameraMicGranted) {
    await initRenderers();
    // Connect the socket...
    try {
      // socket = io(websocketUrl, {
      //   "transports": ['websocket'],
      //   "auth": {"key": "kOvEFJ3pBzvj8="},
      //   'cors': {
      //     'origin': 'localhost',
      //     'credentials': true,
      //   },
      // });
      String authKey = Environments.authKey;
      socket = io(
        Environments.WsServer, // websocketUrl,
        OptionBuilder()
            .setTransports(['websocket'])
            .enableForceNew() //close and reconnect
            .setQuery({
              "auth": "key=$authKey"
            }) // include authentication key in the query
            .build(),
      );

      // listen onConnect event
      socket!.on('connect', (data) async {
        print('open socket:');
        //Make an initial call
        if (mounted) startCall();

        // 接続開始時間
        startTime = DateTime.now();
        await _checkLocationPermission();
      });

      // listen for offer call from user
      socket!.on('newCall', (data) async {
        var description = data['sdpOffer'];
        var pc = await _createPeerConnection();
        peerConnection = pc;
        if (description != null) {
          await pc.setRemoteDescription(
              RTCSessionDescription(description['sdp'], description['type']));
        }
        await _createAnswer(pc);
        if (remoteCandidates.length > 0) {
          remoteCandidates.forEach((candidate) async {
            await pc.addCandidate(candidate);
          });
          remoteCandidates.clear();
        }
      });

      // listen for Remote IceCandidate
      socket!.on("IceCandidate", (data) async {
        print("GOT ICE candidate");
        var candidateMap = data['iceCandidate'];
        if (candidateMap != null) {
          var pc = peerConnection;
          RTCIceCandidate candidate = RTCIceCandidate(candidateMap['candidate'],
              candidateMap['sdpMid'], candidateMap['sdpMLineIndex']);
          if (pc != null) {
            await pc.addCandidate(candidate);
          } else {
            remoteCandidates.add(candidate);
          }
        }
      });

      // Listen for call answer
      socket!.on("callAnswered", (data) async {
        print('callAnswered');
        var description = data['sdpAnswer'];
        var pc = peerConnection;
        if (description != null) {
          await pc?.setRemoteDescription(
              RTCSessionDescription(description['sdp'], description['type']));
        }
      });

      socket!.on('receivedData', (data) {
        _onDataReceived(data);
      });

      // ルームユーザーの接続を解除している時
      socket!.on('disconnectUser', (data) async {
        print('inside disconnectUser');
        if (!_disconnectUser) {
          _leaveRoom();
          _disconnect();
          // endFlgUpdate(widget.loginToken, selectedRoomCd!);
          _showCallLog();
          _resetState();
        }
        _disconnectUser = true;
      });

      socket!.connect();

      // create and join room
      socket!.emit("createRoom", {
        "roomId": _roomName,
      });

      socket!.on('error', (data) async {
        print('error$data');
        if ('error$data' == 'error{message: Invalid key}') {
          // endFlgUpdate(widget.loginToken, selectedRoomCd!);
          _resetState();
          showCustomAlertDialog(context, 'エラー', '認証キーが一致しません。');
          socket!.close();
        }
      });
    } catch (e) {
      print('socket_error: $e');
    }
    // } else {
    //   setState(() {
    //     callButtonBackgroundColor = const Color(0xFF00698D);
    //     callButtonText = '接続開始';
    //     callButtonState = 1;
    //   });
    //   // endFlgUpdate(widget.loginToken, selectedRoomCd!);
    //   // ignore: use_build_context_synchronously
    //   showCustomAlertDialog(
    //       context, 'エラー', 'カメラ・マイクアクセスが禁止されています。カメラ・マイクを許可してください。');
    // }
  }

  startCall() async {
    if (socket != null) {
      await _createPeerConnection().then((pc) {
        setState(() {
          isConnected = true;
          peerConnection = pc;
        });
        _createOffer(pc);
      });
    }
  }

  _createOffer(RTCPeerConnection pc) async {
    try {
      RTCSessionDescription s = await pc.createOffer(_constraints);
      pc.setLocalDescription(s);

      final description = {'sdp': s.sdp, 'type': s.type};
      socket!.emit('makeCall', {"roomId": _roomName, "sdpOffer": description});
    } catch (e) {
      print(e.toString());
    }
  }

  _createAnswer(RTCPeerConnection pc) async {
    try {
      RTCSessionDescription s = await pc.createAnswer(_constraints);
      pc.setLocalDescription(s);

      final description = {'sdp': s.sdp, 'type': s.type};
      // send SDP answer to remote peer over signalling
      socket!.emit("answerCall", {
        "roomId": _roomName,
        "sdpAnswer": description,
      });
    } catch (e) {
      print(e.toString());
    }
  }

  Future<MediaStream> createStream() async {
    // final Map<String, dynamic> mediaConstraints = {
    //   'audio': true,
    //   'video': isVideoOn
    //       ? {
    //           'facingMode': isFrontCameraSelected ? 'user' : 'environment',
    //           'mandatory': {
    //             'minWidth':
    //                 '640', // Provide your own width, height and frame rate here
    //             'minHeight': '480',
    //             'minFrameRate': '30',
    //           },
    //           'optional': [],
    //         }
    //       : false,
    // };
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': true
    };

    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);

    if (stream != null) {
      setState(() {
        _localRTCVideoRenderer.srcObject = stream;
      });
    }
    return stream;
  }

  _createPeerConnection() async {
    RTCPeerConnection? pc = await createPeerConnection(_iceServers, _config);

    _localStream = await createStream();
    //スピーカーフォンをオンにする
    if (WebRTC.platformIsMobile)
      _localStream!.getAudioTracks()[0].enableSpeakerphone(true);

    // pc.addStream(_localStream!);  //problem in mobile
    _localStream!.getTracks().forEach((track) async {
      _senders.add(await pc.addTrack(track, _localStream!));
    });

    pc.onConnectionState = (RTCPeerConnectionState state) {
      // if (pc!.connectionState == 'connected') {
      //   // The peers are connected!
      //   print('The peers are connected! ');
      // }
      // print('onConnectionState: $state');
      print('this offer Connection state change: $state');
    };

    pc.onIceConnectionState = (state) {
      print('onIceConnectionState $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateClosed ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        stopCall();
        _leaveRoom();
        _disconnect();
        endFlgUpdate(widget.loginToken, selectedRoomCd!);
        // _showCallLog();
        _resetState();
      }
    };

    pc.onAddStream = (stream) async {
      print('onAddRemoteStream');
      // if (_remoteStream == null && mounted) {
      _remoteStream = stream;
      // _remoteStreams.add(stream);
      setState(() {
        _remoteRTCVideoRenderer.srcObject = _remoteStream;
        _hasRemoteStream = true;
      });
      _sendPartnerInfo();
      // }
    };

    pc.onTrack = (event) {
      event.streams[0]
          .getTracks()
          .forEach((track) => _remoteStream?.addTrack(track));
    };

    pc.onIceCandidate = (candidate) async {
      if (candidate.candidate != null) {
        var iceCandidate = {
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
          'candidate': candidate.candidate,
        };
        // print('iceCandidate$iceCandidate');
        await Future.delayed(
            const Duration(seconds: 2),
            () => socket!.emit("IceCandidate",
                {"roomId": _roomName, "iceCandidate": iceCandidate}));

        // This delay is needed to allow enough time to try an ICE candidate
        // before skipping to the next one. 1 second is just an heuristic value
        // and should be thoroughly tested in your own environment.

        // if (socket != null) {
        //   socket!.emit("IceCandidate",
        //       {"roomId": _roomName, "iceCandidate": iceCandidate});
        // }
      }
    };

    // _createOffer(pc);

    // pc.onRemoveStream = (stream) {
    //   print('remoteStream...$_remoteStreams');
    //   setState(() {
    //     _remoteRTCVideoRenderer.srcObject = null;
    //     _hasRemoteStream = false;
    //     pc = null;
    //   });
    //   // _showCallLog();
    //   _remoteStreams.removeWhere((it) {
    //     return (it.id == stream.id);
    //   });
    // };

    return pc;
  }

  Future<void> _disconnect() async {
    debugPrint("_disconnect:");
    stopCall();
  }

  stopCall() async {
    if (peerConnection != null) {
      peerConnection!.close();
      peerConnection = null;
    }
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) async {
        await track.stop();
      });
      await _localStream!.dispose();
      _localStream = null;
    }
    _senders.clear();

    if (_remoteStream != null) {
      _remoteStream!.getTracks().forEach((track) async {
        await track.stop();
      });
      await _remoteStream!.dispose();
      _remoteStream = null;
    }
    _remoteStreams.clear();
    remoteCandidates.clear();

    _localRTCVideoRenderer.srcObject = null;
    _remoteRTCVideoRenderer.srcObject = null;
    _localRTCVideoRenderer.dispose();
    _remoteRTCVideoRenderer.dispose();

    close();

    _localRTCVideoRenderer = RTCVideoRenderer();
    _remoteRTCVideoRenderer = RTCVideoRenderer();
    _localRTCVideoRenderer.initialize();
    _remoteRTCVideoRenderer.initialize();

    setState(() {
      isConnected = false;
      _hasRemoteStream = false;
    });
    await stopListeningToLocation();
  }

  // call when the widget is removed, release resources
  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _localStream?.dispose();
    peerConnection?.dispose();

    _localRTCVideoRenderer.srcObject = null;
    _remoteRTCVideoRenderer.srcObject = null;
    _localRTCVideoRenderer.dispose();
    _remoteRTCVideoRenderer.dispose();
  }

  // @override
  // void didUpdateWidget(CallP2pMeshScreen oldWidget) {
  //   super.didUpdateWidget(oldWidget);
  // }

  // cleanup before widget is remove
  // @override
  // deactivate() {
  //   super.deactivate();
  //   socket?.close();
  //   _localRTCVideoRenderer.dispose();
  //   _remoteRTCVideoRenderer.dispose();
  // }

  //  prevent the setState() called after dispose()
  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  // 最初の状況に戻る
  void _resetState() {
    setState(() {
      callButtonBackgroundColor = const Color(0xFF00698D);
      callButtonText = '接続開始';
      callButtonState = 1;
      shareScreenButtonText = '画面共有';
      screenShareBackgroundColor = const Color(0xFF00698D);
      shareScreenButtonState = 1;
      mapButtonState = 1;
      mapButtonText = 'マップ表示';
      mapButtonBackgroundColor = const Color(0xFF00698D);
      _hasRemoteStream = false;
      _hideRemoteVideo = false;
    });
  }

  // キャメラ切り替え
  void _switchCamera() async {
    if (_localStream != null) {
      // ignore: deprecated_member_use
      _localStream!.getVideoTracks()[0].switchCamera();
      isFrontCameraSelected = !isFrontCameraSelected;
    }
  }

  void resumeLocalStream() async {
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _localStream = await createStream();
    // ignore: avoid_function_literals_in_foreach_calls
    _senders.forEach((sender) {
      if (sender.track!.kind == 'video') {
        sender.replaceTrack(_localStream!.getVideoTracks()[0]);
      }
    });
  }

  // [OK]ボタンがあるAlertダイアログ
  void showCustomAlertDialog(
      BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            // Make the content scrollable
            child: Text(message),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                _disconnectUser = false;
                // // ignore: use_build_context_synchronously
                // Navigator.pushReplacement(
                //   context,
                //   MaterialPageRoute(
                //       builder: (context) =>
                //           CallP2pMeshScreen(loginToken, title: _systemName)),
                // );
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    ).then((value) {
      _disconnectUser = false;
      // // ignore: use_build_context_synchronously
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(
      //       builder: (context) =>
      //           CallP2pMeshScreen(loginToken, title: _systemName)),
      // );
    });
  }

  // [OK、Cancel]ボタンがあるAlertダイアログ
  void showCancelAlertDialog(
      BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // 外部からの盗聴で解雇を阻止
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                setState(() {
                  _resetState();
                  _leaveRoom();
                  _disconnect();
                  // endFlgUpdate(widget.loginToken, selectedRoomCd!);
                  Navigator.of(context).pop();
                  _showCallLog();
                });
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  callButtonBackgroundColor = Colors.red;
                  callButtonText = '接続終了';
                  callButtonState = 4;
                  Navigator.of(context).pop();
                });
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // [Logout]ボタンAlertダイアログ
  void showLogoutAlertDialog(
      BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                // Handle the "OK" button click as before
                _leaveRoom();
                _disconnect();
                // endFlgUpdate(widget.loginToken, selectedRoomCd!);
                Navigator.of(context).pop();
                SharedPreferences pref = await SharedPreferences.getInstance();
                pref.remove('TOKEN');
                pref.remove('KENGEN');
                dropdownValue = null;
                // ignore: use_build_context_synchronously
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SelectorScreen(),
                  ),
                );
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    ).then((value) {
      setState(() {
        //「OK」をクリックせずにダイアログが閉じられると
      });
    });
  }

  // 選択したルームを設定
  Future<void> _setRoomName(String roomName, roomList) async {
    for (var room in roomList) {
      if (room.roomId == roomName) {
        selectedRoomCd = room.roomCD;
        break;
      }
    }
    setState(() {
      _roomName = roomName;
    });
  }

  Future<void> _leaveRoom() async {
    debugPrint("_leaveRoom:");
    if (socket != null) {
      socket!.emit('leaveRoom', {"roomId": _roomName});
    }
  }

  void _onDataReceived(data) async {
    // print('receivedData $data');

    // JSON Stringを解析してマップに変換する
    Map<String, dynamic> obj = json.decode(data['data']);

    if (obj['startExam'] != null) {
      setState(() {
        callButtonBackgroundColor = const Color(0xFF6c757d);
        callButtonText = '監査終了';
        callButtonState = 3;
        examStartTime = DateTime.now();
      });
    } else if (obj['endExam'] != null) {
      setState(() {
        isCallButtonEnabled = true;
        callButtonBackgroundColor = Colors.red;
        callButtonText = '接続終了';
        callButtonState = 4;
        examEndTime = DateTime.now();
      });
    } else if (obj['latLng'] != null) {
      // debugPrint('latLng mapData: $data');
      setState(() {
        userLat = obj['latLng']['lat'];
        userLng = obj['latLng']['lng'];
      });
      // マップ作成後に初期化する
      if (mapButtonState == 2) {
        await _updateCameraPosition();
      }
    } else if (obj['sendPartnerInfo'] != null) {
      debugPrint('sendPartnerInfo: $data');
      setState(() {
        partnerUserNo = obj['userData']['userNo'];
        partnerMachineId = obj['userData']['machineId'];
      });
    }
  }

//--------------------------------CALL API-----------------------------------------------
  // 使用可能なルームのリストを取得
  Future<Rooms> fetchRoom(String loginToken) async {
    Map<String, String> headers = {
      "Content-Type": "application/json",
      'Accept': 'application/json',
      "Authorization": "Bearer $loginToken"
    };
    // var response = await http.get(Uri.parse("$baseUrl/Room/CanUseList/"),
    //     headers: headers);
    List<Map<String, dynamic>> roomList = [
      {
        'roomCD': 'room1',
        'roomId': '001',
        'roomName': 'roomOne',
      }
    ];

    // Create the body map with the roomList
    Map<String, dynamic> body = {'roomList': roomList};

    // Convert the Dart Map to JSON format
    var response = jsonEncode(body);

    // if (response.statusCode == 200) {
    if (response != null) {
      var decodedData = jsonDecode(response);
      if (loginKengenKbn == '3') {
        selectedRoomCd = decodedData['roomList'][0]['roomCD'];
        getRoomConnectionStatus(widget.loginToken, selectedRoomCd!);
      } else {
        if (decodedData['roomList'].length == 1) {
          selectedRoomCd = decodedData['roomList'][0]['roomCD'];
        } else {
          loadMyRoom(loginToken);
        }
      }
      return Rooms.fromJson(decodedData);
    } else {
      // then throw an exception.
      throw Exception('Failed to load Rooms');
    }
  }

  // 自分のルームを取得
  Future<void> loadMyRoom(String loginToken) async {
    Map<String, String> headers = {
      "Content-Type": "application/json",
      'Accept': 'application/json',
      "Authorization": "Bearer $loginToken"
    };

    var response =
        await http.get(Uri.parse("$baseUrl/User/MyRoomNo/"), headers: headers);
    if (response.statusCode == 200) {
      debugPrint('My Room No : $response.body');
      var decodedData = jsonDecode(response.body);
      selectedRoomCd = decodedData['myRoomNo'];
      for (var room in roomDataList) {
        if (room.roomCD == selectedRoomCd) {
          dropdownValue = room.roomId;
          setState(() {
            _roomName = room.roomId;
          });
          break;
        }
      }
    } else {
      debugPrint('Failed to loadMyRoom');
    }
  }

  // ルーム作成・接続を作成
  Future<void> createConnection(
      String loginToken, String roomNo, int waitUser) async {
    // final response = await http.post(
    //   Uri.parse("$baseUrl/Room/CreateConnection"),
    //   headers: <String, String>{
    //     'Content-Type': 'application/json',
    //     'Authorization': 'Bearer $loginToken',
    //   },
    //   body: jsonEncode(<String, dynamic>{
    //     'roomNo': roomNo,
    //     'waitUserNo': waitUser,
    //   }),
    // );
    // if (response.statusCode == 200) {
    // if (response.statusCode == 200) {
    List<Map<String, dynamic>> userList = [
      {
        'userName': 'admin',
        'userNo': 1,
        'delFlg': false,
      },
      {
        'userName': 'user',
        'userNo': 2,
        'delFlg': false,
      }
    ];

    // Create the body map with the userList
    Map<String, dynamic> body = {'userList': userList};

    // Convert the Dart Map to JSON format
    var response = jsonEncode(body);
    if (response != null) {
      // debugPrint("sucess: $response");
      setState(() {
        newConnectionNo = newConnectionNo! + 1;
      });
      // ルーム作成後に接続する
      _connect();
      // _onCall(1);
    } else {
      debugPrint('createConnection failed');
    }
  }

  // 自分の情報を取得
  Future<void> loadMyInfo(String loginToken) async {
    Map<String, String> headers = {
      "Content-Type": "application/json",
      'Accept': 'application/json',
      "Authorization": "Bearer $loginToken"
    };
    // var response =
    //     await http.get(Uri.parse('$baseUrl/User/MyInfo/'), headers: headers);
    // if (response.statusCode == 200) {
    //   var list = response.body;
    //   debugPrint('loadMyInfo: $list');
    //   var decodedData = jsonDecode(response.body);
    //   setState(() {
    //     myUserNo = decodedData['userNo'];
    //     machineId = decodedData['machineId'];
    //     tantoNo = decodedData['tantoNo'];
    //   });
    // } else {
    //   debugPrint('loadMyInfo failed');
    // }
    setState(() {
      myUserNo = 1;
      machineId = 'machine1';
      tantoNo = 11;
    });
  }

  // 接続したいルームの状況を取得
  Future<void> getRoomConnectionStatus(String loginToken, String roomNo) async {
    Map<String, String> headers = {
      "Content-Type": "application/json",
      'Accept': 'application/json',
      "Authorization": "Bearer $loginToken"
    };
    // var response = await http.get(
    //     Uri.parse('$baseUrl/Room/SetRoomConnection?roomNo=$roomNo'),
    //     headers: headers);
    // if (response.statusCode == 200) {
    var response = {};
    if (response != null) {
      // var list = response.body;
      // debugPrint(list);
      // var decodedData = jsonDecode(response.body);
      // setState(() {
      //   newConnectionNo = decodedData['roomList'][0]['connectionNo'];
      //   waitUserNo = decodedData['roomList'][0]['waitUserNo'];
      //   secondUserNo = decodedData['roomList'][0]['secondUserNo'];
      //   _endFlg = decodedData['roomList'][0]['endFlg'];
      // });
      setState(() {
        newConnectionNo = 1;
        waitUserNo = 1;
        secondUserNo = null;
        _endFlg = false;
      });

      if (loginKengenKbn == '3') {
        if (_endFlg == true) {
          // ignore: use_build_context_synchronously
          showCustomAlertDialog(
              context, '情報', 'このルームは現在使用できません。医師からの連絡をお待ちください。');
        } else if (secondUserNo != null) {
          // ignore: use_build_context_synchronously
          showCustomAlertDialog(
              context, 'エラー', 'すでに二人がこのルームを利用しています。別のルームを選択するか、担当者に連絡してください。');
        } else {
          // 接続状況を更新
          // connectionUpdate(widget.loginToken, selectedRoomCd!, loginUserNo!);
          _connect();
          // _onCall(1);
          setState(() {
            isCallButtonEnabled = false;
            callButtonBackgroundColor = const Color(0xFF28a745);
            callButtonText = '監査開始';
            callButtonState = 2;
          });
        }
      } else {
        if (_endFlg == false) {
          if (loginUserNo == waitUserNo) {
            callCreateConnection(waitUserNo);
            setState(() {
              callButtonBackgroundColor = const Color(0xFF28a745);
              callButtonText = '監査開始';
              callButtonState = 2;
            });
          } else {
            // ignore: use_build_context_synchronously
            showCustomAlertDialog(context, 'エラー', '現在このルームは使用しています。');
          }
        } else {
          if (dropdownValue == null) {
            // ignore: use_build_context_synchronously
            showCustomAlertDialog(context, 'エラー', 'ルームを選択してください。');
          } else {
            if (userList.isNotEmpty) {
              showButtonMenu();
            }
          }
        }
      }
    } else {
      debugPrint('getRoomConnectionStatus failed');
    }
  }

  // 接続を閉じる時endFlgはFalse更新
  Future<void> connectionUpdate(
      String loginToken, String roomCd, int userId) async {
    final response = await http.post(
      Uri.parse("$baseUrl/Room/ConnectionSecondUserUpdate"),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $loginToken',
      },
      body: jsonEncode(<dynamic, dynamic>{
        'connectionNo': newConnectionNo,
        'roomNo': roomCd,
        'secondUserNo': userId,
        'endFlg': false,
      }),
    );

    if (response.statusCode == 200) {
      debugPrint('connectionUpdate sucess: $response');
    } else {
      debugPrint('getRoomConnectionStatus failed');
    }
  }

  // データベースのconnectionテーブルの完了フラグを更新する
  Future<void> endFlgUpdate(String loginToken, String roomCd) async {
    final response = await http.post(
      Uri.parse("$baseUrl/Room/ConnectionEndFlgUpdate"),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $loginToken',
      },
      body: jsonEncode(<dynamic, dynamic>{
        'connectionNo': newConnectionNo,
        'roomNo': roomCd,
        'endFlg': true,
      }),
    );
    if (response.statusCode == 200) {
      debugPrint("endFlgUpdate: true");
    } else {
      debugPrint("failed to endFlgUpdate");
    }
  }

  // ユーザーのリストを取得する
  Future<List<User>> fetchUsers(String loginToken) async {
    Map<String, String> headers = {
      "Content-Type": "application/json",
      'Accept': 'application/json',
      "Authorization": "Bearer $loginToken"
    };
    // var response =
    //     await http.get(Uri.parse('$baseUrl/User/List/'), headers: headers);

    // if (response.statusCode == 200) {
    List<Map<String, dynamic>> userList = [
      {
        'userName': 'admin',
        'userNo': 1,
        'delFlg': false,
      },
      {
        'userName': 'user',
        'userNo': 2,
        'delFlg': false,
      }
    ];

    // Create the body map with the userList
    Map<String, dynamic> body = {'userList': userList};

    // Convert the Dart Map to JSON format
    var response = jsonEncode(body);
    if (response != null) {
      var decodedData = json.decode(response);
      final List<dynamic> data = decodedData['userList'];
      // delFlg・loginUserNo を使用してユーザーをfilterする
      final List<User> users = data
          .where((userJson) =>
              userJson['delFlg'] == false && userJson['userNo'] != loginUserNo)
          .map((userJson) => User.fromJson(userJson))
          .toList();
      return users;
    } else {
      throw Exception('Failed to load users');
    }
  }

  // ログを追加
  Future<void> messageLog(DateTime endTime, String loginToken) async {
    // DateTime UTC タイムゾーンに変換
    DateTime examStartTimeInUtc = examStartTime!.toUtc();
    DateTime examEndTimeInUtc = examEndTime!.toUtc();
    DateTime startTimeInUtc = startTime!.toUtc();
    DateTime endTimeInUtc = endTime.toUtc();

    final response = await http.post(
      Uri.parse("$baseUrl/User/MeLog"),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $loginToken',
      },
      body: jsonEncode(<String, dynamic>{
        'logNo': updateLogNo,
        'partnerUserNo': partnerUserNo,
        'examinationStartTime':
            DateFormat('yyyy-MM-ddTHH:mm:ss').format(examStartTimeInUtc),
        'examinationEndTime':
            DateFormat('yyyy-MM-ddTHH:mm:ss').format(examEndTimeInUtc),
        'startTime': DateFormat('yyyy-MM-ddTHH:mm:ss').format(startTimeInUtc),
        'endTime': DateFormat('yyyy-MM-ddTHH:mm:ss').format(endTimeInUtc),
      }),
    );
    if (response.statusCode == 200) {
      debugPrint("sucess: $response");
      var decodedData = json.decode(response.body);
      setState(() {
        updateLogNo = decodedData['logNo'];
      });
    } else {
      debugPrint('messageLog save failed');
    }
  }

  // ユーザーをリストに追加
  Future<void> fetchAndSetUsers(String loginToken) async {
    try {
      final users = await fetchUsers(loginToken);
      setState(() {
        userList.clear();
        userList.addAll(users);
      });
    } catch (error) {
      debugPrint('Error fetching users: $error');
    }
  }

//--------------------------------------------------------------------------------
  // 接続ボタンの状態
  void changeCallState() async {
    switch (callButtonState) {
      case 1:
        await getRoomConnectionStatus(widget.loginToken, selectedRoomCd!);
        break;
      case 2:
        setState(() {
          callButtonBackgroundColor = const Color(0xFF6c757d);
          callButtonText = '監査終了';
          callButtonState = 3;
        });
        _examStart();
        break;
      case 3:
        setState(() {
          callButtonBackgroundColor = Colors.red;
          callButtonText = '接続終了';
          callButtonState = 4;
        });
        _examEnd();
        break;
      case 4:
        _endCall();
        break;
    }
  }

  // マップボタンの状態
  void changeMapButtonState() {
    setState(() {
      switch (mapButtonState) {
        case 1:
          _hideRemoteVideo = true;
          mapButtonBackgroundColor = Colors.red;
          mapButtonText = 'マップ非表示';
          mapButtonState = 2;
          break;
        case 2:
          _hideRemoteVideo = false;
          mapButtonBackgroundColor = const Color(0xFF00698D);
          mapButtonText = 'マップ表示';
          mapButtonState = 1;
          break;
        default:
          break;
      }
    });
  }

  // 画面共有ボタンの状態
  void changeScreenShareState() {
    setState(() {
      switch (shareScreenButtonState) {
        case 1:
          _startScreenShare();
          screenShareBackgroundColor = Colors.red;
          shareScreenButtonText = '画面共有停止';
          shareScreenButtonState = 2;
          break;
        case 2:
          _stopScreenShare();
          screenShareBackgroundColor = const Color(0xFF00698D);
          shareScreenButtonText = '画面共有';
          shareScreenButtonState = 1;
          break;
        default:
          break;
      }
    });
  }

  void _onCaputureEvent(CaptureEvent event, Map<dynamic, dynamic> args) {}

  void _startScreenShare() async {
    if (!isFrontCameraSelected) {
      _switchCamera();
    }

    if (WebRTC.platformIsAndroid && versionNumber >= 10) {
      try {
        await CapturePeer.startForegroundService(_onCaputureEvent)
            .then((pc) async {
          _peer = pc;
          // Foreground サービスを開始ために2秒待つ
          Future.delayed(const Duration(seconds: 2), () async {
            debugPrint('_startScreenShare  function called.');
            bool isStartCapture = await _peer!.startCaptureStream();
            if (isStartCapture) {
              // Stop existing tracks in _localStream
              _localStream?.getTracks().forEach((track) {
                track.stop();
              });
              try {
                _localStream = await navigator.mediaDevices
                    .getDisplayMedia(_displayMediaConstraints);
              } catch (e) {
                print('erro $e');
                _stopScreenShare();
                setState(() {
                  screenShareBackgroundColor = const Color(0xFF00698D);
                  shareScreenButtonText = '画面共有';
                  shareScreenButtonState = 1;
                });
                // ignore: use_build_context_synchronously
                showCustomAlertDialog(context, 'エラー', 'コンテンツのキャプチャーを許可してください。');
              }

              if (_localStream != null) {
                setState(() {
                  _localRTCVideoRenderer.srcObject = _localStream;
                });
              }
              // ignore: avoid_function_literals_in_foreach_calls
              _senders.forEach((sender) {
                if (sender.track!.kind == 'video') {
                  sender.replaceTrack(_localStream!.getVideoTracks()[0]);
                }
              });
              _sendScreenCaputerInfo(true);
            } else {
              _stopScreenShare();
              setState(() {
                screenShareBackgroundColor = const Color(0xFF00698D);
                shareScreenButtonText = '画面共有';
                shareScreenButtonState = 1;
              });
              // ignore: use_build_context_synchronously
              showCustomAlertDialog(context, 'エラー', 'コンテンツのキャプチャーを許可してください。');
            }
          });
        });
      } on PlatformException catch (e) {
        debugPrint('PlatformException error: $e');
      }
    } else {
      try {
        // Stop existing tracks in _localStream
        _localStream?.getTracks().forEach((track) {
          track.stop();
        });
        _localStream = await navigator.mediaDevices
            .getDisplayMedia(_displayMediaConstraints);

        if (_localStream != null) {
          setState(() {
            _localRTCVideoRenderer.srcObject = _localStream;
          });
        }

        // ignore: avoid_function_literals_in_foreach_calls
        _senders.forEach((sender) {
          if (sender.track!.kind == 'video') {
            sender.replaceTrack(_localStream!.getVideoTracks()[0]);
          }
        });
        _sendScreenCaputerInfo(true);
      } catch (e) {
        print('erro $e');
        _stopScreenShare();
        setState(() {
          screenShareBackgroundColor = const Color(0xFF00698D);
          shareScreenButtonText = '画面共有';
          shareScreenButtonState = 1;
        });
        // ignore: use_build_context_synchronously
        showCustomAlertDialog(context, 'エラー', 'コンテンツのキャプチャーを許可してください。');
      }
    }
  }

  void _stopScreenShare() async {
    debugPrint('_stopScreenShare  function called.');
    if (WebRTC.platformIsAndroid && versionNumber >= 10) {
      await _peer!.stopCaptureStream();
    }
    _sendScreenCaputerInfo(false);

    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _localStream = await createStream();

    // ignore: avoid_function_literals_in_foreach_calls
    _senders.forEach((sender) {
      if (sender.track!.kind == 'video') {
        sender.replaceTrack(_localStream!.getVideoTracks()[0]);
      }
    });
  }

  void _examStart() {
    setState(() {
      examStartTime = DateTime.now();
    });
    _sendExamStartData();
  }

  void _examEnd() {
    setState(() {
      examEndTime = DateTime.now();
    });
    _sendExamEndData();
  }

  void _endCall() async {
    showCancelAlertDialog(context, '確認', '接続を終了します。よろしいですか？');
  }

  // ポップアップメニューを表示する
  void showButtonMenu() {
    final RenderBox button =
        _popupMenuKey.currentContext!.findRenderObject() as RenderBox;

    RelativeRect? position;

    // if(isLandscape){
    //   // メニューの中心を画面の中心に配置
    //   final Size screenSize = MediaQuery.of(context).size;
    //   final double screenWidth = screenSize.width;
    //   final double screenHeight = screenSize.height;
    //   final double centerX = screenWidth / 2;
    //   final double centerY = screenHeight / 2;

    //   position = RelativeRect.fromLTRB(
    //     centerX,
    //     centerY,
    //     screenWidth - centerX,
    //     screenHeight - centerY,
    //   );
    // }
    // else{
    // メニューの左上隅をボタンの左上隅に配置する
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(const Offset(0, 0), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(const Offset(0, 0)),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    //}

    showMenu<User>(
      context: context,
      position: position!,
      items: userList.map((User user) {
        return PopupMenuItem<User>(
          value: User(userName: user.userName, userNo: user.userNo),
          child: Text(user.userName),
        );
      }).toList(),
    ).then<void>((User? newValue) async {
      if (newValue != null) {
        callCreateConnection(newValue.userNo);
        setState(() {
          callButtonBackgroundColor = const Color(0xFF28a745);
          callButtonText = '監査開始';
          callButtonState = 2;
        });
      }
    });
  }

  void _sendExamStartData() async {
    Map<String, dynamic> examFlg = {
      "exam": true,
      "startExam": true,
    };
    String jsonStringExamFlg = jsonEncode(examFlg);

    // send data to remote peer over signallingA
    if (socket != null) {
      socket!.emit('sendData', {
        "roomId": _roomName,
        "data": jsonStringExamFlg,
      });
    }
  }

  void _sendPartnerInfo() async {
    Map<String, dynamic> partnerInfo = {
      "sendPartnerInfo": true,
      "userData": {"userNo": myUserNo, "machineId": machineId},
      "roomData": {"isExaminationStarted": false}
    };
    String jsonStringPartnerInfo = jsonEncode(partnerInfo);
    if (socket != null) {
      socket!.emit('sendData', {
        "roomId": _roomName,
        "data": jsonStringPartnerInfo,
      });
    }
  }

  void _sendScreenCaputerInfo(isStart) async {
    Map<String, dynamic> deviceInfo = {
      "isMobileUser": isStart,
    };
    String jsonStringInfo = jsonEncode(deviceInfo);

    socket!.emit('sendData', {
      "roomId": _roomName,
      "data": jsonStringInfo,
    });
  }

  void _sendExamEndData() async {
    Map<String, dynamic> examFlg = {
      "exam": true,
      "endExam": true,
    };
    String jsonStringExamFlg = jsonEncode(examFlg);
    if (socket != null) {
      socket!.emit('sendData', {
        "roomId": _roomName,
        "data": jsonStringExamFlg,
      });
    }
  }

  void callCreateConnection(userNo) {
    if (loginKengenKbn != '3' && userNo != null) {
      createConnection(widget.loginToken, selectedRoomCd!, userNo);
    }
  }

  /// Logoutボタン
  void onLogout() async {
    if (isConnected) {
      // ignore: use_build_context_synchronously
      showLogoutAlertDialog(context, '確認', '監査を停止します。よろしいでしょうか？');
    } else {
      SharedPreferences pref = await SharedPreferences.getInstance();
      pref.remove('TOKEN');
      pref.remove('KENGEN');
      pref.remove('SYSTEM-NAME');
      pref.remove('MAP-CONFIG');
      dropdownValue = null;
      // ignore: use_build_context_synchronously
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SelectorScreen()),
      );
    }
  }
}
