class Environments {
  // static const String WsServer = 'ws://840d1d19390f.ngrok.io';
  // static const String WsServer = 'ws://localhost:8081';
  static const String WsServer = 'https://192.168.11.5';
  // static const String WsServer = 'https://signal.servertest.com';
  static const String authKey = "kOvEFJ3pBzvj8=";

  static const Map IceServers = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
      /*
        * turn server configuration example.
        {
          'url': 'turn:123.45.67.89:3478',
          'username': 'change_to_real_user',
          'credential': 'change_to_real_secret'
        },
        */
    ]
  };
}
