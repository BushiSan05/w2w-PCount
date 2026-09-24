import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:physicalcountv2/db/models/itemCountModel.dart';
import 'package:physicalcountv2/db/models/itemNotFoundModel.dart';
import 'package:physicalcountv2/db/models/logsModel.dart';
import 'package:physicalcountv2/db/sqfLite_dbHelper.dart';
import 'package:physicalcountv2/services/api.dart';
import 'package:physicalcountv2/syncscreentoserver.dart';
import 'package:physicalcountv2/values/globalVariables.dart';
import 'package:physicalcountv2/widget/instantMsgModal.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'dart:ui' as ui;

import '../../widget/scanRovingITModal.dart';

class SyncScannedItemScreen extends StatefulWidget {
  const SyncScannedItemScreen({Key? key}) : super(key: key);

  @override
  _SyncScannedItemScreenState createState() => _SyncScannedItemScreenState();
}

class _SyncScannedItemScreenState extends State<SyncScannedItemScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<SfSignaturePadState> signatureUserGlobalKey = GlobalKey();
  final GlobalKey<SfSignaturePadState> signatureAuditGlobalKey = GlobalKey();

  late SqfliteDBHelper _sqfliteDBHelper;
  List _myAudit = [];
  List _items = [];
  List _nfitems = [];
  List _auditTrail = [];
  List count_type = [];
  String _auditor = "";
  bool checkingNetwork = false;
  bool btn_sync = false;
  bool btn_close_click = true;
  Logs _log = Logs();
  DateFormat dateFormat = DateFormat("yyyy-MM-dd");
  DateFormat timeFormat = DateFormat("hh:mm:ss aaa");
  bool proceed = true;
  String userSignature = "";
  String auditSignature = "";
  String location = GlobalVariables.currentBusinessUnit;
  String bu = GlobalVariables.currentBusinessUnit.trim();

  bool ags() {
    return bu == 'GLASS SERVICE - TAGBILARAN';
  }

  @override
  void initState() {
    _sqfliteDBHelper = SqfliteDBHelper.instance;
    btn_sync = true;
    btn_close_click = false;
    if (mounted) setState(() {});
    _getMyAudit();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
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
          title: Row(
            children: [
              Flexible(
                child: Material(
                  type: MaterialType.transparency,
                  child: Text(
                    "Sync Count Data to Database",
                    maxLines: 2,
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            checkingNetwork
                ? LinearProgressIndicator(minHeight: 8.0)
                : SizedBox(),
            Spacer(),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "NOTE: \n  Make sure to review all the item before syncing. \n You cannot edit or delete all synced item.",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      fontSize: 23),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            MaterialButton(
              color: btn_sync ? Colors.green : Colors.grey,
              disabledColor: Colors.grey,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.tray_arrow_up_fill,
                      size: 25,
                      color: Colors.white,
                    ),
                    Text(
                      " Start to sync",
                      style: TextStyle(color: Colors.white, fontSize: 25),
                    ),
                  ],
                ),
              ),
              onPressed: () async {
                await scanRovingITModal(context, _sqfliteDBHelper);
                if (GlobalVariables.isRovingITAccess) {
                  GlobalVariables.isRovingITAccess = false;
                  if (btn_sync) {
                    btn_sync = false;
                    var res = await checkConnection();
                    print('RES: $res');
                    if (res == 'connected') {
                      final dataUser = await signatureUserGlobalKey
                          .currentState!
                          .toImage(pixelRatio: 2.0); //3.0
                      final bytesUser = await dataUser.toByteData(
                          format: ui.ImageByteFormat.png);
                      final dataAudit = await signatureAuditGlobalKey
                          .currentState!
                          .toImage(pixelRatio: 2.0); //3.0
                      final bytesAudit = await dataAudit.toByteData(
                          format: ui.ImageByteFormat.png);

                      if (signatureUserGlobalKey.currentState!
                                  .toPathList()
                                  .length ==
                              0 ||
                          signatureAuditGlobalKey.currentState!
                                  .toPathList()
                                  .length ==
                              0) {
                        instantMsgModal(
                            context,
                            Icon(
                              CupertinoIcons.exclamationmark_circle,
                              color: Colors.red,
                              size: 40,
                            ),
                            Text(
                                "User signature and Auditor signature are required to be signed before syncing."));
                        btn_sync = true;
                      } else {
                        userSignature =
                            base64Encode(bytesUser!.buffer.asUint8List());
                        auditSignature =
                            base64Encode(bytesAudit!.buffer.asUint8List());
                        continueSync(
                            base64Encode(bytesUser!.buffer.asUint8List()),
                            base64Encode(bytesAudit!.buffer.asUint8List()));
                      }
                    } else {
                      instantMsgModal(
                          context,
                          Icon(
                            CupertinoIcons.exclamationmark_circle,
                            color: Colors.red,
                            size: 40,
                          ),
                          Text("No Connection. Please connect to a network."));
                      btn_sync = true;
                    }
                    setState(() {});
                  }
                }
              },
            ),
            Spacer(),
            Divider(),
            Row(
              children: [
                Text(
                  "  User Signature",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                TextButton(
                    onPressed: () {
                      signatureUserGlobalKey.currentState!.clear();
                    },
                    child: Text("Clear"))
              ],
            ),
            Padding(
                padding: EdgeInsets.only(right: 8, left: 8),
                child: Container(
                    child: SfSignaturePad(
                      key: signatureUserGlobalKey,
                      strokeColor: Colors.black,
                      minimumStrokeWidth: 1.0,
                      maximumStrokeWidth: 4.0,
                      backgroundColor: Colors.transparent,
                    ),
                    height: 150,
                    width: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      image: DecorationImage(
                        image: AssetImage(
                            "assets/images/signaturepad/guideLine.png"),
                        fit: BoxFit.cover,
                      ),
                    ))),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "${GlobalVariables.logFullName.toUpperCase()}",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Divider(),
            Row(
              children: [
                Text(
                  "  Auditor Signature",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    signatureAuditGlobalKey.currentState!.clear();
                  },
                  child: Text("Clear"),
                ),
              ],
            ),
            Padding(
                padding: EdgeInsets.only(right: 10, left: 10),
                child: Container(
                    child: SfSignaturePad(
                        key: signatureAuditGlobalKey,
                        backgroundColor: Colors.transparent,
                        strokeColor: Colors.black,
                        minimumStrokeWidth: 1.0,
                        maximumStrokeWidth: 4.0),
                    height: 150,
                    width: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      image: DecorationImage(
                        image: AssetImage(
                            "assets/images/signaturepad/guideLine.png"),
                        fit: BoxFit.cover,
                      ),
                    ))),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "$_auditor",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Spacer(),
          ],
        ),
      ),
    );
  }

  _getMyAudit() async {
    _myAudit = [];
    _auditor = "";
    _myAudit = await _sqfliteDBHelper
        .findAuditByLocationId(GlobalVariables.currentLocationID);
    if (_myAudit.length > 0) {
      _auditor = _myAudit[0]['name'].toString().toUpperCase();
    }
    if (mounted) setState(() {});
  }

  tryCatch(String execute, List items) async {
    var timeLimit = const Duration(seconds: 20);
    var res;
    try {
      switch (execute) {
        //----| 1 |------
        case "advance-NF-items":
          res = await syncNfItem_adv(items, userSignature, auditSignature)
              .timeout(timeLimit);
          break;
        //----| 2 |------
        case "advance-count-items":
          ags()
              ? res = await syncAdvCount(items, userSignature, auditSignature, location,)
              .timeout(timeLimit)
              : res = await syncItem_adv(items, userSignature, auditSignature, location)
                  .timeout(timeLimit);
          break;
        //----| 3 |------
        /*case "audit-trail":
          res = await syncAuditTrail(items).timeout(timeLimit);
          break;*/
        //----| 4 |------
        case "actual-NF-items":
          res = await syncNfItem(items, userSignature, auditSignature)
              .timeout(timeLimit);
          break;
        //----| 5 |------
        case "actual-count-items":
          print("ACTUAL COUNT CASE");
          ags()
          ? res = await syncCount(items, userSignature, auditSignature, location,)
              .timeout(timeLimit)
          : res = await syncItem(items, userSignature, auditSignature, location)
              .timeout(timeLimit);
          break;
        //----| 6 |------
        /*case "audit-trail":
          res = await syncAuditTrail(items).timeout(timeLimit);
          break;*/
        //----| 7 |------
        case "NF-Item-freegoods":
          res = await syncNfItem_freegoods(items, userSignature, auditSignature)
              .timeout(timeLimit);
          break;
        //----| 8 |------
        case "count-Item-freegoods":
          res = await syncItem_freegoods(items, userSignature, auditSignature)
              .timeout(timeLimit);
          break;
        //----| 9 |------
        case "audit-trail":
          res = await syncAuditTrail(items, location).timeout(timeLimit);
          break;
      }
      if (GlobalVariables.statusCode == 200) {
        if (res == true) {
          proceed = true;
        } else {
          proceed = false;
          var details = "[ASYNC][Something went wrong, During $execute sync.]";
          var text = "Something went wrong! Please try again Later";
          tryCatchLogs(details, text);
        }
      } else if (GlobalVariables.statusCode >= 400 || res.statusCode <= 499) {
        proceed = false;
        var details =
            "[ASYNC][Error: Client issued a malformed or illegal request, During $execute sync.]";
        var text = "Error: Client issued a malformed or illegal request.";
        tryCatchLogs(details, text);
      } else if (GlobalVariables.statusCode >= 500 || res.statusCode <= 599) {
        proceed = false;
        var details =
            "[ASYNC][Error: Internal server error, During $execute sync.]";
        var text = "Error: Internal server error.";
        tryCatchLogs(details, text);
      }
    } on TimeoutException {
      proceed = false;
      var details = "[ASYNC][Connection is Low, During $execute sync.]";
      var text = "Connection is Low, please try again Later.";
      tryCatchLogs(details, text);
    } on SocketException {
      proceed = false;
      var details = "[ASYNC][Connection is Low, During $execute sync.]";
      var text = "Connection is Low, please try again Later.";
      tryCatchLogs(details, text);
    } on HttpException {
      proceed = false;
      var details =
          "[ASYNC][Error: An HTTP error occurred, During $execute sync.]";
      var text = "Error: An HTTP error occurred. Please try again later.";
      tryCatchLogs(details, text);
    } on FormatException {
      proceed = false;
      print("ERROR :: $FormatException");
      var details =
          "[ASYNC][Error: Format exception error occurred. During $execute sync.]";
      var text =
          "Error: Format exception error occurred. Please try again later.";
      tryCatchLogs(details, text);
    }
  }

  tryCatchLogs(String details, String text) async {
    _log.date = dateFormat.format(DateTime.now());
    _log.time = timeFormat.format(DateTime.now());
    _log.device =
        "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
    _log.user = GlobalVariables.logFullName;
    _log.empid = GlobalVariables.logEmpNo;
    _log.details = details;
    await _sqfliteDBHelper.insertLog(_log);
    Navigator.of(context).pop();
    instantMsgModal(
        context,
        Icon(
          CupertinoIcons.exclamationmark_circle,
          color: Colors.red,
          size: 40,
        ),
        Text(text));
  }

  continueSync(String bytesUser, String bytesAudit) async {
    var timeLimit = const Duration(seconds: 5);
    print(GlobalVariables.currentLocationID);
    checkingNetwork = true;
    if (mounted) setState(() {});
    var res = await checkConnection();
//-------------------CONNECTION CHECK!-----------------------
    if (res == 'error') {
      checkingNetwork = false;
      if (mounted) setState(() {});
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
      checkingNetwork = false;
      if (mounted) setState(() {});
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
        await _getCountedItems();
        await _getCountedNfItems();
        await _getAuditTrail();
        await _getCountType();
        print('COUNT TYPE: ${count_type[0]['countType']}');
//-----------------ADVANCE-----------------------
        //NF ITEMS//
        if (count_type[0]['countType'] == 'ADVANCE') {
          if (_nfitems.length == 0 && _items.length == 0) {
            checkingNetwork = false;
            if (mounted) setState(() {});
            instantMsgModal(
                context,
                Icon(
                  CupertinoIcons.exclamationmark_circle,
                  color: Colors.red,
                  size: 40,
                ),
                Text("No data to sync."));
            btn_sync = true;
          } else {
            if (_nfitems.length > 0 && proceed) {
              print("NF ITEMS :: $_nfitems");
              //-------------try catch here 1--------------------
              await tryCatch("advance-NF-items", _nfitems);
              //-------------try catch end here 1--------------------
              if (proceed) {
                await _sqfliteDBHelper.updateItemNotFoundByLocation(
                    GlobalVariables.currentLocationID, "exported = 'EXPORTED'");
                _log.date = dateFormat.format(DateTime.now());
                _log.time = timeFormat.format(DateTime.now());
                _log.device =
                    "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
                _log.user = GlobalVariables.logFullName;
                _log.empid = GlobalVariables.logEmpNo;
                _log.details =
                    "[SYNCED][USER Synced Not Found Item on Location ID: ${GlobalVariables.currentLocationID}]";
                await _sqfliteDBHelper.insertLog(_log);
              }
            }
            //COUNT
            if (_items.length > 0 && proceed) {
              //-------------try catch here 2--------------------
              await tryCatch("advance-count-items", _items);
              //-------------try catch end here 2--------------------
              if (proceed) {
                await _sqfliteDBHelper.updateItemCountByLocation(
                    GlobalVariables.currentLocationID, "exported = 'EXPORTED'");
                _log.date = dateFormat.format(DateTime.now());
                _log.time = timeFormat.format(DateTime.now());
                _log.device =
                    "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
                _log.user = GlobalVariables.logFullName;
                _log.empid = GlobalVariables.logEmpNo;
                _log.details =
                    "[SYNCED][USER Synced Count Item on Location ID: ${GlobalVariables.currentLocationID}]";
                await _sqfliteDBHelper.insertLog(_log);
              }
            }
            if (_auditTrail.length > 0 && proceed) {
              //-------------try catch here 3--------------------
              await tryCatch("audit-trail", _auditTrail);
              //-------------try catch end here 3--------------------
              if (proceed) {
                checkingNetwork = false;
                if (mounted)
                  setState(() {
                    // Navigator.pop(context);
                  });
                await _sqfliteDBHelper.updateTblAuditTrail();
                if (btn_close_click) {
                  btn_close_click = false;
                  Navigator.of(context).pop();
                }
                Navigator.of(context).pop(true);
                instantMsgModal(
                    context,
                    Icon(
                      CupertinoIcons.checkmark_alt_circle,
                      color: Colors.green,
                      size: 40,
                    ),
                    Text("Data successfully synced."));
                _log.details =
                    "[SYNCED][Location ${GlobalVariables.currentLocationID} has been synced.]";
                await _sqfliteDBHelper.insertLog(_log);
              }
            }
          }

//----------------------ACTUAL------------------------------
        } else if (count_type[0]['countType'] == 'ACTUAL') {
          if (_nfitems.length == 0 && _items.length == 0) {
            checkingNetwork = false;
            if (mounted)
              setState(() {
                // Navigator.pop(context);
              });
            instantMsgModal(
                context,
                Icon(
                  CupertinoIcons.exclamationmark_circle,
                  color: Colors.red,
                  size: 40,
                ),
                Text("No data to sync."));
            btn_sync = true;
            return;
          } else {
            if (_nfitems.length > 0 && proceed) {
              //-------------try catch here 4--------------------
              await tryCatch("actual-NF-items", _nfitems);
              //-------------try catch end here 4--------------------
              if (proceed) {
                await _sqfliteDBHelper.updateItemNotFoundByLocation(
                    GlobalVariables.currentLocationID, "exported = 'EXPORTED'");
                _log.date = dateFormat.format(DateTime.now());
                _log.time = timeFormat.format(DateTime.now());
                _log.device =
                    "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
                _log.user = GlobalVariables.logFullName;
                _log.empid = GlobalVariables.logEmpNo;
                _log.details =
                    "[SYNCED][USER Synced Not Found Item on Location ID: ${GlobalVariables.currentLocationID}]";
                await _sqfliteDBHelper.insertLog(_log);
              }
            }
            //COUNT
            if (_items.length > 0 && proceed) {
              //-------------try catch here 5--------------------
              print("ACTUAL ITEMS :: $_items");
              await tryCatch("actual-count-items", _items);
              //-------------try catch end here 5--------------------
              if (proceed) {
                await _sqfliteDBHelper.updateItemCountByLocation(
                    GlobalVariables.currentLocationID, "exported = 'EXPORTED'");

                _log.date = dateFormat.format(DateTime.now());
                _log.time = timeFormat.format(DateTime.now());
                _log.device =
                    "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
                _log.user = GlobalVariables.logFullName;
                _log.empid = GlobalVariables.logEmpNo;
                _log.details =
                    "[SYNCED][USER Synced Count Item on Location ID: ${GlobalVariables.currentLocationID}]";
                await _sqfliteDBHelper.insertLog(_log);
              }
            }
            if (_auditTrail.length > 0 && proceed) {
              //-------------try catch here 6--------------------
              await tryCatch("audit-trail", _auditTrail);
              //-------------try catch end here 6--------------------
              if (proceed) {
                checkingNetwork = false;
                if (mounted)
                  setState(() {
                    // Navigator.pop(context);
                  });
                await _sqfliteDBHelper.updateTblAuditTrail();
                if (btn_close_click) {
                  btn_close_click = false;
                  Navigator.of(context).pop();
                }
                Navigator.of(context).pop(true);
                instantMsgModal(
                    context,
                    Icon(
                      CupertinoIcons.checkmark_alt_circle,
                      color: Colors.green,
                      size: 40,
                    ),
                    Text("Data successfully synced."));
                _log.details = "[SYNCED][Location ${GlobalVariables.currentLocationID} has been synced.]";
                await _sqfliteDBHelper.insertLog(_log);
              } else {
                checkingNetwork = false;
                if (mounted) setState(() {});
                instantMsgModal(
                    context,
                    Icon(
                      CupertinoIcons.exclamationmark_circle,
                      color: Colors.red,
                      size: 40,
                    ),
                    Text("Something went wrong."));
                btn_sync = true;
              }
            } else {
              checkingNetwork = false;
              if (mounted) setState(() {});
              instantMsgModal(
                  context,
                  Icon(
                    CupertinoIcons.exclamationmark_circle,
                    color: Colors.red,
                    size: 40,
                  ),
                  Text("No data to sync."));
              btn_sync = true;
              return;
            }
          }

//-------------------FREE GOODS------------------------
        } else {
          if (_nfitems.length == 0 && _items.length == 0) {
            checkingNetwork = false;
            if (mounted) setState(() {});
            instantMsgModal(
                context,
                Icon(
                  CupertinoIcons.exclamationmark_circle,
                  color: Colors.red,
                  size: 40,
                ),
                Text("No data to sync."));
            btn_sync = true;
          } else {
            if (_nfitems.length > 0 && proceed) {
              //-------------try catch here 7--------------------
              await tryCatch("NF-Item-freegoods", _nfitems);
              //-------------try catch end here 7--------------------
              if (proceed) {
                await _sqfliteDBHelper.updateItemNotFoundByLocation(
                    GlobalVariables.currentLocationID, "exported = 'EXPORTED'");
                _log.date = dateFormat.format(DateTime.now());
                _log.time = timeFormat.format(DateTime.now());
                _log.device =
                    "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
                _log.user = GlobalVariables.logFullName;
                _log.empid = GlobalVariables.logEmpNo;
                _log.details =
                    "[SYNCED][USER Synced Not Found Item on Location ID: ${GlobalVariables.currentLocationID}]";
                await _sqfliteDBHelper.insertLog(_log);
              }
            }
            //COUNT
            if (_items.length > 0 && proceed) {
              //-------------try catch here 8--------------------
              await tryCatch("count-Item-freegoods", _items);
              //-------------try catch end here 8--------------------
              if (proceed) {
                await _sqfliteDBHelper.updateItemCountByLocation(
                    GlobalVariables.currentLocationID, "exported = 'EXPORTED'");
                _log.date = dateFormat.format(DateTime.now());
                _log.time = timeFormat.format(DateTime.now());
                _log.device =
                    "${GlobalVariables.deviceInfo}(${GlobalVariables.readdeviceInfo})";
                _log.user = GlobalVariables.logFullName;
                _log.empid = GlobalVariables.logEmpNo;
                _log.details =
                    "[SYNCED][USER Synced Count Item on Location ID: ${GlobalVariables.currentLocationID}]";
                await _sqfliteDBHelper.insertLog(_log);
              }
            }
            if (_auditTrail.length > 0 && proceed) {
              //-------------try catch here 9--------------------
              await tryCatch("audit-trail", _auditTrail);
              //-------------try catch end here 9--------------------
              if (proceed) {
                checkingNetwork = false;
                if (mounted) setState(() {});
                await _sqfliteDBHelper.updateTblAuditTrail();
                if (btn_close_click) {
                  btn_close_click = false;
                  Navigator.of(context).pop();
                }
                Navigator.of(context).pop(true);
                instantMsgModal(
                    context,
                    Icon(
                      CupertinoIcons.checkmark_alt_circle,
                      color: Colors.green,
                      size: 40,
                    ),
                    Text("Data successfully synced."));
                _log.details =
                    "[SYNCED][Location ${GlobalVariables.currentLocationID} has been synced.]";
                await _sqfliteDBHelper.insertLog(_log);
              } else {
                checkingNetwork = false;
                if (mounted) setState(() {});
                instantMsgModal(
                    context,
                    Icon(
                      CupertinoIcons.exclamationmark_circle,
                      color: Colors.red,
                      size: 40,
                    ),
                    Text("Something went wrong."));
                btn_sync = true;
              }
            } else {
              checkingNetwork = false;
              if (mounted) setState(() {});
              instantMsgModal(
                  context,
                  Icon(
                    CupertinoIcons.exclamationmark_circle,
                    color: Colors.red,
                    size: 40,
                  ),
                  Text("No data to sync."));
              btn_sync = true;
              return;
            }
          }
        }
      }
    }
  }

  _getCountedItems() async {
    _items = await _sqfliteDBHelper.selectItemCountRawQuery(
        "SELECT itemcode, barcode, image, desc, description, uom, lot_number, expiry, qty, company, business_unit, department, section, rack_desc, datetimecreated, datetimesaved, location_id, conqty FROM ${ItemCount.tblItemCount} WHERE empno = '${GlobalVariables.logEmpNo}' AND company = '${GlobalVariables.currentCompany}' AND business_unit = '${GlobalVariables.currentBusinessUnit}' AND department = '${GlobalVariables.currentDepartment}' AND section  = '${GlobalVariables.currentSection}' AND rack_desc  = '${GlobalVariables.currentRackDesc}' AND location_id = '${GlobalVariables.currentLocationID}' AND exported != 'EXPORTED'");
    print("ITEMS :: $_items");
    print('mao nig company: ${GlobalVariables.currentCompany}');
  }

  _getCountedNfItems() async {
    _nfitems = await _sqfliteDBHelper.selectItemNotFoundRawQuery(
        "SELECT barcode, inputted_description, itemcode, uom, qty, location, datetimecreated, company, business_unit, department, section, empno, rack_desc, description FROM ${ItemNotFound.tblItemNotFound} WHERE empno = '${GlobalVariables.logEmpNo}' AND business_unit = '${GlobalVariables.currentBusinessUnit}' AND department = '${GlobalVariables.currentDepartment}' AND section  = '${GlobalVariables.currentSection}' AND rack_desc  = '${GlobalVariables.currentRackDesc}' AND location = '${GlobalVariables.currentLocationID}' AND exported != 'EXPORTED'");
  }

  _getCountType() async {
    count_type =
        await _sqfliteDBHelper.getCountType(GlobalVariables.currentLocationID);
  }

  _getAuditTrail() async {
    _auditTrail = await _sqfliteDBHelper.getAuditTrail();
  }
}
