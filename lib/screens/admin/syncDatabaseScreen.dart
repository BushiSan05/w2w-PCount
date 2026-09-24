import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:intl/intl.dart';
import 'package:physicalcountv2/db/models/logsModel.dart';
import 'package:physicalcountv2/db/sqfLite_dbHelper.dart';
import 'package:physicalcountv2/screens/admin/syncDoneScreen.dart';
import 'package:physicalcountv2/services/api.dart';
import 'package:physicalcountv2/services/server_url.dart';
import 'package:physicalcountv2/services/server_url_list.dart';
import 'package:physicalcountv2/values/globalVariables.dart';
import 'package:physicalcountv2/widget/instantMsgModal.dart';

class SyncDatabaseScreen extends StatefulWidget {
  final user;
  final id;
  const SyncDatabaseScreen({Key? key, required this.user, required this.id})
      : super(key: key);
  @override
  _SyncDatabaseScreenState createState() => _SyncDatabaseScreenState();
}

class _SyncDatabaseScreenState extends State<SyncDatabaseScreen>
    with SingleTickerProviderStateMixin {
  ServerUrl su = ServerUrl();
  // ServerUrlList sul = ServerUrlList();
  late AnimationController animationController;
  List tables = [
    {
      'tbName': 'User Masterfile',
      'status': '',
      'truncate': true,
      'selected': true
    },
    {
      'tbName': 'Audit Masterfile',
      'status': '',
      'truncate': true,
      'selected': true
    },
    {
      'tbName': 'Location Masterfile',
      'status': '',
      'truncate': true,
      'selected': true
    },
    {
      'tbName': 'Item Masterfile',
      'status': '',
      'truncate': true,
      'selected': false
    },
    {'tbName': 'Filters', 'status': '', 'truncate': true, 'selected': true},
    // {'tbName': 'Item Count', 'status': '', 'truncate': false, 'selected': true}
  ];

  NumberFormat nF = NumberFormat("###,###", "en_US");
  int userMasterfileCount = 0;
  int auditMastefileCount = 0;
  int locationMasterfileCount = 0;
  int itemMasterfileCount = 0;
  int filterMasterfileCount = 0;
  late SqfliteDBHelper _sqfliteDBHelper;
  DateFormat dateFormat = DateFormat("yyyy-MM-dd");
  DateFormat timeFormat = DateFormat("hh:mm:ss aaa");
  bool checkingNetwork = false;
  List userMasterfileData = [];
  List auditMasterfileData = [];
  List locationMasterfileData = [];
  List itemMasterfileData = [];
  List filter = [];
  List dunit = [];
  Logs _log = Logs();
  bool btn_sync = false;
  bool btn_close_click = true;
  bool is_syncing = false;
  String assignedBu = GlobalVariables.currentBusinessUnit;

  @override
  void initState() {
    _sqfliteDBHelper = SqfliteDBHelper.instance;
    btn_sync = true;
    btn_close_click = false;
    if (mounted) setState(() {});
    animationController = new AnimationController(
      vsync: this,
      duration: new Duration(seconds: 7),
    );
    animationController.repeat();
    super.initState();
    print('mao nig current server ${ServerUrl.current}');
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
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
          leading: IconButton(
              icon: Icon(Icons.close, color: Colors.red),
              onPressed: () {
                if (!btn_sync) {
                  btn_close_click = true;
                  showDialog(
                      barrierDismissible: false,
                      context: context,
                      builder: (BuildContext context) {
                        return CupertinoAlertDialog(
                          title: Text("Syncing ongoing"),
                          content: Text("Continue to Close?"),
                          actions: <Widget>[
                            TextButton(
                              child: Text("Yes"),
                              onPressed: () {
                                is_syncing = false;
                                btn_close_click = false;
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                              },
                            ),
                            TextButton(
                              child: Text("No"),
                              onPressed: () {
                                Navigator.of(context).pop();
                                btn_close_click = false;
                              },
                            ),
                          ],
                        );
                      });
                } else {
                  Navigator.of(context).pop();
                }
              }),
          title: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              "Sync Database",
              style: TextStyle(color: Colors.blue),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Center(
                child: Text(
                  "${GlobalVariables.currentBusinessUnit}",
                  style: TextStyle(
                      color: Colors.black), // Customize the style as needed
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              checkingNetwork ? LinearProgressIndicator() : SizedBox(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  height: 35,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            Center(
                                child: Text(" Legend:   ",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            Center(
                                child: Icon(
                              CupertinoIcons.ellipsis_circle,
                              color: Colors.red,
                            )),
                            Center(child: Text(" -Waiting   ")),
                            Center(
                                child: Icon(CupertinoIcons.arrow_2_circlepath,
                                    color: Colors.blue)),
                            Center(child: Text(" -Syncing   ")),
                            Center(
                                child: Icon(
                                    CupertinoIcons.checkmark_alt_circle_fill,
                                    color: Colors.green)),
                            Center(child: Text(" -Sync Finished   ")),
                            Center(
                                child: Icon(CupertinoIcons.capsule_fill,
                                    color: Colors.green)),
                            Center(child: Text(" -Truncate Table (On/Off)")),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: tables.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Checkbox(
                              value: tables[index]['selected'],
                              onChanged: is_syncing
                                  ? null
                                  : (val) {
                                      if (val!) {
                                        tables[index]['selected'] = true;
                                      } else {
                                        tables[index]['selected'] = false;
                                      }
                                      if (mounted) setState(() {});
                                    }),
                          FittedBox(
                            child: Text(
                              tables[index]['tbName'] + " - ",
                              style: TextStyle(fontSize: 30),
                            ),
                          ),
                          FittedBox(
                            child: tables[index]['status'] == ""
                                ? Icon(CupertinoIcons.ellipsis_circle,
                                    color: Colors.transparent)
                                : tables[index]['status'] == "waiting"
                                    ? Icon(CupertinoIcons.ellipsis_circle,
                                        color: Colors.red)
                                    : tables[index]['status'] == "queue"
                                        ? AnimatedBuilder(
                                            animation: animationController,
                                            child: Icon(
                                                CupertinoIcons
                                                    .arrow_2_circlepath,
                                                color: Colors.blue),
                                            builder: (BuildContext context,
                                                Widget? _widget) {
                                              return new Transform.rotate(
                                                angle:
                                                    animationController.value *
                                                        40,
                                                child: _widget,
                                              );
                                            },
                                          )
                                        : Icon(
                                            CupertinoIcons
                                                .checkmark_alt_circle_fill,
                                            color: Colors.green),
                          ),
                          tables[index]['tbName'] == 'User Masterfile'
                              ? Text(
                                  "${nF.format(userMasterfileCount)} record(s) synced.")
                              // ? Text("${_calculatePercentage(userMasterfileCount)}% synced")
                              : SizedBox(),
                          tables[index]['tbName'] == 'Audit Masterfile'
                              ? Text(
                                  "${nF.format(auditMastefileCount)} record(s) synced.")
                              // ? Text("${_calculatePercentage(auditMastefileCount)}% synced")
                              : SizedBox(),
                          tables[index]['tbName'] == 'Location Masterfile'
                              ? Text(
                                  "${nF.format(locationMasterfileCount)} record(s) synced.",
                                  style: TextStyle(fontSize: 12.0))
                              // ? Text("${_calculatePercentage(locationMasterfileCount)}% synced", style: TextStyle(fontSize: 12.0))
                              : SizedBox(),
                          tables[index]['tbName'] == 'Item Masterfile'
                              ? Text(
                                  "${nF.format(itemMasterfileCount)} record(s) synced.")
                              // ? Text("${_calculatePercentage(itemMasterfileCount)}% synced")
                              : SizedBox(),
                          tables[index]['tbName'] == 'Filters'
                              ? Text(
                                  "${nF.format(filterMasterfileCount)} record(s) synced.")
                              // ? Text("${_calculatePercentage(filterMasterfileCount)}% synced")
                              : SizedBox(),
                          Spacer(),
                          FlutterSwitch(
                            activeColor:
                                is_syncing ? Colors.grey : Colors.green,
                            width: 95.0,
                            height: 40.0,
                            valueFontSize: 20.0,
                            toggleSize: 30.0,
                            value: tables[index]['truncate'],
                            borderRadius: 30.0,
                            padding: 8.0,
                            showOnOff: true,
                            onToggle: is_syncing
                                ? ((_) {})
                                : (val) {
                                    tables[index]['truncate'] = val;
                                    if (mounted) setState(() {});
                                  },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              MaterialButton(
                minWidth: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height / 15,
                color: btn_sync ? Colors.blue : Colors.grey,
                disabledColor: Colors.grey,
                child: Text(
                  "Start Syncing",
                  style: TextStyle(fontSize: 25, color: Colors.white),
                ),
                onPressed: () async {
                  if (btn_sync) {
                    btn_sync = false;
                    checkingNetwork = true;
                    if (mounted) setState(() {});
                    var res = await checkConnection();
                    checkingNetwork = false;
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
                      btn_sync = true;
                    } else if (res == 'errornet') {
                      instantMsgModal(
                          context,
                          Icon(
                            CupertinoIcons.exclamationmark_circle,
                            color: Colors.red,
                            size: 40,
                          ),
                          Text("${GlobalVariables.httpError}"));
                      btn_sync = true;
                    } else {
                      if (res == 'connected') {
                        showDialog(
                            barrierDismissible: false,
                            context: context,
                            builder: (BuildContext context) {
                              return CupertinoAlertDialog(
                                title: Text(
                                    "${GlobalVariables.currentBusinessUnit} Server"),
                                content:
                                    Text("Continue to Sync in this Server?"),
                                actions: <Widget>[
                                  TextButton(
                                    child: Text("Yes"),
                                    onPressed: () async {
                                      var res = await checkConnection();
                                      if (res == 'connected') {
                                        continueSync();
                                        Navigator.of(context).pop();
                                      } else {
                                        Navigator.of(context).pop();
                                        btn_sync = true;
                                        instantMsgModal(
                                            context,
                                            Icon(
                                              CupertinoIcons
                                                  .exclamationmark_circle,
                                              color: Colors.red,
                                              size: 40,
                                            ),
                                            Text(
                                                "${GlobalVariables.httpError}"));
                                      }
                                    },
                                  ),
                                  TextButton(
                                    child: Text("No"),
                                    onPressed: () {
                                      btn_sync = true;
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              );
                            });
                      } else {
                        btn_sync = true;
                      }
                      // setState(() {
                      //   btn_sync =true;
                      // });
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  continueSync() async {
    is_syncing = true;
    if (!is_syncing) return;
    tables.forEach((element) {
      if (element['selected'] == true) element['status'] = "waiting";
    });
    if (mounted) setState(() {});
//------------------USER MASTERFILE------------------//
    if (!is_syncing) return;
    if (tables[0]['selected'] == true) {
      if (!is_syncing) return;
      if (tables[0]['truncate'] == true) {
        if (!is_syncing) return;
        await _sqfliteDBHelper.deleteUserAll();
        _log.date = dateFormat.format(DateTime.now());
        _log.time = timeFormat.format(DateTime.now());
        _log.device =
            "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
        _log.user = "${widget.user}";
        _log.empid = "${widget.id}";
        _log.details = "[SYNC][User Masterfile Truncate]";
        await _sqfliteDBHelper.insertLog(_log);
      }
      if (!is_syncing) return;
      tables[0]['status'] = "queue";
      if (mounted) setState(() {});
      userMasterfileData = await getUserMasterfile();
      if (!is_syncing) return;
      await _sqfliteDBHelper.insertUserBatch(
          userMasterfileData, 0, userMasterfileData.length);
      if (!is_syncing) return;
      userMasterfileCount = userMasterfileCount + userMasterfileData.length;
      if (mounted) setState(() {});
      tables[0]['status'] = "done";
      if (mounted) setState(() {});
      //logs
      _log.date = dateFormat.format(DateTime.now());
      _log.time = timeFormat.format(DateTime.now());
      _log.device =
          "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
      _log.user = "${widget.user}";
      _log.empid = "${widget.id}";
      _log.details = "[SYNC][User Masterfile]";
      await _sqfliteDBHelper.insertLog(_log);
    }
//------------------USER MASTERFILE------------------//

//------------------AUDIT MASTERFILE------------------//
    if (!is_syncing) return;
    if (tables[1]['selected'] == true) {
      if (!is_syncing) return;
      if (tables[1]['truncate'] == true) {
        if (!is_syncing) return;
        await _sqfliteDBHelper.deleteAuditAll();
        _log.date = dateFormat.format(DateTime.now());
        _log.time = timeFormat.format(DateTime.now());
        _log.device =
            "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
        _log.user = "${widget.user}";
        _log.empid = "${widget.id}";
        _log.details = "[SYNC][Audit Masterfile Truncate]";
        await _sqfliteDBHelper.insertLog(_log);
      }
      if (!is_syncing) return;
      tables[1]['status'] = "queue";
      if (mounted) setState(() {});
      auditMasterfileData = await getAuditMasterfile();
      if (!is_syncing) return;
      await _sqfliteDBHelper.insertAuditBatch(
          auditMasterfileData, 0, auditMasterfileData.length);
      if (!is_syncing) return;
      auditMastefileCount = auditMastefileCount + auditMasterfileData.length;
      if (mounted) setState(() {});
      tables[1]['status'] = "done";
      if (mounted) setState(() {});
      _log.date = dateFormat.format(DateTime.now());
      _log.time = timeFormat.format(DateTime.now());
      _log.device =
          "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
      _log.user = "${widget.user}";
      _log.empid = "${widget.id}";
      _log.details = "[SYNC][Audit Masterfile]";
      await _sqfliteDBHelper.insertLog(_log);
    }
//------------------AUDIT MASTERFILE------------------//

//------------------LOCATION MASTERFILE------------------//
    if (!is_syncing) return;
    if (tables[2]['selected'] == true) {
      if (!is_syncing) return;
      if (tables[2]['truncate'] == true) {
        if (!is_syncing) return;
        await _sqfliteDBHelper.deleteLocationAll();
        _log.date = dateFormat.format(DateTime.now());
        _log.time = timeFormat.format(DateTime.now());
        _log.device =
            "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
        _log.user = "${widget.user}";
        _log.empid = "${widget.id}";
        _log.details = "[SYNC][Location Masterfile Truncate]";
        await _sqfliteDBHelper.insertLog(_log);
      }
      if (!is_syncing) return;
      tables[2]['status'] = "queue";
      if (mounted) setState(() {});
      locationMasterfileData = await getLocationMasterfile();
      if (!is_syncing) return;
      await _sqfliteDBHelper.insertLocationBatch(
          locationMasterfileData, 0, locationMasterfileData.length);
      if (!is_syncing) return;
      locationMasterfileCount =
          locationMasterfileCount + locationMasterfileData.length;
      if (mounted) setState(() {});
      tables[2]['status'] = "done";
      if (mounted) setState(() {});
      _log.date = dateFormat.format(DateTime.now());
      _log.time = timeFormat.format(DateTime.now());
      _log.device =
          "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
      _log.user = "${widget.user}";
      _log.empid = "${widget.id}";
      _log.details = "[SYNC][Location Masterfile]";
      await _sqfliteDBHelper.insertLog(_log);
    }
//------------------LOCATION MASTERFILE------------------//

//------------------ITEM MASTERFILE------------------//
    if (!is_syncing) return;
    if (tables[3]['selected'] == true) {
      if (!is_syncing) return;
      if (tables[3]['truncate'] == true) {
        if (!is_syncing) return;
        await _sqfliteDBHelper.deleteItemAll();
        _log.date = dateFormat.format(DateTime.now());
        _log.time = timeFormat.format(DateTime.now());
        _log.device =
            "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
        _log.user = "${widget.user}";
        _log.empid = "${widget.id}";
        _log.details = "[SYNC][Item Masterfile Truncate]";
        await _sqfliteDBHelper.insertLog(_log);
      }
      if (!is_syncing) return;
      tables[3]['status'] = "queue";
      if (mounted) setState(() {});
      var floop = 0;
      var rsp = await getItemMasterfileCount(assignedBu.toString());
      if (!is_syncing) return;
      var loop = rsp / 50000;
      if ((loop % 1) == 0) {
        //integer
        floop = loop.toInt();
      } else {
        //double
        floop = loop.toInt() + 1;
      }
      int offset = 0;
      for (var i = 0; i < floop; i++) {
        itemMasterfileData = await getItemMasterfileOffset(
            offset.toString(), assignedBu.toString());
        if (!is_syncing) return;
        // print('getItemMasterfileOffset $itemMasterfileData');
        await _sqfliteDBHelper.insertItemBatch(
            itemMasterfileData, 0, itemMasterfileData.length);
        if (!is_syncing) return;
        offset = offset + 50000;
        itemMasterfileCount = itemMasterfileCount + itemMasterfileData.length;
        if (mounted) setState(() {});
      }
      tables[3]['status'] = "done";
      if (mounted) setState(() {});
      _log.date = dateFormat.format(DateTime.now());
      _log.time = timeFormat.format(DateTime.now());
      _log.device =
          "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
      _log.user = "${widget.user}";
      _log.empid = "${widget.id}";
      _log.details = "[SYNC][Item Masterfile]";
      await _sqfliteDBHelper.insertLog(_log);
    }
//------------------ITEM MASTERFILE------------------//

//------------------FILTERS------------------//
    if (!is_syncing) return;
    if (tables[4]['selected'] == true) {
      if (!is_syncing) return;
      if (tables[4]['truncate'] == true) {
        if (!is_syncing) return;
        await _sqfliteDBHelper.deleteFilterAll();
        _log.date = dateFormat.format(DateTime.now());
        _log.time = timeFormat.format(DateTime.now());
        _log.device =
            "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
        _log.user = "${widget.user}";
        _log.empid = "${widget.id}";
        _log.details = "[SYNC][Filters Truncate]";
        await _sqfliteDBHelper.insertLog(_log);
      }
      if (!is_syncing) return;
      tables[4]['status'] = "queue";
      if (mounted) setState(() {});
      filter = await getFilteredItemMasterfile();
      if (!is_syncing) return;
      // print('FILTER :  $filter');
      await _sqfliteDBHelper.insertFilterBatch(filter, 0, filter.length);
      if (!is_syncing) return;
      //unit
      // print(filter);
      await _sqfliteDBHelper.deleteUnitAll();
      if (!is_syncing) return;
      dunit = await getUnit(
          filter[0]['byCategory'] == 'True' ? 'True' : 'False',
          filter[0]['categoryName']);
      if (!is_syncing) return;
      // print('GET UNIsssssssT:');
      // print('GET UNIT: $dunit');
      await _sqfliteDBHelper.insertUnitBatch(dunit, 0, dunit.length);
      //unit
      filterMasterfileCount = filterMasterfileCount + filter.length;
      if (!is_syncing) return;
      if (mounted) setState(() {});

      tables[4]['status'] = "done";
      if (mounted) setState(() {});
      _log.date = dateFormat.format(DateTime.now());
      _log.time = timeFormat.format(DateTime.now());
      _log.device =
          "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
      _log.user = "${widget.user}";
      _log.empid = "${widget.id}";
      _log.details = "[SYNC][Filters]";
      await _sqfliteDBHelper.insertLog(_log);
    }
//------------------FILTERS------------------//

//------------------ITEMCOUNT------------------//
//     if (tables[5]['selected'] == true) {
//       if (tables[5]['truncate'] == true) {
//         tables[5]['status'] = "queue";
//         if (mounted) setState(() {});
//         //await _sqfliteDBHelper.deleteItemCountAll();
//         tables[5]['status'] = "done";
//         if (mounted) setState(() {});
//         _log.date   = dateFormat.format(DateTime.now());
//         _log.time   = timeFormat.format(DateTime.now());
//         _log.device = "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
//         _log.user   = "${widget.user}";
//         _log.empid  = "${widget.id}";
//         _log.details = "[SYNC][Item Count Truncate]";
//         await _sqfliteDBHelper.insertLog(_log);
//       }
//     }
//------------------ITEMCOUNT------------------//
    if (tables[0]['selected'] == true ||
        tables[1]['selected'] == true ||
        tables[2]['selected'] == true ||
        tables[3]['selected'] == true ||
        tables[4]['selected'] == true ||
        tables[5]['selected'] == true) {
      if (btn_close_click) {
        btn_close_click = false;
        Navigator.of(context).pop();
      }
      is_syncing = false;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SyncDoneScreen()),
      );
    } else {
      instantMsgModal(
          context,
          Icon(
            CupertinoIcons.exclamationmark_circle,
            color: Colors.red,
            size: 40,
          ),
          Text("No masterfile to sync"));
      is_syncing = false;
      btn_sync = true;
    }
  }
}
