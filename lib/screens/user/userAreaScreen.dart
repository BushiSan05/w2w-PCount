import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:physicalcountv2/db/models/itemCountModel.dart';
import 'package:physicalcountv2/db/sqfLite_dbHelper.dart';
import 'package:physicalcountv2/screens/user/itemNotFoundScanScreen.dart';
import 'package:physicalcountv2/screens/user/itemScannedListScreen.dart';
import 'package:physicalcountv2/screens/user/itemScanningScreen.dart';
import 'package:physicalcountv2/screens/user/syncScannedItemScreen.dart';
import 'package:physicalcountv2/screens/user/viewItemNotFoundScanScreen.dart';
import 'package:physicalcountv2/screens/user/viewItemScannedListScreen.dart';
import 'package:physicalcountv2/services/api.dart';
import 'package:physicalcountv2/services/server_url_list.dart';
import 'package:physicalcountv2/values/globalVariables.dart';
import 'package:physicalcountv2/widget/instantMsgModal.dart';
import 'package:physicalcountv2/services/server_url.dart';
import 'package:physicalcountv2/widget/scanAuditModal.dart';
import 'package:physicalcountv2/widget/scanRovingITModal.dart';

import '../../db/models/itemNotFoundModel.dart';

class UserAreaScreen extends StatefulWidget {
  const UserAreaScreen({Key? key}) : super(key: key);

  @override
  _UserAreaScreenState createState() => _UserAreaScreenState();
}

