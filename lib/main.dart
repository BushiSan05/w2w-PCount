import 'dart:async';
import 'dart:io';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:physicalcountv2/auth/loginScreen.dart';
import 'package:physicalcountv2/db/sqfLite_dbHelper.dart';
import 'package:physicalcountv2/services/server_url.dart';
import 'package:physicalcountv2/services/server_url_list.dart';
import 'package:physicalcountv2/values/assets.dart';
import 'package:physicalcountv2/values/globalVariables.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(PhysicalCount());
}

class PhysicalCount extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // SystemChrome.setPreferredOrientations([
    //   DeviceOrientation.portraitUp,
    // ]);
    return MaterialApp(
      title: 'Physical Count',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Splash(),
    );
  }
}

class Splash extends StatefulWidget {
  const Splash({Key? key}) : super(key: key);

  @override
  _SplashState createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  ServerUrlList sul = ServerUrlList();
  String deviceName = '';
  String deviceVersion = '';
  String identifier = '';
  late SqfliteDBHelper _sqfliteDBHelper;

  void initState() {
    super.initState();
    _sqfliteDBHelper = SqfliteDBHelper.instance;
    checkSelectedServer();
    GlobalVariables.bodyContext = context;
    _initializeApp();
    Timer(Duration(seconds: 2), () {
      _deviceDetails();
      gotoLogin();
    });
  }

  Future<void> _initializeApp() async {
    await _requestProperStoragePermission();
  }

  Future<void> _requestProperStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted ||
          await Permission.storage.isGranted) {
        return;
      }

      final manageStorage =
      await Permission.manageExternalStorage.request();

      if (manageStorage.isGranted) {
        return;
      }

      await Permission.storage.request();
    }
  }

  checkSelectedServer() async {
    await _sqfliteDBHelper.updateItemCountNullDesc();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.getString('new_server');
    prefs.getString('new_loc');
    String savedServer = prefs.getString('new_server') ?? 'LOCAL';
    String savedLocation = prefs.getString('new_loc') ?? '';
    GlobalVariables.selectedServer = savedServer;
    GlobalVariables.currentBusinessUnit = savedLocation;
    ServerUrl.setServer(savedServer);

    print("Loaded server: $savedServer");
    print('Loaded bu: $savedLocation');
    print("Server URL: ${ServerUrl.current}");
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Image.asset(
                Assets.pc,
                width: 300,
              ),
            ),
          ),
          Center(
            child: CircularProgressIndicator(
              backgroundColor: Colors.blue,
              valueColor: new AlwaysStoppedAnimation<Color>(Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future gotoLogin() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  Future<void> _deviceDetails() async {
    final DeviceInfoPlugin deviceInfoPlugin = new DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        var build = await deviceInfoPlugin.androidInfo;
        deviceName = build.model;
        identifier = build.androidId;
        GlobalVariables.deviceInfo = "$deviceName $identifier";
        GlobalVariables.readdeviceInfo = "${build.brand} ${build.device}";
        //UUID for Android
      } else if (Platform.isIOS) {
        var data = await deviceInfoPlugin.iosInfo;
        deviceName = data.name;
        identifier = data.identifierForVendor;
        GlobalVariables.deviceInfo = "$deviceName $identifier";
        GlobalVariables.readdeviceInfo = "${data.utsname.machine}";
        //UUID for iOS
      }
    } on PlatformException {
      print('Failed to get platform version');
    }
  }
}
