import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:online_communication/call_screen.dart';

var loginToken = "111";
var loginKengenKbn = "1";
int? userNoId = 1;

class User {
  final String accessToken;
  final String? faceCd;
  final String kengenKbn;
  final String status;
  final String userName;
  final int userNo;

  const User({
    required this.accessToken,
    required this.faceCd,
    required this.kengenKbn,
    required this.status,
    required this.userName,
    required this.userNo,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    loginToken = json['accessToken'];
    userNoId = json['userNo'];
    loginKengenKbn = json['kengenKbn'];

    return User(
      accessToken: json['accessToken'],
      faceCd: json['faceCd'],
      kengenKbn: json['kengenKbn'],
      status: json['status'],
      userName: json['userName'],
      userNo: json['userNo'],
    );
  }
}

class SelectorScreen extends StatefulWidget {
  const SelectorScreen({super.key});
  @override
  // ignore: library_private_types_in_public_api
  _SelectorScreenState createState() => _SelectorScreenState();
}

class _SelectorScreenState extends State<SelectorScreen> {
  static const String _prefUserId = 'USER-ID';
  static const String _prefPassword = 'PASSWORD';

  static const String baseUrl =
      "https://10.100.9.7:6443/OnlineCommunicationAPI";
  // static const String baseUrl = "https://smartmedical-tm.jp/TELEMEDICINE_API";

  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _errorMessage = '';
  String _systemName = '', _googleMapConfig = '1';
  bool _isLogined = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 戻るのボトンを防ぐ
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              color: const Color(0xFF00698D),
              height: MediaQuery.of(context).padding.top,
            ),
            SafeArea(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      Expanded(
                        child: Image.asset('images/login.png'),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _userIdController,
                          decoration: const InputDecoration(
                            labelText: 'ユーザーID :',
                            hintText: 'ユーザーID',
                          ),
                          onSubmitted: _setUserId,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'パスワード:',
                            hintText: 'パスワード',
                          ),
                          obscureText: true, // TextField as a password field
                          onSubmitted: _setPassword,
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          key: null,
                          onPressed: () => {
                            setState(() {
                              _checkLogin();
                            })
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(2.0),
                            backgroundColor: const Color(0xFF00698D),
                          ),
                          child:
                              _isLoading // Show CircularProgressIndicator if isLoading is true
                                  ? const CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    )
                                  : const Text(
                                      'ログイン',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24.0,
                                        fontWeight: FontWeight.w400,
                                        fontFamily: 'Roboto',
                                      ),
                                    ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SharedPreferencesから前回の設定を読み込む
  void _loadPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String userId = prefs.getString(_prefUserId) ?? '';
    final String password = prefs.getString(_prefPassword) ?? '';

    setState(() {
      _userIdController.text = userId;
      _passwordController.text = password;
    });
  }

  // userId を保存する
  void _setUserId(final String userId) async {
    if (userId.isNotEmpty) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString(_prefUserId, userId);
    }
  }

  // passwordを保存する
  void _setPassword(final String password) async {
    if (password.isNotEmpty) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString(_prefPassword, password);
    }
  }

  void _checkLogin() async {
    // await loginUser(_userIdController.text, _passwordController.text);
    // if (_isLogined) {
    //   await loadSystemName(loginToken);
    //   _setTokenKengenKbn(loginToken, loginKengenKbn, userNoId!);
    //   debugPrint('buttonPressed');
    //   // ignore: use_build_context_synchronously
    //   Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //         builder: (context) =>
    //             CallP2pMeshScreen(loginToken, title: _systemName)),
    //   );
    //   setState(() {
    //     _isLoading = false;
    //   });
    // }

    _setTokenKengenKbn(loginToken, loginKengenKbn, userNoId!);

    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              CallP2pMeshScreen(loginToken, title: _systemName)),
    );
  }

  Future<User?> loginUser(String userId, String password) async {
    try {
      setState(() {
        _isLoading = true;
      });
      final response = await http.post(
        Uri.parse("$baseUrl/User/Login/"),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'loginId': userId,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        _isLogined = true;
        return User.fromJson(jsonDecode(response.body));
      } else {
        // throw an exception.
        final errorMessage = jsonDecode(response.body)['error']['message'] ??
            'An error occurred';
        setState(() {
          _errorMessage = errorMessage;
          _isLoading = false;
        });
        throw Exception(errorMessage);
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      // Handle the exception by displaying an AlertDialog
      showDialog(
        context:
            context, // You need to have access to the BuildContext for this
        builder: (context) {
          return AlertDialog(
            title: const Text('エラー'),
            content: Text(_errorMessage),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return null;
    }
  }

  // loadSystemName
  Future<void> loadSystemName(String loginToken) async {
    Map<String, String> headers = {
      "Content-Type": "application/json",
      'Accept': 'application/json',
      "Authorization": "Bearer $loginToken"
    };

    var response = await http.get(Uri.parse("$baseUrl/User/SystemName/"),
        headers: headers);
    if (response.statusCode == 200) {
      var decodedData = jsonDecode(response.body);
      debugPrint('System Name : $decodedData');
      setState(() {
        _systemName = decodedData['systemName'];
        _googleMapConfig = decodedData['googleMapConfig'];
      });
    } else {
      debugPrint('Failed to loadSystemName');
    }
  }

  void _setTokenKengenKbn(final String token, final String loginKengenKbn,
      final int userNoId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('TOKEN', token);
    prefs.setString('KENGEN', loginKengenKbn);
    prefs.setInt('USERNO', userNoId);
    prefs.setString('SYSTEM-NAME', _systemName);
    prefs.setString('MAP-CONFIG', _googleMapConfig);
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
