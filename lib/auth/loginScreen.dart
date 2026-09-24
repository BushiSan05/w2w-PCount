import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:physicalcountv2/db/sqfLite_dbHelper.dart';
import 'package:physicalcountv2/db/models/logsModel.dart';
import 'package:physicalcountv2/screens/admin/adminDashboardScreen.dart';
import 'package:physicalcountv2/screens/admin/locationManager.dart';
import 'package:physicalcountv2/screens/admin/serverSelectionScreen.dart';
import 'package:physicalcountv2/screens/user/userDashboardScreen.dart';
import 'package:physicalcountv2/services/api.dart';
import 'package:physicalcountv2/services/app_update.dart';
import 'package:physicalcountv2/services/location_list.dart';
import 'package:physicalcountv2/services/server_url.dart';
import 'package:physicalcountv2/values/assets.dart';
import 'package:physicalcountv2/values/globalVariables.dart';
import 'package:physicalcountv2/widget/instantMsgModal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  List adminMasterfileData = [];
  var adminMasterfileCount = 0;
  bool downloading = true;
  bool syncBtn_click = true;
  AppUpdateVersion version = AppUpdateVersion();
  late FocusNode myFocusNodeEmpNo;
  late FocusNode myFocusNodeEmpPin;
  final empnoController = TextEditingController();
  final emppinController = TextEditingController();
  bool btnEnabled = false;
  late SqfliteDBHelper _sqfliteDBHelper;
  Logs _log = Logs();
  DateFormat dateFormat = DateFormat("yyyy-MM-dd");
  DateFormat timeFormat = DateFormat("hh:mm:ss aaa");
  bool obscureENumber = true;
  bool obscureEPin = true;
  String server = GlobalVariables.selectedServer;
  String bu = GlobalVariables.currentBusinessUnit;

  @override
  void initState() {
    loadLocationSettings();
    _sqfliteDBHelper = SqfliteDBHelper.instance;
    downloading = false;
    syncBtn_click = false;
    myFocusNodeEmpNo = FocusNode();
    myFocusNodeEmpPin = FocusNode();
    myFocusNodeEmpNo.requestFocus();
    animationController = new AnimationController(
      vsync: this,
      duration: new Duration(seconds: 7),
    );
    animationController.repeat();
    super.initState();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  getAdminHere() async {
    var net = true;
    downloading = true;
    await _sqfliteDBHelper.deleteAdminAll();
    try {
      adminMasterfileData =
          await getAdmin('True', 'Admin').timeout(const Duration(seconds: 5));
    } on TimeoutException {
      net = false;
    }
    //adminMasterfileData = await getAdmin('True', 'Admin');
    await _sqfliteDBHelper.insertAdminBatch(
        adminMasterfileData, 0, adminMasterfileData.length);
    adminMasterfileCount = adminMasterfileCount + adminMasterfileData.length;
    _log.date = dateFormat.format(DateTime.now());
    _log.time = timeFormat.format(DateTime.now());
    _log.device =
        "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
    _log.user = "USER";
    _log.empid = "USER";
    _log.details = "[SYNC][ADMIN Masterfile]";
    await _sqfliteDBHelper.insertLog(_log);
    downloading = false;
    print("DATA :: ${adminMasterfileData}");
    if (adminMasterfileData.length > 0) {
      setState(() {
        syncBtn_click = false;
      });
      instantMsgModal(
          context,
          Icon(
            CupertinoIcons.checkmark_alt_circle,
            color: Colors.green,
            size: 40,
          ),
          Text("Admin Masterfile successfully synced."));
    } else {
      setState(() {
        syncBtn_click = false;
      });
      instantMsgModal(
          context,
          Icon(
            CupertinoIcons.exclamationmark_circle,
            color: Colors.red,
            size: 40,
          ),
          Text(net
              ? "No Data Received"
              : "Connection is Low, please try again Later"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          titleSpacing: 0.0,
          elevation: 0.0,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              // Left-most: selected location
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  server != ""
                      ? server == "LIVE"
                          ? "🟢 $server"
                          : "🔴 $server"
                      : "⚠️ Need Sync",
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
              Spacer(), // Pushes the server name to the right
              // Right-most: server name
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  bu != "" ? bu : "⚠️ Need Sync",
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: Image.asset(Assets.pc, width: 300),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Center(
                      child: Text('App version ${version.versionNumber()}'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      obscureText: obscureENumber,
                      focusNode: myFocusNodeEmpNo,
                      cursorColor: Colors.black,
                      style: TextStyle(color: Colors.black, fontSize: 25),
                      controller: empnoController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        prefixIcon: Icon(
                          CupertinoIcons.person_alt_circle,
                          color: Colors.black,
                        ),
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        hintText: 'Employee Number',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            empnoController.text.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      if (mounted)
                                        setState(() {
                                          empnoController.clear();
                                          btnEnabled = false;
                                        });
                                    },
                                    icon: Icon(
                                      CupertinoIcons.xmark_circle_fill,
                                      color: Colors.red,
                                    ),
                                  )
                                : SizedBox(),
                            IconButton(
                              icon: !obscureENumber
                                  ? Icon(CupertinoIcons.eye_fill,
                                      color: Colors.blueGrey[900])
                                  : Icon(CupertinoIcons.eye_slash_fill,
                                      color: Colors.blueGrey[900]),
                              onPressed: () {
                                obscureENumber = !obscureENumber;
                                if (mounted) setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                      onChanged: (value) {
                        if (mounted)
                          setState(() {
                            empnoController.text.isNotEmpty &&
                                    emppinController.text.isNotEmpty
                                ? btnEnabled = true
                                : btnEnabled = false;
                          });
                      },
                      onSubmitted: (value) {
                        myFocusNodeEmpPin.requestFocus();
                        onPressLogin();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      obscureText: obscureEPin,
                      focusNode: myFocusNodeEmpPin,
                      cursorColor: Colors.black,
                      style: TextStyle(color: Colors.black, fontSize: 25),
                      controller: emppinController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        prefixIcon: Icon(
                          CupertinoIcons.lock_circle,
                          color: Colors.black,
                        ),
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        hintText: 'Employee Pin',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            emppinController.text.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      if (mounted)
                                        setState(() {
                                          emppinController.clear();
                                          btnEnabled = false;
                                        });
                                    },
                                    icon: Icon(
                                      CupertinoIcons.xmark_circle_fill,
                                      color: Colors.red,
                                    ),
                                  )
                                : SizedBox(),
                            IconButton(
                              icon: !obscureEPin
                                  ? Icon(CupertinoIcons.eye_fill,
                                      color: Colors.blueGrey[900])
                                  : Icon(CupertinoIcons.eye_slash_fill,
                                      color: Colors.blueGrey[900]),
                              onPressed: () {
                                obscureEPin = !obscureEPin;
                                if (mounted) setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                      onChanged: (value) {
                        if (mounted)
                          setState(() {
                            empnoController.text.isNotEmpty &&
                                    emppinController.text.isNotEmpty
                                ? btnEnabled = true
                                : btnEnabled = false;
                          });
                      },
                      onSubmitted: (value) => onPressLogin(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 8.0,
                      right: 8.0,
                      left: 8.0,
                    ),
                    child: MaterialButton(
                      minWidth: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height / 15,
                      elevation: 0.0,
                      child: Text(
                        "Log In",
                        style: TextStyle(
                            color: btnEnabled ? Colors.white : Colors.grey[400],
                            fontSize: 25),
                      ),
                      color: btnEnabled ? Colors.blue : Colors.grey[300],
                      onPressed: () async {
                        await onPressLogin();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool validateCredentials(value) {
    RegExp _regExp = RegExp(r'^[0-9]+$');
    if (_regExp.hasMatch(value)) {
      print('TRUE NI SIYA');
      print(_regExp.hasMatch(value));
      return true;
    } else {
      print('FALSE NI SIYA');
      return false;
    }
  }

  onPressLogin() async {
    print('${empnoController.text.trim()}');
    if (!btnEnabled) return;
    String empNo = empnoController.text.trim();
    String empPin = emppinController.text.trim();

    if (empNo == "0000" && empPin == "0000") {
      await showLocationManager(context)
          .then((value) => myFocusNodeEmpNo.requestFocus());
      empnoController.clear();
      emppinController.clear();
      setState(() {});
      return;
    }

    if (empNo == "IT ROVING" && empPin == "IT ROVING") {
      //logs
      _log.date = dateFormat.format(DateTime.now());
      _log.time = timeFormat.format(DateTime.now());
      _log.device =
          "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
      _log.user = "ADMIN";
      _log.empid = "ADMIN";
      _log.details = "[LOGIN][Admin Login]";
      await _sqfliteDBHelper.insertLog(_log);
      bool proceed = await selectServerAndLocation(context);

      if (proceed) {
        // Only navigate if user pressed Continue
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDashboardScreen(
              user: "ADMIN",
              id: "ADMIN",
              businessUnit: "All",
            ),
          ),
        );
      }
    } else {
      var ls = await _sqfliteDBHelper.selectUserWhere(empNo, empPin);
      // var rs = await _sqfliteDBHelper.fetchUsersWhere("id != 0");
      print(ls);
      if (ls.isNotEmpty) {
        String locationId = ls[0]['location_id'];
        var filter = await _sqfliteDBHelper.selectFilterWhere(locationId);
        print('LOCATION: $locationId');
        print('FILTER: $filter');
        // print(filter[0]['byCategory']);
        GlobalVariables.byCategory =
            filter[0]['byCategory'] == 'True' ? true : false;
        GlobalVariables.categories = filter[0]['categoryName'];
        GlobalVariables.byVendor =
            filter[0]['byVendor'] == 'True' ? true : false;
        GlobalVariables.vendors = filter[0]['vendorName'];
        GlobalVariables.countType = filter[0]['ctype'];
        GlobalVariables.currentLocationID = locationId;
        GlobalVariables.enableExpiry = false;
        GlobalVariables.prevBarCode = "Unknown";
        GlobalVariables.prevItemCode = "Unknown";
        GlobalVariables.prevItemDesc = "Unknown";
        GlobalVariables.prevDesc = "Unknown";
        GlobalVariables.prevItemUOM = "Unknown";
        GlobalVariables.prevLotno = "Unknown";
        GlobalVariables.prevExpiry = "Unknown";
        GlobalVariables.prevQty = "Unknown";
        GlobalVariables.prevDTCreated = "Unknown";
        GlobalVariables.logEmpNo = empNo;
        GlobalVariables.logFullName = ls[0]['name'];
        _log.date = dateFormat.format(DateTime.now());
        _log.time = timeFormat.format(DateTime.now());
        _log.device =
            "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
        _log.user = GlobalVariables.logFullName;
        _log.empid = GlobalVariables.logEmpNo;
        _log.details = "[LOGIN][Inventory Clerk]";
        await _sqfliteDBHelper.insertLog(_log);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => UserDashboardScreen()),
        );
      } else {
        instantMsgModal(
            context,
            Icon(
              CupertinoIcons.exclamationmark_circle,
              color: Colors.red,
              size: 40,
            ),
            Text("Invalid Credentials."));
      }
    }
  }

  // Future<bool> selectServerAndLocation(BuildContext context) async {
  //   String selectedServer = server;
  //   String? selectedLocation = GlobalVariables.currentBusinessUnit;
  //   final serverNames = ServerUrl.servers.keys.toList();
  //   final Map<String,bool> locations = LocationList.locations;
  //
  //   bool proceed = false;
  //
  //   await showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) {
  //       return WillPopScope(
  //         onWillPop: () async {
  //           Navigator.of(context).pop();
  //           proceed = false;
  //           return false;
  //         },
  //         child: StatefulBuilder(
  //           builder: (context, setState) {
  //             return AlertDialog(
  //               title: Text("Select Server and Location"),
  //               content: Column(
  //                 mainAxisSize: MainAxisSize.min,
  //                 children: [
  //
  //                   DropdownButton<String>(
  //                     isExpanded: true,
  //                     value: selectedServer,
  //                     items: serverNames.map((s) {
  //                       return DropdownMenuItem(value: s, child: Text(s));
  //                     }).toList(),
  //                     onChanged: (val) {
  //                       setState(() {
  //                         selectedServer = val!;
  //                         selectedLocation = null;
  //                       });
  //                     },
  //                   ),
  //
  //                   SizedBox(height: 20),
  //
  //                   DropdownButton<String>(
  //                     isExpanded: true,
  //                     hint: Text("Select Location"),
  //                     value: locations[selectedLocation] == true ? selectedLocation : null,
  //                     items: locations.entries.map((entry) {
  //
  //                       final location = entry.key;
  //                       final enabled = entry.value;
  //
  //                       return DropdownMenuItem<String>(
  //                         value: enabled ? location : null,
  //                         enabled: enabled,
  //                         child: Text(
  //                           location,
  //                           style: TextStyle(
  //                             color: enabled ? Colors.black : Colors.grey,
  //                           ),
  //                         ),
  //                       );
  //
  //                     }).toList(),
  //                     onChanged: (val) {
  //                       if (val == null) return;
  //                       setState(() {
  //                         selectedLocation = val;
  //                       });
  //                     },
  //                   ),
  //                 ],
  //               ),
  //               actions: [
  //                 TextButton(
  //                   onPressed: selectedLocation == null || selectedLocation!.isEmpty
  //                     ? null
  //                     : () async {
  //                     print('ang location ky $selectedLocation');
  //                     // Save selections
  //                     SharedPreferences prefs = await SharedPreferences.getInstance();
  //                     await prefs.setString("new_server", selectedServer);
  //                     await prefs.setString("new_loc", selectedLocation!);
  //                     GlobalVariables.selectedServer = selectedServer;
  //                     GlobalVariables.currentBusinessUnit = selectedLocation!;
  //                     ServerUrl.setServer(selectedServer);
  //                     print('ang server connection ky: ${ServerUrl.current}');
  //
  //                     setState(() {
  //                       server = selectedServer;
  //                       bu = selectedLocation!;
  //                     });
  //
  //                     proceed = true; // allow navigation
  //                     Navigator.of(context).pop();
  //                   },
  //                   child: Text("Continue"),
  //                 ),
  //               ],
  //             );
  //           },
  //         ),
  //       );
  //     },
  //   );
  //   return proceed;
  // }

  Future<bool> selectServerAndLocation(BuildContext context) async {
    String selectedServer = server;

    // Only preselect saved location if it's enabled
    String? savedLocation = GlobalVariables.currentBusinessUnit;
    String? selectedLocation =
        (savedLocation != null && LocationList.locations[savedLocation] == true)
            ? savedLocation
            : null;

    final serverNames = ServerUrl.servers.keys.toList();
    final Map<String, bool> locations = LocationList.locations;

    bool proceed = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async {
            Navigator.of(context).pop();
            proceed = false;
            return false;
          },
          child: StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text("Select Server and Location"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedServer,
                      items: serverNames.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s));
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedServer = val!;
                          selectedLocation =
                              null; // reset location if server changes
                        });
                      },
                    ),
                    SizedBox(height: 20),
                    DropdownButton<String>(
                      isExpanded: true,
                      hint: Text("Select Location"),
                      value: (selectedLocation != null &&
                              locations[selectedLocation] == true)
                          ? selectedLocation
                          : null,
                      items: locations.entries.map((entry) {
                        final location = entry.key;
                        final enabled = entry.value;

                        return DropdownMenuItem<String>(
                          value: enabled ? location : null,
                          enabled: enabled,
                          child: Text(
                            location,
                            style: TextStyle(
                              color: enabled ? Colors.black : Colors.grey,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          selectedLocation = val;
                        });
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: (selectedLocation == null)
                        ? null // disable if no enabled location selected
                        : () async {
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();

                            await prefs.setString("new_server", selectedServer);
                            await prefs.setString("new_loc", selectedLocation!);

                            GlobalVariables.selectedServer = selectedServer;
                            GlobalVariables.currentBusinessUnit =
                                selectedLocation!;

                            ServerUrl.setServer(selectedServer);

                            setState(() {
                              server = selectedServer;
                              bu = selectedLocation!;
                            });

                            proceed = true;
                            Navigator.of(context).pop();
                          },
                    child: Text("Continue"),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    return proceed;
  }
}