class _UserAreaScreenState extends State<UserAreaScreen>
    with SingleTickerProviderStateMixin {
  ServerUrlList sul = ServerUrlList();

  late SqfliteDBHelper _sqfliteDBHelper;
  List _assignArea = [];
  bool checking = true;
  List countType = [];
  bool checkingData = false;
  bool btnSyncClick = false;
  int indexClick = -1;
  late AnimationController animationController;
  int remainingCount1 = 0;
  int remainingCount2 = 0;

  @override
  void initState() {
    super.initState();
    _sqfliteDBHelper = SqfliteDBHelper.instance;
    checkingData = true;
    animationController = new AnimationController(
      vsync: this,
      duration: new Duration(seconds: 1),
    );
    _refreshUserAssignAreaList();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  Future checkCountItemAssignArea(List assignArea) async {
    var areaLen = assignArea.length;
    for (int i = 0; i < areaLen; i++) {
      List<ItemCount> x = await _sqfliteDBHelper.fetchItemCountWhere(
          "empno = '${GlobalVariables.logEmpNo}' AND business_unit = '${assignArea[i]['business_unit']}' AND department = '${assignArea[i]['department']}' AND section  = '${assignArea[i]['section']}' AND rack_desc  = '${assignArea[i]['rack_desc']}' AND location_id = '${assignArea[i]['location_id']}'");
      if (x.isNotEmpty) {
        await _lockUnlockLocation2(
            true, true, assignArea[i]['location_id'].toString());
      }
      if (i == areaLen - 1) {
        checkingData = false;
        _refreshUserAssignAreaList();
      }
    }
  }

  bool isWithinOneWeek(DateTime scheduledDate) {
    final now = DateTime.now();
    final oneWeekBefore = now.subtract(Duration(days: 7));
    final oneWeekLater = now.add(Duration(days: 7));
    return scheduledDate.isAfter(oneWeekBefore) &&
        scheduledDate.isBefore(oneWeekLater);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${GlobalVariables.currentBusinessUnit}",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          titleSpacing: 0.0,
          elevation: 0.0,
          leadingWidth: 150,
          leading: Container(
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.close, color: Colors.red),
                onPressed: () async {
                  var count = await _sqfliteDBHelper.selectItemCountRawQuery(
                      "SELECT COUNT(*) as totalCount FROM ${ItemCount.tblItemCount} WHERE exported != 'EXPORTED'");
                  var count2 = await _sqfliteDBHelper.selectItemCountRawQuery(
                      "SELECT COUNT(*) as totalNF FROM ${ItemNotFound.tblItemNotFound} WHERE exported != 'EXPORTED'");
                  var result1 =
                      count.isNotEmpty && count[0]['totalCount'] != null
                          ? count[0]['totalCount']
                          : 0;
                  var result2 =
                      count2.isNotEmpty && count2[0]['totalNF'] != null
                          ? count2[0]['totalNF']
                          : 0;
                  // Only proceed to close if both counts are 0
                  if (result1 == 0 && result2 == 0) {
                    print(
                        "Closing screen, no items left: $result1 and $result2");
                    Navigator.of(context).pop();
                  } else {
                    Fluttertoast.showToast(
                      msg: 'There are still items that have not been synced.\n'
                          'Please review the scanned items and proceed with syncing.',
                      toastLength: Toast.LENGTH_LONG,
                      gravity: ToastGravity.BOTTOM,
                      backgroundColor: Colors.black54,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );
                    print("Items still exist. Can't close the screen.");
                    print("Counts are $result1 and $result2");
                  }
                },
              ),
              Expanded(
                child: Text(
                  "User Area",
                  style: TextStyle(
                      color: Colors.blue,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ]),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            checking ? LinearProgressIndicator() : SizedBox(),
            !checking
                ? Expanded(
                    child: Scrollbar(
                      child: ListView.builder(
                        itemCount: _assignArea.length,
                        itemBuilder: (context, index) {
                          var data = _assignArea;
                          var countData = countType;
                          if (index >= 0 && index < countData.length) {
                            var scheduledDate =
                                DateTime.parse(countData[index]['batchDate']);

                            if (!isWithinOneWeek(scheduledDate)) {
                              // Skip adding this item to the list
                              return SizedBox.shrink();
                            }
                            print("Scheduled Date: $scheduledDate");
                            print(
                                "Is Within One Week: ${isWithinOneWeek(scheduledDate)}");
                          } else {
                            // Handle the case when index is out of bounds, e.g., print an error message or provide a default value.
                            print('Invalid index: $index');
                          }
                          for (int i = 0; i < countData.length; i++) {
                            print("Index: $i, Data: ${countData[i]}");
                          }
                          print("mao ni index: $index");

                          return Padding(
                            padding:
                                const EdgeInsets.only(right: 8.0, left: 8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        data[index]['company'] +
                                            "/ " +
                                            data[index]['business_unit'] +
                                            "/ " +
                                            data[index]['department'] +
                                            "/ " +
                                            data[index]['section'],
                                        style: TextStyle(fontSize: 18),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10.0),
                                Row(
                                  children: [
                                    Icon(
                                      data[index]['done'] == 'true'
                                          ? CupertinoIcons
                                              .checkmark_alt_circle_fill
                                          : CupertinoIcons.ellipsis_circle_fill,
                                      size: 30,
                                      color: data[index]['done'] == 'true'
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                    SizedBox(width: 2.0),
                                    Expanded(
                                      child: Text(
                                        data[index]['rack_desc'],
                                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 10),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: <Widget>[
                                          Column(
                                            children: <Widget>[
                                              RichText(
                                                text: TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text: 'Count Type: ',
                                                      style: TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 12),
                                                    ),
                                                    TextSpan(
                                                      text: (index <
                                                              countData.length
                                                          ? countData[index]
                                                              ['countType']
                                                          : 'Invalid Index'),
                                                      style: TextStyle(
                                                          color:
                                                              Colors.deepOrange,
                                                          fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              RichText(
                                                text: TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text: 'Category: ',
                                                      style: TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 12),
                                                    ),
                                                    TextSpan(
                                                      text: (index <
                                                              countData.length
                                                          ? countData[index]
                                                              ['ctype']
                                                          : 'Invalid Index'),
                                                      style: TextStyle(
                                                          color:
                                                              Colors.deepOrange,
                                                          fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              RichText(
                                                text: TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text: 'Sched: ',
                                                      style: TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 12),
                                                    ),
                                                    TextSpan(
                                                      text: (index <
                                                              countData.length
                                                          ? countData[index]
                                                              ['batchDate']
                                                          : 'Invalid Index'),
                                                      style: TextStyle(
                                                          color:
                                                              Colors.deepOrange,
                                                          fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Spacer(),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          final batchDate =
                                              DateFormat("yyyy-MM-dd").parse(
                                                  countData[index]
                                                      ['batchDate']);
                                          final dateTimeNow = DateTime.now();
                                          print('BATCH DATE: $batchDate');
                                          final difference = dateTimeNow
                                              .difference(batchDate)
                                              .inDays;
                                          print('DIFFERENCE: $difference');
                                          if (data[index]['locked'] ==
                                              'false') {
                                            GlobalVariables.currentLocationID =
                                                data[index]['location_id'];
                                            GlobalVariables.currentCompany =
                                                data[index]['company'];
                                            GlobalVariables
                                                    .currentBusinessUnit =
                                                data[index]['business_unit'];
                                            GlobalVariables.currentDepartment =
                                                data[index]['department'];
                                            GlobalVariables.currentSection =
                                                data[index]['section'];
                                            GlobalVariables.currentRackDesc =
                                                data[index]['rack_desc'];
                                            var dtls =
                                                "[LOGIN][Audit] scan ID to add item on location (${data[index]['business_unit']}/${data[index]['department']}/${data[index]['section']}/${data[index]['rack_desc']}).]";
                                            GlobalVariables.isAuditLogged =
                                                false;
                                            // await scanAuditModal(context, _sqfliteDBHelper, dtls);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      ItemScanningScreen()),
                                            ).then((value) {
                                              _refreshUserAssignAreaList();
                                            });
                                          } else {
                                            instantMsgModal(
                                                context,
                                                Icon(
                                                  CupertinoIcons
                                                      .exclamationmark_circle,
                                                  color: Colors.red,
                                                  size: 40,
                                                ),
                                                Text(
                                                    "This location is locked."));
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                            primary: Colors.blue),
                                        child: Row(
                                          children: [
                                            Icon(CupertinoIcons
                                                .barcode_viewfinder),
                                            Text("Start scan"),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () async {
                                              GlobalVariables.currentLocationID = data[index]['location_id'];
                                              GlobalVariables.currentCompany = data[index]['company'];
                                              GlobalVariables.currentBusinessUnit = data[index]['business_unit'];
                                              GlobalVariables.currentDepartment = data[index]['department'];
                                              GlobalVariables.currentSection = data[index]['section'];
                                              GlobalVariables.currentRackDesc = data[index]['rack_desc'];
                                              GlobalVariables.ableEditDelete = false;
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) => ItemScannedListScreen()),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                                primary: Colors.yellow[700]),
                                            child: Row(
                                              children: [
                                                Icon(CupertinoIcons
                                                    .doc_plaintext),
                                                SizedBox(width: 5),
                                                Text("View-S"),
                                              ],
                                            ),
                                          ),
                                          // Counter badge positioned at the upper right corner
                                          FutureBuilder<int>(
                                            future: getRemainingItemCount(
                                                data[index]['rack_desc'],
                                                data[index]['location_id']),
                                            builder: (context, snapshot) {
                                              int remainingCount =
                                                  snapshot.data ?? 0;
                                              if (remainingCount > 0) {
                                                return Positioned(
                                                  right: -5,
                                                  top: -8,
                                                  child: Container(
                                                    padding: EdgeInsets.all(5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                          color: Colors.white,
                                                          width: 2),
                                                    ),
                                                    constraints: BoxConstraints(
                                                      minWidth: 22,
                                                      minHeight: 22,
                                                    ),
                                                    child: Text(
                                                      '$remainingCount',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                );
                                              }
                                              return SizedBox(); // Return empty widget if count is 0
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () async {
                                              GlobalVariables.currentLocationID = data[index]['location_id'];
                                              GlobalVariables.currentCompany = data[index]['company'];
                                              GlobalVariables.currentBusinessUnit = data[index]['business_unit'];
                                              GlobalVariables.currentDepartment = data[index]['department'];
                                              GlobalVariables.currentSection = data[index]['section'];
                                              GlobalVariables.currentRackDesc = data[index]['rack_desc'];
                                              GlobalVariables.ableEditDelete = false;
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) => ItemNotFoundScanScreen()),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                                primary: Colors.yellow[700]),
                                            child: Row(
                                              children: [
                                                Icon(CupertinoIcons
                                                    .doc_plaintext),
                                                SizedBox(width: 5),
                                                Text("View-NF"),
                                              ],
                                            ),
                                          ),
                                          // Counter badge positioned at the upper right corner
                                          FutureBuilder<int>(
                                            future: getRemainingNfItemCount(
                                                data[index]['rack_desc'],
                                                data[index]['location_id']),
                                            builder: (context, snapshot) {
                                              int remainingCount =
                                                  snapshot.data ?? 0;
                                              if (remainingCount > 0) {
                                                return Positioned(
                                                  right: -5,
                                                  top: -8,
                                                  child: Container(
                                                    padding: EdgeInsets.all(5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                          color: Colors.white,
                                                          width: 2),
                                                    ),
                                                    constraints: BoxConstraints(
                                                      minWidth: 22,
                                                      minHeight: 22,
                                                    ),
                                                    child: Text(
                                                      '$remainingCount',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                );
                                              }
                                              return SizedBox(); // Return empty widget if count is 0
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          GlobalVariables.currentLocationID = data[index]['location_id'];
                                          GlobalVariables.currentCompany = data[index]['company'];
                                          GlobalVariables.currentBusinessUnit = data[index]['business_unit'];
                                          GlobalVariables.currentDepartment = data[index]['department'];
                                          GlobalVariables.currentSection = data[index]['section'];
                                          GlobalVariables.currentRackDesc = data[index]['rack_desc'];
                                          var dtls = data[index]['locked'] == 'true'
                                              ? "[LOCK][Audit Lock Rack (${data[index]['business_unit']}/${data[index]['department']}/${data[index]['section']}/${data[index]['rack_desc']})]"
                                              : "[LOCK][Audit Unlock Rack (${data[index]['business_unit']}/${data[index]['department']}/${data[index]['section']}/${data[index]['rack_desc']})]";
                                          GlobalVariables.isAuditLogged = false;
                                          await scanAuditModal(context, _sqfliteDBHelper, dtls);
                                          if (GlobalVariables.isAuditLogged == true) {data[index]['locked'].toString() == 'true'
                                                ? _lockUnlockLocation(index, false, false)
                                                : _lockUnlockLocation(index, true, true);
                                          }
                                        },
                                        style: data[index]['locked'] == 'true'
                                            ? ElevatedButton.styleFrom(primary: Colors.red)
                                            : ElevatedButton.styleFrom(primary: Colors.red[200]),
                                        child: Row(
                                          children: [
                                            Icon(data[index]['locked'] == 'true'
                                                ? CupertinoIcons.lock_fill
                                                : CupertinoIcons.lock_open_fill),
                                            Text(data[index]['locked'] == 'true'
                                                ? "Locked"
                                                : "Unlock"),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(padding: const EdgeInsets.only(right: 8.0),
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          if (!btnSyncClick) {
                                            setState(() {
                                              btnSyncClick = true;
                                              indexClick = index;
                                            });
                                            animationController.repeat();
                                            var res = await checkConnection();
                                            if (res == 'connected') {
                                              showDialog(
                                                  barrierDismissible: false,
                                                  context: context,
                                                  builder: (BuildContext context) {
                                                    return CupertinoAlertDialog(
                                                      title: Text("${GlobalVariables.currentBusinessUnit} Server"),
                                                      content: Text("Continue to Sync in this Server?"),
                                                      actions: <Widget>[
                                                        TextButton(
                                                            child: Text("Yes"),
                                                            onPressed: () async {
                                                              print("Still here!");
                                                              GlobalVariables.currentLocationID = data[index]['location_id'];
                                                              GlobalVariables.currentCompany = data[index]['company'];
                                                              GlobalVariables.currentBusinessUnit = data[index]['business_unit'];
                                                              GlobalVariables.currentDepartment = data[index]['department'];
                                                              GlobalVariables.currentSection = data[index]['section'];
                                                              GlobalVariables.currentRackDesc = data[index]['rack_desc'];
                                                              animationController.stop();
                                                              setState(() {
                                                                btnSyncClick = false;
                                                                indexClick = index;
                                                              });
                                                              Navigator.of(context).pop();
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                    builder: (context) => SyncScannedItemScreen()),
                                                              )..then((result) {
                                                                print('mao na ni ang result: $result');
                                                                  if (result != null && result == true) {
                                                                    // Data was synced successfully, update the UI counts
                                                                    setState(
                                                                        () {
                                                                      // remainingCount1 = count1;
                                                                      // remainingCount2 = count2;
                                                                      getRemainingItemCount(
                                                                          data[index]['rack_desc'],
                                                                          data[index]['location_id']);
                                                                      getRemainingNfItemCount(
                                                                          data[index]['rack_desc'],
                                                                          data[index]['location_id']);
                                                                    });
                                                                  }
                                                                });
                                                            }
                                                            // },
                                                            ),
                                                        TextButton(
                                                          child: Text("No"),
                                                          onPressed: () {
                                                            animationController.stop();
                                                            setState(() {
                                                              btnSyncClick = false;
                                                              indexClick = index;
                                                            });
                                                            Navigator.of(context).pop();
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  });
                                            } else {
                                              setState(() {
                                                btnSyncClick = false;
                                                indexClick = index;
                                              });
                                              instantMsgModal(
                                                  context,
                                                  Icon(CupertinoIcons.exclamationmark_circle,
                                                    color: Colors.red,
                                                    size: 40,
                                                  ),
                                                  Text("No Connection. Please connect to a network."));
                                            }
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(primary: Colors.green),
                                        child: Row(
                                          children: [
                                            btnSyncClick && indexClick == index
                                                ? AnimatedBuilder(
                                                  animation: animationController,
                                                  child: const Icon(
                                                    CupertinoIcons.arrow_2_circlepath,
                                                    color: Colors.white,
                                                  ),
                                                  builder: (context, child) {
                                                    return Transform.rotate(
                                                      angle: animationController.value * 2 * pi,
                                                      child: child,
                                                    );
                                                  },
                                                )
                                                : Icon(CupertinoIcons.arrow_2_circlepath),
                                            Text(" Sync"),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  )
                : SizedBox(),
          ],
        ),
      ),
    );
  }

  Future _lockUnlockLocation(int index, bool value, bool done) async {
    var user = await _sqfliteDBHelper.selectU(GlobalVariables.logEmpNo);
    await await _sqfliteDBHelper.updateUserAssignAreaWhere(
      "locked = '" + value.toString() + "' , done = '" + done.toString() + "'",
      "emp_no = '${user[0]['emp_no']}' AND location_id = '${GlobalVariables.currentLocationID}'",
    );
    _refreshUserAssignAreaList();
  }

  Future _lockUnlockLocation2(bool value, bool done, String locID) async {
    var user = await _sqfliteDBHelper.selectU(GlobalVariables.logEmpNo);
    await _sqfliteDBHelper.updateUserAssignAreaWhere(
      "locked = '" + value.toString() + "' , done = '" + done.toString() + "'",
      "emp_no = '${user[0]['emp_no']}' AND location_id = '$locID'",
    );
  }

  Future<int> getRemainingItemCount(String rackDesc, String locId) async {
    final db = await _sqfliteDBHelper.database;
    List<Map<String, dynamic>> result = await db.rawQuery(
        "SELECT COUNT(*) as count FROM ${ItemCount.tblItemCount} WHERE exported != 'EXPORTED' AND rack_desc = ? AND location_id = ?",
        [rackDesc, locId] // Correct way to pass parameters
        );
    return result.isNotEmpty ? result.first["count"] as int : 0;
  }

  Future<int> getRemainingNfItemCount(String rackDesc, String locId) async {
    final db = await _sqfliteDBHelper.database;
    List<Map<String, dynamic>> result = await db.rawQuery(
        "SELECT COUNT(*) as count FROM ${ItemNotFound.tblItemNotFound} WHERE exported != 'EXPORTED' AND rack_desc = ? AND location = ?",
        [rackDesc, locId] // Correct way to pass parameters
        );
    return result.isNotEmpty ? result.first["count"] as int : 0;
  }

  _refreshUserAssignAreaList() async {
    _assignArea = [];
    countType = [];
    _assignArea = await _sqfliteDBHelper.selectUserArea(
        GlobalVariables.logEmpNo, GlobalVariables.currentBusinessUnit);
    countType = await _sqfliteDBHelper.getCountTypeDate(
        GlobalVariables.logEmpNo, GlobalVariables.currentBusinessUnit);

    if (_assignArea.length > 0 && countType.length > 0) {
      if (mounted) setState(() {});
    } else {
      var user = int.parse(GlobalVariables.logEmpNo) * 1;
      _assignArea = await _sqfliteDBHelper.selectUserArea(
          user.toString(), GlobalVariables.currentBusinessUnit);
      countType = await _sqfliteDBHelper.getCountTypeDate(
          user.toString(), GlobalVariables.currentBusinessUnit);
      print("mao ni assign area: $_assignArea");
      print("kani ang counttype: $countType");
      print("-------");
      if (mounted) setState(() {});
    }
    if (checkingData) {
      await checkCountItemAssignArea(_assignArea);
    } else {
      checkingData = false;
      this.checking = false;
    }
  }
}
