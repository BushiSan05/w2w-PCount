import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:physicalcountv2/db/models/logsModel.dart';
import 'package:physicalcountv2/db/sqfLite_dbHelper.dart';
import 'package:physicalcountv2/main.dart';
import 'package:physicalcountv2/screens/admin/activityLogScreen.dart';
import 'package:physicalcountv2/screens/admin/signatureCapture.dart';
import 'package:physicalcountv2/screens/admin/syncDatabaseScreen.dart';
import 'package:physicalcountv2/services/api.dart';
import 'package:physicalcountv2/services/app_update.dart';
import 'package:physicalcountv2/services/location_list.dart';
import 'package:physicalcountv2/services/server_url.dart';
import 'package:physicalcountv2/services/server_url_list.dart';
import 'package:physicalcountv2/values/globalVariables.dart';
import 'package:physicalcountv2/widget/customLogicalModal.dart';
import 'package:physicalcountv2/widget/instantMsgModal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminDashboardScreen extends StatefulWidget {
  final user;
  final id;
  final businessUnit;
  const AdminDashboardScreen(
      {Key? key,
      required this.user,
      required this.id,
      required this.businessUnit})
      : super(key: key);
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final List<String> items = [
    'Item1',
    'Item2',
    'Item3',
    'Item4',
  ];
  var version = AppUpdateVersion().versionNumber();
  String? selectedValue;
  ServerUrlList sul = ServerUrlList();
  var serverName = ServerUrl.servers.keys.toList();
  late String _currentItemSelectd = '';
  String prev_server = "";
  String new_server = "";
  bool btnUpdateClick = true;
  int totUsers = 0;
  int totAudit = 0;
  int totLocations = 0;
  int totItems = 0;
  String formattedTotUsers = '';
  String formattedTotAudit = '';
  String formattedTotLocation = '';
  String formattedTotItems = '';
  bool isLoading = false;
  late SqfliteDBHelper _sqfliteDBHelper;
  Logs _log = Logs();
  DateFormat dateFormat = DateFormat("yyyy-MM-dd");
  DateFormat timeFormat = DateFormat("hh:mm:ss aaa");

  @override
  void initState() {
    print('Business Unit ::: ${widget.businessUnit}');
    _sqfliteDBHelper = SqfliteDBHelper.instance;
    btnUpdateClick = false;
    checkSelectedServer();
    loadCounts();
    super.initState();
  }

  Future<void> checkSelectedServer() async {
    final prefs = await SharedPreferences.getInstance();
    String savedServer = prefs.getString('new_server') ?? serverName[0];

    setState(() {
      _currentItemSelectd = savedServer;
      GlobalVariables.selectedServer = savedServer;
    });

    ServerUrl.setServer(savedServer);
    print('Current server URL: ${ServerUrl.current}');
  }

  checkAppUpdate() async {
    print('VERSION: $version');
    var res = await checkUpdate(version);
    print(res);
    if (res == 'Uptodate') {
      await _showDialog(
          "$res", "Your app is up to date. \n App version $version", '');
      setState(() {
        isLoading = false;
      });
    } else {
      if (res['version'] != '') {
        await _showDialog("Latest Version available",
            "App Version ${res['version']}", '${res['url']}');
      } else {
        await _showDialog("Error", "Something went wrong", '');
      }
    }
    print("false");
    setState(() {
      isLoading = false;
    });
    btnUpdateClick = false;
  }

  _showDialog(String title, String content, String url) {
    showDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: title != 'Uptodate'
                ? Text("$title")
                : Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 36,
                  ),
            content: Text(
              "$content",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            actions: <Widget>[
              title != 'Uptodate'
                  ? TextButton(
                      child: Text("Download"),
                      onPressed: () async {
                        //Navigator.of(context).pop();
                        _launchURL(url);
                        //openBrowserURL(url: url, inApp: true);
                      },
                    )
                  : SizedBox(),
              title != 'Uptodate'
                  ? TextButton(
                      child: Text("Later"),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    )
                  : SizedBox(),
            ],
          );
        });
  }

  _launchURL(String urlApk) async {
    var url = '$urlApk';
    //var url = 'https://tinyurl.com/pcountpm1';
    if (await launch(url)) {
      await canLaunch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void serverLog(String fServer) async {
    _log.date = dateFormat.format(DateTime.now());
    _log.time = timeFormat.format(DateTime.now());
    _log.device =
        "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
    _log.user = "${widget.user}";
    _log.empid = "${widget.id}";
    _log.details = "[SERVER][$fServer Change to $_currentItemSelectd]";
    await _sqfliteDBHelper.insertLog(_log);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        // appBar: AppBar(
        //   automaticallyImplyLeading: false,
        //   backgroundColor: Colors.transparent,
        //   titleSpacing: 0.0,
        //   elevation: 0.0,
        //   title: Padding(
        //     padding: const EdgeInsets.only(left: 8.0),
        //     child: Text(
        //       "ADMINISTRATOR ACCESS",
        //       style: TextStyle(
        //           color: Colors.blue,
        //           fontSize: 18.0
        //       ),
        //     ),
        //   ),
        //   actions: <Widget>[
        //     Row(
        //       mainAxisAlignment: MainAxisAlignment.end,
        //       children: [
        //         widget.businessUnit == 'All' ?
        //         Text("Selected Server : ",
        //           style: TextStyle(
        //             color: Colors.black,
        //             fontSize: 17,
        //           ),
        //         )
        //             : SizedBox(),
        //         widget.businessUnit == 'All' ?
        //         DropdownButtonHideUnderline(
        //           child: Container(
        //             height: 40,
        //             width: 160,
        //             child: DropdownButton(
        //               isExpanded: true,
        //               value: _currentItemSelectd,
        //               items: serverName.map((String dropDownStringItem) {
        //                 return DropdownMenuItem(
        //                   value: dropDownStringItem,
        //                   child: Text(dropDownStringItem),
        //                 );
        //               }).toList(),
        //               onChanged: (String? newValueSelected) async {
        //
        //                 if (newValueSelected != _currentItemSelectd) {
        //
        //                   showDialog(
        //                     barrierDismissible: true,
        //                     context: context,
        //                     builder: (BuildContext context) {
        //
        //                       return CupertinoAlertDialog(
        //                         title: Text("Switching Server"),
        //                         content: Text("Continue to Switch a new Server?"),
        //                         actions: <Widget>[
        //
        //                           TextButton(
        //                             child: Text("Yes"),
        //                             onPressed: () async {
        //
        //                               var previousServer = _currentItemSelectd;
        //
        //                               SharedPreferences prefs =
        //                               await SharedPreferences.getInstance();
        //
        //                               String selectedServer =
        //                               newValueSelected!.trim();
        //
        //                               await prefs.setString("new_server", selectedServer);
        //
        //                               setState(() {
        //
        //                                 _currentItemSelectd = selectedServer;
        //                                 GlobalVariables.currentBusinessUnit = selectedServer;
        //                                 ServerUrl.setServer(selectedServer);
        //
        //                                 print("new server :: ${ServerUrl.current}");
        //
        //                               });
        //
        //                               serverLog(previousServer);
        //
        //                               Navigator.of(context).pop();
        //                             },
        //                           ),
        //
        //                           TextButton(
        //                             child: Text("No"),
        //                             onPressed: () {
        //                               Navigator.of(context).pop();
        //                             },
        //                           ),
        //
        //                         ],
        //                       );
        //                     },
        //                   );
        //                 }
        //               },
        //               iconEnabledColor: Colors.lightBlueAccent,
        //               style: TextStyle(
        //                 color: Colors.blueAccent,
        //                 fontSize: 12.0,
        //               ),
        //               borderRadius: BorderRadius.all(
        //                 Radius.circular(10),
        //               ),
        //             ),
        //           ),
        //         )
        //         : SizedBox(width: 30),
        //         IconButton(
        //           icon: Icon(Icons.logout, color: Colors.red),
        //           color: Colors.white,
        //           onPressed: () {
        //             logOut();
        //           },
        //         ),
        //       ],
        //     ),
        //   ],
        // ),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          titleSpacing: 0.0,
          elevation: 0.0,
          title: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              "ADMINISTRATOR ACCESS",
              style: TextStyle(color: Colors.blue, fontSize: 18.0),
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Display selected server
                Text(
                  GlobalVariables.selectedServer != ""
                      ? "${GlobalVariables.selectedServer}"
                      : "LOCAL",
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
                SizedBox(width: 10),

                // Display selected location
                Text(
                  GlobalVariables.currentBusinessUnit != ""
                      ? "${GlobalVariables.currentBusinessUnit}"
                      : "Location: Not selected",
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
                SizedBox(width: 10),

                // Logout button
                IconButton(
                  icon: Icon(Icons.logout, color: Colors.red),
                  onPressed: logOut,
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            isLoading ? LinearProgressIndicator() : SizedBox(),
            Expanded(
              child: ListView(
                children: [
                  Divider(),
                  menuList(Icons.sync, "Sync Database", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => SyncDatabaseScreen(
                              user: "${widget.user}", id: "${widget.id}")),
                    ).then((result) {
                      if (result != null && result == true) {
                        setState(() {
                          loadCounts();
                        });
                      }
                    });
                  }),
                  Divider(),
                  menuList(CupertinoIcons.list_bullet_below_rectangle,
                      "Activity Log", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ActivityLogScreen()),
                    );
                  }),
                  // Divider(),
                  // menuList(CupertinoIcons.signature, "Signature Uploading", () {
                  //   Navigator.push(
                  //     context,
                  //     MaterialPageRoute(
                  //         builder: (context) => SignatureCapture()),
                  //   );
                  // }),
                  Divider(),
                  menuList(
                      CupertinoIcons.checkmark_rectangle, "Check for Update",
                      () async {
                    if (!btnUpdateClick) {
                      btnUpdateClick = true;
                      if (mounted) setState(() {});
                      var res = await checkConnection();
                      if (mounted) setState(() {});
                      if (res == 'error') {
                        instantMsgModal(
                            context,
                            Icon(
                              CupertinoIcons.exclamationmark_circle,
                              color: Colors.red,
                              size: 40,
                            ),
                            Text("${GlobalVariables.httpError}"));
                        btnUpdateClick = false;
                      } else if (res == 'errornet') {
                        instantMsgModal(
                            context,
                            Icon(
                              CupertinoIcons.exclamationmark_circle,
                              color: Colors.red,
                              size: 40,
                            ),
                            Text("${GlobalVariables.httpError}"));
                        btnUpdateClick = false;
                      } else {
                        if (res == 'connected') {
                          isLoading = true;
                          await checkAppUpdate();
                        } else {
                          btnUpdateClick = false;
                        }
                        // setState(() {
                        //   btn_sync =true;
                        // });
                      }
                    }
                    /*Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CheckForUpdate()),
                    );*/
                  }),
                  Divider(),
                  totUsers == 0 &&
                          totAudit == 0 &&
                          totLocations == 0 &&
                          totItems == 0
                      ? Column(
                          children: [
                            SizedBox(height: 15.0),
                            Text('DATABASE NOT SYNC!',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 25.0)),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: 15.0),
                            Text('DATABASES SYNCED',
                                style: TextStyle(fontSize: 18.0)),
                            SizedBox(height: 10.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Users ',
                                    style: TextStyle(fontSize: 18.0)),
                                totUsers == 0
                                    ? Icon(Icons.cancel, color: Colors.red)
                                    : Icon(Icons.check_circle,
                                        color: Colors.green)
                              ],
                            ),
                            SizedBox(height: 5.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Audit ',
                                    style: TextStyle(fontSize: 18.0)),
                                totAudit == 0
                                    ? Icon(Icons.cancel, color: Colors.red)
                                    : Icon(Icons.check_circle,
                                        color: Colors.green)
                              ],
                            ),
                            SizedBox(height: 5.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Locations ',
                                    style: TextStyle(fontSize: 18.0)),
                                totLocations == 0
                                    ? Icon(Icons.cancel, color: Colors.red)
                                    : Icon(Icons.check_circle,
                                        color: Colors.green)
                              ],
                            ),
                            SizedBox(height: 5.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Items ',
                                    style: TextStyle(fontSize: 18.0)),
                                totItems == 0
                                    ? Icon(Icons.cancel, color: Colors.red)
                                    : Icon(Icons.check_circle,
                                        color: Colors.green)
                              ],
                            ),
                          ],
                        )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget menuList(IconData icon, String title, VoidCallback voidCallback) {
    return GestureDetector(
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0),
        child: Container(
          height: MediaQuery.of(context).size.height / 7,
          color: Colors.white,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                    child: Icon(
                      icon,
                      color: Colors.blue,
                      size: 70.0,
                    ),
                  ),
                  Material(
                    type: MaterialType.transparency,
                    child: FittedBox(
                      child: Text(
                        title,
                        style: TextStyle(fontSize: 25),
                      ),
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
      onTap: voidCallback,
    );
  }

  logOut() {
    customLogicalModal(context, Text("Are you sure you want to logout?"),
        () => Navigator.pop(context), () async {
      _log.date = dateFormat.format(DateTime.now());
      _log.time = timeFormat.format(DateTime.now());
      _log.device =
          "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
      _log.user = "${widget.user}";
      _log.empid = "${widget.id}";
      _log.details = "[LOGOUT][Admin Logout]";
      await _sqfliteDBHelper.insertLog(_log);
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (BuildContext context) => PhysicalCount(),
          ),
          (Route route) => false);
    });
  }

  void loadCounts() async {
    totUsers = await _sqfliteDBHelper.getTotUsers();
    formattedTotUsers = NumberFormat('#,###').format(totUsers);
    totAudit = await _sqfliteDBHelper.getTotAudit();
    formattedTotAudit = NumberFormat('#,###').format(totAudit);
    totLocations = await _sqfliteDBHelper.getTotLocation();
    formattedTotLocation = NumberFormat('#,###').format(totLocations);
    totItems = await _sqfliteDBHelper.getTotItems();
    formattedTotItems = NumberFormat('#,###').format(totItems);
    print('ang totItems $formattedTotItems');
    setState(() {});
  }
}
