import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:permission_handler/permission_handler.dart' as permission;
import 'package:location/location.dart';
import 'package:online_communication/login_screen.dart';
import 'package:online_communication/call_screen.dart';

String? token;
String? systemName;
class MyHttpOverrides extends HttpOverrides{
  @override
  HttpClient createHttpClient(SecurityContext? context){
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port)=> true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // initialize splash screen
  var widgetsBinding = WidgetsBinding.instance; // Get WidgetsBinding instance
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding); // Pass it to FlutterNativeSplash.preserve
  // get saved data
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  token = prefs.getString('TOKEN') ?? '';
  systemName = prefs.getString('SYSTEM-NAME') ?? '';
   // For allowing requests to the public network
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  static const Color myPrimaryColor = Color(0xFF00698D);

  @override
  Widget build(BuildContext context) {
    MaterialColor myPrimarySwatch = MaterialColor(
      myPrimaryColor.value,
      const <int, Color>{
        50: myPrimaryColor,
        100: myPrimaryColor,
        200: myPrimaryColor,
        300: myPrimaryColor,
        400: myPrimaryColor,
        500: myPrimaryColor, 
        600: myPrimaryColor,
        700: myPrimaryColor,
        800: myPrimaryColor,
        900: myPrimaryColor,
      },
    );

    return MaterialApp(
      theme: ThemeData(
        primarySwatch: myPrimarySwatch,
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), // Use SplashScreen as your initial screen
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Location
  final Location location = Location();
  late bool _serviceEnabled;
  late PermissionStatus _permissionGranted;

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async{
    await checkPermission();
    await _initLocation();
  }

  Future<void> _loadData() async {
    // Simulate a 2-second delay
    await Future.delayed(const Duration(seconds: 2));
    // remove splash screen
    FlutterNativeSplash.remove();
  }


  /// 必要なパーミッション(CAMERA, RECORD_AUDIO)を保持しているかを
  /// 確認し保持していない場合にはパーミッションを要求する
  Future<void> checkPermission() async {
    // Request permissions
    Map<permission.Permission, permission.PermissionStatus> statuses = await [
      permission.Permission.camera,
      permission.Permission.microphone,
    ].request();
    print(statuses);
  }

  
  Future<void> _initLocation() async {
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
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // To prevent navigating back, return false
        return false;
      },
      child: FutureBuilder<void>(
        future: _loadData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // Loading is complete, navigate to the next screen
            Future.microtask(() {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) {
                  if (token != "") {
                    return CallP2pMeshScreen(token!, title: systemName!);
                  } else {
                    return const SelectorScreen();
                  }
                }),
              );
            });
          }
          return const Scaffold(
            backgroundColor: Color(0xFF00698D),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }
}