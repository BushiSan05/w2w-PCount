import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:marquee/marquee.dart';
import 'package:open_filex/open_filex.dart';
import 'package:physicalcountv2/db/models/itemCountModel.dart';
import 'package:physicalcountv2/db/models/logsModel.dart';
import 'package:physicalcountv2/db/sqfLite_dbHelper.dart';
import 'package:physicalcountv2/screens/user/barcodeInputSearch.dart';
import 'package:physicalcountv2/screens/user/itemNotFoundScanScreen.dart';
import 'package:physicalcountv2/screens/user/itemScannedListScreen.dart';
import 'package:physicalcountv2/values/globalVariables.dart';
import 'package:physicalcountv2/widget/customLogicalModal.dart';
import 'package:physicalcountv2/widget/instantMsgModal.dart';
import 'package:physicalcountv2/widget/itemNofFoundModal.dart';
import 'package:physicalcountv2/widget/scanAuditModal.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../db/models/itemNotFoundModel.dart';
import '../../widget/saveNotFoundBarcode.dart';
import '../../widget/saveNotFoundItemModal.dart';
import 'package:image/image.dart' as img;

class ItemScanningScreen extends StatefulWidget {
  const ItemScanningScreen({Key? key}) : super(key: key);
  @override
  _ItemScanningScreenState createState() => _ItemScanningScreenState();
}

class _ItemScanningScreenState extends State<ItemScanningScreen> {
  late FocusNode myFocusNodeBarcode;
  late FocusNode myFocusNodeLotno;
  late FocusNode myFocusNodeQty;
  final barcodeController = TextEditingController();
  final lotnoController = TextEditingController();
  final qtyController = TextEditingController();
  final auditIDController = TextEditingController();
  List units = [];
  List<ItemNotFound> itemNotFound = [];
  bool btnSaveEnabled = false;
  String itemCode = "";
  String itemDescription = "";
  String desc = "";
  String itemUOM = "";
  int convQty = 0;
  String dtItemScanned = "";
  ItemCount _itemCount = ItemCount();
  late SqfliteDBHelper _sqfliteDBHelper;
  Logs _log = Logs();
  DateFormat dateFormat = DateFormat("yyyy-MM-dd");
  DateFormat timeFormat = DateFormat("HH:mm:ss");
  List<ItemCount> _items = [];
  List<ItemNotFound> _nfitems = [];
  DateTime? selectedDate;
  final validCharacters = RegExp(r'^[0-9]+$');
  bool _loading = true;
  String bu = GlobalVariables.currentBusinessUnit.trim();
  bool _isProcessingImage = false;
  File? _imageFile;

  String get _locationTitle {
    final rack = GlobalVariables.currentRackDesc.trim();

    return rack.isEmpty ? 'Rack' : rack;
  }

  String get _locationSubtitle {
    return
        // '${GlobalVariables.currentCompany} / '
        '${GlobalVariables.currentBusinessUnit} / '
        '${GlobalVariables.currentDepartment} / '
        '${GlobalVariables.currentSection}';
  }

  Widget _buildBadge(int count) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(3),
      constraints: const BoxConstraints(
        minWidth: 16,
        minHeight: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 1,
        ),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  bool ags() {
    return bu == 'GLASS SERVICE - TAGBILARAN';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ??
          DateTime.now(), // Use DateTime.now() if selectedDate is null
      firstDate: DateTime(2015, 8),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      DateTime today = DateTime.now();
      if (picked.isBefore(DateTime(today.year, today.month, today.day))) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text("Expired Item"),
            content: Text("You have selected an expired date."),
            actions: [
              CupertinoDialogAction(
                child: Text("Proceed"),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
        setState(() {
          selectedDate = picked;
        });
      } else {
        setState(() {
          selectedDate = picked;
        });
      }
    }
    print("ang selected date ni $selectedDate");
  }

  bool resetSelectedDate() {
    setState(() {
      selectedDate = null;
    });
    return true;
  }

  @override
  void initState() {
    _sqfliteDBHelper = SqfliteDBHelper.instance;
    ags();
    getUnits();
    _refreshItemList();
    _refreshNfItemList();
    if (mounted) setState(() {});
    btnSaveEnabled = false;
    itemCode = "Unknown";
    itemDescription = "Unknown";
    desc = "Unknown";
    itemUOM = "Unknown";
    if (mounted) setState(() {});
    myFocusNodeBarcode = FocusNode();
    myFocusNodeLotno = FocusNode();
    myFocusNodeQty = FocusNode();
    super.initState();
    print('ang currentBU ni: ${GlobalVariables.currentBusinessUnit}');
    print('ags result: ${ags()}');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          shadowColor: Colors.black12,
          toolbarHeight: 64,
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: Colors.red),
            onPressed: () async {
              await _refreshItemList();
              await _refreshNfItemList();
              if (_items.length > 0 || _nfitems.length > 0) {
                print("$_items ug $_nfitems");
                customLogicalModal(
                    context,
                    Text(
                        "Are you finished scanning this area? \n"
                        "Click YES to tag this area FINISHED. \n"
                        "Setting this area to FINISHED will lock the area. Continue?",
                        textAlign: TextAlign.center),
                    () => Navigator.pop(context), () async {
                  var dtls =
                      "[FINISHED][Audit tag rack (${GlobalVariables.currentBusinessUnit}/${GlobalVariables.currentDepartment}/${GlobalVariables.currentSection}/${GlobalVariables.currentRackDesc}) to FINISHED]";
                  GlobalVariables.isAuditLogged = false;
                  await scanAuditModal(context, _sqfliteDBHelper, dtls);
                  if (GlobalVariables.isAuditLogged == true) {
                    var user = await _sqfliteDBHelper
                        .selectU(GlobalVariables.logEmpNo);
                    var value = true;
                    var done = true;
                    await _sqfliteDBHelper.updateUserAssignAreaWhere(
                      "locked = '" +
                          value.toString() +
                          "' , done = '" +
                          done.toString() +
                          "'",
                      "emp_no = '${user[0]['emp_no']}' AND location_id = '${GlobalVariables.currentLocationID}'",
                    );
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  }
                });
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          // title: Row(
          //   children: [
          //     Flexible(
          //       child: Material(
          //         type: MaterialType.transparency,
          //         child: Text(
          //           GlobalVariables.currentCompany +
          //               "/ " +
          //               GlobalVariables.currentBusinessUnit +
          //               "/ " +
          //               GlobalVariables.currentDepartment +
          //               "/ " +
          //               GlobalVariables.currentSection +
          //               "/ " +
          //               GlobalVariables.currentRackDesc,
          //           maxLines: 2,
          //           style: TextStyle(
          //               fontSize: 20,
          //               color: Colors.blue,
          //               fontWeight: FontWeight.bold),
          //         ),
          //       ),
          //     ),
          //   ],
          // ),

          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _locationTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 30,
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _locationSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(CupertinoIcons.search),
              color: Colors.red,
              onPressed: () {
                // selectedDate = DateTime.now();
                barcodeController.clear();
                qtyController.clear();
                itemCode = "Unknown";
                itemDescription = "Unknown";
                desc = "Unknown";
                itemUOM = "Unknown";
                myFocusNodeBarcode.requestFocus();
                btnSaveEnabled = false;
                if (mounted) setState(() {});
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => BarcodeInputSearchScreen()),
                ).then((value) {
                  if (value == true) {
                    barcodeController.text = GlobalVariables.searchItemBarcode;
                    searchItem2(GlobalVariables.searchItemCode,
                        GlobalVariables.searchUom);
                    print(barcodeController.text);
                    print(
                        "ga itemcode search ${GlobalVariables.searchItemCode} ug ${GlobalVariables.searchUom}");
                    ags()
                        ? myFocusNodeQty.requestFocus()
                        : myFocusNodeLotno.requestFocus();
                    if (mounted) setState(() {});
                  }
                });
              },
            ),
            // Padding(
            //   padding: const EdgeInsets.all(8.0),
            //   child: Stack(
            //     children: [
            //       IconButton(
            //         icon: Icon(CupertinoIcons.doc_plaintext),
            //         color: Colors.red,
            //         onPressed: () {
            //           GlobalVariables.ableEditDelete = true;
            //           Navigator.push(
            //             context,
            //             MaterialPageRoute(
            //                 builder: (context) => ItemScannedListScreen()),
            //           ).then((value) async => await _refreshItemList());
            //         },
            //       ),
            //       FutureBuilder<int>(
            //         future: getRemainingItemCount(
            //             GlobalVariables.currentRackDesc.trim(),
            //             GlobalVariables.currentLocationID.trim()),
            //         builder: (context, snapshot) {
            //           int remainingCount = snapshot.data ?? 0;
            //           if (remainingCount > 0) {
            //             return Positioned(
            //               right: 2,
            //               top: 0,
            //               child: Container(
            //                 padding: EdgeInsets.all(3),
            //                 decoration: BoxDecoration(
            //                   color: Colors.red,
            //                   shape: BoxShape.circle,
            //                   border: Border.all(color: Colors.white, width: 1),
            //                 ),
            //                 constraints: BoxConstraints(
            //                   minWidth: 12,
            //                   minHeight: 12,
            //                 ),
            //                 child: Text(
            //                   '$remainingCount',
            //                   style: TextStyle(
            //                     color: Colors.white,
            //                     fontSize: 12,
            //                     fontWeight: FontWeight.bold,
            //                   ),
            //                   textAlign: TextAlign.center,
            //                 ),
            //               ),
            //             );
            //           }
            //           return SizedBox(); // Return empty widget if count is 0
            //         },
            //       ),
            //     ],
            //   ),
            // ),
            // Padding(
            //   padding: const EdgeInsets.all(8.0),
            //   child: Stack(
            //     children: [
            //       IconButton(
            //         icon: Icon(CupertinoIcons.barcode_viewfinder),
            //         color: Colors.red,
            //         onPressed: () {
            //           GlobalVariables.ableEditDelete = true;
            //           Navigator.push(
            //             context,
            //             MaterialPageRoute(
            //                 builder: (context) => ItemNotFoundScanScreen()),
            //           ).then((value) async => await _refreshNfItemList());
            //         },
            //       ),
            //       FutureBuilder<int>(
            //         future: getRemainingNfItemCount(
            //             GlobalVariables.currentRackDesc.trim(),
            //             GlobalVariables.currentLocationID.trim()),
            //         builder: (context, snapshot) {
            //           int remainingCount = snapshot.data ?? 0;
            //           if (remainingCount > 0) {
            //             return Positioned(
            //               right: 2,
            //               top: 0,
            //               child: Container(
            //                 padding: EdgeInsets.all(3),
            //                 decoration: BoxDecoration(
            //                   color: Colors.red,
            //                   shape: BoxShape.circle,
            //                   border: Border.all(color: Colors.white, width: 1),
            //                 ),
            //                 constraints: BoxConstraints(
            //                   minWidth: 12,
            //                   minHeight: 12,
            //                 ),
            //                 child: Text(
            //                   '$remainingCount',
            //                   style: TextStyle(
            //                     color: Colors.white,
            //                     fontSize: 12,
            //                     fontWeight: FontWeight.bold,
            //                   ),
            //                   textAlign: TextAlign.center,
            //                 ),
            //               ),
            //             );
            //           }
            //           return SizedBox(); // Return empty widget if count is 0
            //         },
            //       ),
            //     ],
            //   ),
            // ),

            SizedBox(
              width: 48,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(
                      CupertinoIcons.doc_plaintext,
                      color: Colors.red,
                    ),
                    onPressed: () {
                      GlobalVariables.ableEditDelete = true;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ItemScannedListScreen(),
                        ),
                      ).then((value) async {
                        await _refreshItemList();
                      });
                    },
                  ),

                  Positioned(
                    top: 10,
                    right: 5,
                    child: FutureBuilder<int>(
                      future: getRemainingItemCount(
                        GlobalVariables.currentRackDesc.trim(),
                        GlobalVariables.currentLocationID.trim(),
                      ),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;

                        if (count == 0) {
                          return const SizedBox.shrink();
                        }

                        return _buildBadge(count);
                      },
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(
              width: 48,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(
                      CupertinoIcons.barcode_viewfinder,
                      color: Colors.red,
                    ),
                    onPressed: () {
                      GlobalVariables.ableEditDelete = true;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ItemNotFoundScanScreen(),
                        ),
                      ).then((value) async {
                        await _refreshNfItemList();
                      });
                    },
                  ),

                  Positioned(
                    top: 10,
                    right: 5,
                    child: FutureBuilder<int>(
                      future: getRemainingNfItemCount(
                        GlobalVariables.currentRackDesc.trim(),
                        GlobalVariables.currentLocationID.trim(),
                      ),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;

                        if (count == 0) {
                          return const SizedBox.shrink();
                        }

                        return _buildBadge(count);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 3.0),
              ags()
                  ? SizedBox()
                  : Row(
                      children: <Widget>[
                        Padding(
                            padding:
                                const EdgeInsets.only(left: 20.0, right: 20.0),
                            child: RichText(
                                text: TextSpan(
                              children: [
                                TextSpan(
                                    text: "Input/Scan Barcode: ",
                                    style: TextStyle(
                                        fontSize: 20,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ))),
                      ],
                    ),
              ags()
                  ? SizedBox()
                  : Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: TextFormField(
                        autofocus: true,
                        focusNode: myFocusNodeBarcode,
                        style: TextStyle(fontSize: 50),
                        textAlign: TextAlign.center,
                        controller: barcodeController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          contentPadding:
                              EdgeInsets.all(8.0), //here your padding
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(3)),
                        ),
                        onChanged: (value) {
                          if (validCharacters.hasMatch(value) == false) {
                            barcodeController.clear();
                          }
                        },
                        onFieldSubmitted: (value) {
                          searchItem(value);
                        },
                      ),
                    ),
              ags()
              ? itemUOM == 'SCRAP' || itemUOM == 'SCRP'
              ? Center(
                child: Column(
                  children: [

                    if (_isProcessingImage)
                      Column(
                        children: const [
                          SizedBox(height: 10),

                          CupertinoActivityIndicator(
                            radius: 14,
                          ),

                          SizedBox(height: 10),

                          Text('Processing image...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                        ],
                      )

                    else if (_imageFile != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        child: GestureDetector(
                          onTap: () => OpenFilex.open(
                            _imageFile!.path,
                          ),
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Image.file(
                                _imageFile!,
                                width: 150,
                                height: 200,
                                fit: BoxFit.cover,
                              ),

                              Positioned(
                                top: 1,
                                right: 1,
                                child: Material(
                                  color: Colors.white70,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    icon: const Icon(
                                      CupertinoIcons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      await _deleteImage();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _takeImage,
                                icon: const Icon(
                                  Icons.camera_alt,
                                ),
                                label: const Text(
                                  "Capture",
                                ),
                              ),

                              const SizedBox(width: 10),

                              ElevatedButton.icon(
                                onPressed: _pickImageFromGallery,
                                icon: const Icon(
                                  Icons.photo_library,
                                ),
                                label: const Text(
                                  "Gallery",
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          const Padding(
                            padding: EdgeInsets.only(
                              bottom: 5,
                            ),
                            child: Text(
                              'No Image',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              )
              : SizedBox()
              : SizedBox(),
              SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: RichText(
                  text: ags()
                      ? TextSpan(
                          children: [
                            TextSpan(
                                text: "Itemcode: ",
                                style: TextStyle(
                                    fontSize: 30,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold)),
                            TextSpan(
                                text: "$itemCode",
                                style: TextStyle(
                                    fontSize: 30, color: Colors.black))
                          ],
                        )
                      : TextSpan(
                          children: [
                            TextSpan(
                                text: "Itemcode: ",
                                style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold)),
                            TextSpan(
                                text: "$itemCode",
                                style: TextStyle(
                                    fontSize: 20, color: Colors.black))
                          ],
                        ),
                ),
              ),
              SizedBox(height: 3.0),
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: RichText(
                  text: ags()
                      ? TextSpan(
                          children: [
                            TextSpan(
                                text: "Description: ",
                                style: TextStyle(
                                    fontSize: 30,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold)),
                            TextSpan(
                                text: "$itemDescription",
                                style: TextStyle(
                                    fontSize: 30, color: Colors.black))
                          ],
                        )
                      : TextSpan(
                          children: [
                            TextSpan(
                                text: "Description: ",
                                style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold)),
                            TextSpan(
                                text: "$itemDescription",
                                style: TextStyle(
                                    fontSize: 20, color: Colors.black))
                          ],
                        ),
                ),
              ),
              itemDescription != desc && desc != "" && desc != "Unknown"
                  ? Padding(
                      padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                                text: "Description2: ",
                                style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold)),
                            TextSpan(
                                text: "$desc",
                                style: TextStyle(
                                    fontSize: 20, color: Colors.black))
                          ],
                        ),
                      ),
                    )
                  : SizedBox(height: 3.0),
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: RichText(
                  text: ags()
                      ? TextSpan(
                          children: [
                            TextSpan(
                                text: "Unit of Measure: ",
                                style: TextStyle(
                                    fontSize: 30,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold)),
                            TextSpan(
                                text: "$itemUOM",
                                style: TextStyle(
                                    fontSize: 30, color: Colors.black))
                          ],
                        )
                      : TextSpan(
                          children: [
                            TextSpan(
                                text: "Unit of Measure: ",
                                style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold)),
                            TextSpan(
                                text: "$itemUOM",
                                style: TextStyle(
                                    fontSize: 20, color: Colors.black))
                          ],
                        ),
                ),
              ),
              SizedBox(height: 3.0),
              ags()
                  ? SizedBox()
                  : Padding(
                      padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                      child: Row(children: [
                        Text("Lot/Batch Number:  ",
                            style: TextStyle(
                                fontSize: 20,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold)),
                        Container(
                            width: MediaQuery.of(context).size.width / 4,
                            child: TextFormField(
                              textAlign: TextAlign.center,
                              controller: lotnoController,
                              focusNode: myFocusNodeLotno,
                              style: TextStyle(fontSize: 23),
                              decoration: InputDecoration(
                                contentPadding:
                                    EdgeInsets.all(8.0), //here your padding
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(3)),
                              ),
                              onFieldSubmitted: (value) {
                                myFocusNodeQty.requestFocus();
                                btnSaveEnabled = false;
                                if (mounted) setState(() {});
                              },
                            ))
                      ])),
              SizedBox(height: 2.0),
              ags()
                  ? SizedBox()
                  : Padding(
                      padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                      child: Row(
                        children: [
                          Text(
                            "Expiry Date:  ",
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            width: MediaQuery.of(context).size.width / 3.5,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                              onPressed: () => _selectDate(context),
                              child: Text(
                                selectedDate != null
                                    ? "${DateFormat('yyyy-MM-dd').format(selectedDate!)}"
                                    : "Select Date", // Show "Select Date" if no date is selected
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ),
                          Spacer(),
                          MaterialButton(
                            onPressed: () {
                              resetSelectedDate();
                            },
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.delete_left,
                                    color: Colors.red),
                                Text(" Clear Expiry Date",
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 18)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

              SizedBox(height: 5.0),
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: Row(
                  children: [
                    Text("Quantity:  ",
                        style: ags()
                            ? TextStyle(
                                fontSize: 30,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold)
                            : TextStyle(
                                fontSize: 20,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold)),
                    Container(
                      width: MediaQuery.of(context).size.width / 5,
                      child: TextFormField(
                        textAlign: TextAlign.center,
                        controller: qtyController,
                        focusNode: myFocusNodeQty,
                        keyboardType: TextInputType.phone,
                        style: ags()
                            ? TextStyle(fontSize: 43)
                            : TextStyle(fontSize: 23),
                        decoration: InputDecoration(
                          contentPadding:
                              EdgeInsets.all(8.0), //here your padding
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(3)),
                        ),
                        onChanged: (value) {
                          final isValid = _validateQuantity();

                          if (btnSaveEnabled != isValid) {
                            setState(() {
                              btnSaveEnabled = isValid;
                            });
                          }
                        },
                        onFieldSubmitted: (value) async {
                          if (!_validateQuantity(showMessage: true)) {
                            btnSaveEnabled = false;
                            if (mounted) {
                              setState(() {});
                            }
                            myFocusNodeQty.requestFocus();
                            return;
                          }

                          if ((itemUOM == 'SCRAP' || itemUOM == 'SCRP') && _imageFile == null) {
                            print('mao nig uom ug imagefile: $itemUOM // $_imageFile 1');
                            instantMsgModal(
                              context,
                              Icon(
                                CupertinoIcons.exclamationmark_circle,
                                color: Colors.red,
                                size: 40,
                              ),
                              Text("Add an image first"),
                            );

                            return;
                          }

                          if (itemCode == "Unknown" &&
                              itemDescription == "Unknown" &&
                              itemUOM == "Unknown") {
                            qtyController.clear();
                            myFocusNodeQty.requestFocus();
                            btnSaveEnabled = false;

                            if (mounted) {
                              setState(() {});
                            }

                            instantMsgModal(
                              context,
                              Icon(
                                CupertinoIcons.exclamationmark_circle,
                                color: Colors.red,
                                size: 40,
                              ),
                              ags()
                                  ? Text("Search for an item first")
                                  : Text(
                                "Error! Please click 'Done' button before saving.",
                              ),
                            );

                            return;
                          }

                          if (selectedDate.toString() == "-0001-11-30 00:00:00.000") {
                            return;
                          }

                          var dtls = "[LOGIN] Audit scan ID to save item.";

                          GlobalVariables.isAuditLogged = false;

                          customLogicalModal(
                            context,
                            Text("Are you sure you want to save this item?"),
                                () => Navigator.pop(context),
                                () async {
                              Navigator.pop(context);

                              await scanAuditModal(
                                context,
                                _sqfliteDBHelper,
                                dtls,
                              );

                              if (GlobalVariables.isAuditLogged != true) {
                                return;
                              }

                              DateFormat dateFormat1 =
                              DateFormat("yyyy-MM-dd HH:mm:ss");

                              String dt = dateFormat1.format(DateTime.now());

                              String imageFilename =
                                  _imageFile?.path.split('/').last ?? '';

                              _itemCount.barcode =
                                  barcodeController.text.trim();

                              _itemCount.image = imageFilename;
                              _itemCount.itemcode = itemCode;
                              _itemCount.description = itemDescription;
                              _itemCount.desc = desc;
                              _itemCount.uom = itemUOM;

                              String lotno = lotnoController.text
                                  .trim()
                                  .toUpperCase();

                              _itemCount.lotno =
                              lotno.isNotEmpty ? lotno : null;

                              _itemCount.expiry = selectedDate != null
                                  ? DateFormat('yyyy-MM-dd')
                                  .format(selectedDate!)
                                  : null;

                              String qty = qtyController.text.trim();
                              _itemCount.qty = qty;

                              _itemCount.conqty =
                                  (int.parse(qty) * convQty).toString();

                              _itemCount.company =
                                  GlobalVariables.currentCompany;

                              _itemCount.bu =
                                  GlobalVariables.currentBusinessUnit;

                              _itemCount.dept =
                                  GlobalVariables.currentDepartment;

                              _itemCount.area =
                                  GlobalVariables.currentSection;

                              _itemCount.rackno =
                                  GlobalVariables.currentRackDesc;

                              _itemCount.dateTimeCreated =
                                  dtItemScanned;

                              _itemCount.dateTimeSaved = dt;

                              _itemCount.empNo =
                                  GlobalVariables.logEmpNo;

                              _itemCount.exported = '';

                              _itemCount.locationid =
                                  GlobalVariables.currentLocationID;

                              await _sqfliteDBHelper.insertItemCount(
                                _itemCount,
                              );

                              _log.date =
                                  dateFormat.format(DateTime.now());

                              _log.time =
                                  timeFormat.format(DateTime.now());

                              _log.device =
                              "${GlobalVariables.deviceInfo}"
                                  "(${GlobalVariables.readdeviceInfo})";

                              _log.user =
                              "${GlobalVariables.logFullName}"
                                  "[Inventory Clerk]";

                              _log.empid =
                                  GlobalVariables.logEmpNo;

                              _log.details =
                              "[ADD][${GlobalVariables.logFullName} "
                                  "add item "
                                  "(barcode: ${barcodeController.text.trim()} "
                                  "description: $itemDescription) "
                                  "with qty of $qtyController $itemUOM "
                                  "to rack "
                                  "(${GlobalVariables.currentBusinessUnit}/"
                                  "${GlobalVariables.currentDepartment}/"
                                  "${GlobalVariables.currentSection}/"
                                  "${GlobalVariables.currentRackDesc})]";

                              await _sqfliteDBHelper.insertLog(_log);

                              GlobalVariables.prevBarCode =
                                  barcodeController.text.trim();

                              GlobalVariables.prevItemCode = itemCode;
                              GlobalVariables.prevItemDesc = itemDescription;
                              GlobalVariables.prevDesc = desc;
                              GlobalVariables.prevItemUOM = itemUOM;

                              GlobalVariables.prevLotno =
                              lotno.isNotEmpty ? lotno : "null";

                              GlobalVariables.prevExpiry =
                              selectedDate != null
                                  ? DateFormat('yyyy-MM-dd')
                                  .format(selectedDate!)
                                  : "null";

                              GlobalVariables.prevQty = qty;
                              GlobalVariables.prevDTCreated = dt;

                              barcodeController.clear();
                              lotnoController.clear();
                              qtyController.clear();

                              itemCode = "Unknown";
                              itemDescription = "Unknown";
                              desc = "Unknown";
                              itemUOM = "Unknown";

                              resetSelectedDate();

                              _imageFile = null;
                              btnSaveEnabled = false;

                              if (mounted) {
                                setState(() {
                                  _refreshItemList();
                                  _refreshNfItemList();
                                });
                              }

                              myFocusNodeBarcode.requestFocus();

                              Fluttertoast.showToast(
                                msg: 'Barcode successfully saved.',
                                toastLength: Toast.LENGTH_LONG,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.black54,
                                textColor: Colors.white,
                                fontSize: 16.0,
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Spacer(),
                    MaterialButton(
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.delete_simple, color: Colors.red),
                          Text(" Clear All Fields",
                              style:
                                  TextStyle(color: Colors.red, fontSize: 25)),
                        ],
                      ),
                      onPressed: () {
                        barcodeController.clear();
                        qtyController.clear();
                        lotnoController.clear();
                        itemCode = "Unknown";
                        itemDescription = "Unknown";
                        desc = "Unknown";
                        itemUOM = "Unknown";
                        resetSelectedDate();
                        print(resetSelectedDate());
                        myFocusNodeBarcode.requestFocus();
                        btnSaveEnabled = false;
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              itemUOM == 'SCRAP' || itemUOM == 'SCRP'
                  ? _imageFile == null
                  ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: SizedBox(
                      height: 30,
                      child: Marquee(
                        text: '❗Image is required for SCRAP items.❗',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                        scrollAxis: Axis.horizontal,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        blankSpace: 50.0,
                        velocity: 40.0,
                        pauseAfterRound: const Duration(seconds: 1),
                        startPadding: 10.0,
                      ),
                    ),
              )
                  : const SizedBox.shrink()
                  : const SizedBox.shrink(),
              Padding(
                padding: const EdgeInsets.only(
                    left: 20.0, right: 20.0, top: 8, bottom: 8.0),
                child: MaterialButton(
                    height: MediaQuery.of(context).size.height / 15,
                    minWidth: MediaQuery.of(context).size.width,
                    color: btnSaveEnabled ? Colors.green : Colors.grey[300],
                    child: Text("SAVE",
                        style: TextStyle(color: Colors.white, fontSize: 25)),
                    onPressed: () async {
                      if (!_validateQuantity(showMessage: true)) {
                        btnSaveEnabled = false;
                        if (mounted) {
                          setState(() {});
                        }
                        myFocusNodeQty.requestFocus();
                        return;
                      }

                      if ((itemUOM == 'SCRAP' || itemUOM == 'SCRP') && _imageFile == null) {
                        print('mao nig uom ug imagefile: $itemUOM // $_imageFile 2');
                        instantMsgModal(
                          context,
                          Icon(
                            CupertinoIcons.exclamationmark_circle,
                            color: Colors.red,
                            size: 40,
                          ),
                          Text("Add an image first"),
                        );

                        return;
                      }

                      if (itemCode == "Unknown" &&
                          itemDescription == "Unknown" &&
                          itemUOM == "Unknown") {
                        qtyController.clear();
                        myFocusNodeQty.requestFocus();
                        btnSaveEnabled = false;

                        if (mounted) {
                          setState(() {});
                        }

                        instantMsgModal(
                          context,
                          Icon(
                            CupertinoIcons.exclamationmark_circle,
                            color: Colors.red,
                            size: 40,
                          ),
                          ags()
                              ? Text("Search for an item first")
                              : Text(
                            "Error! Please click 'Done' button before saving.",
                          ),
                        );
                        return;
                      }

                      if (selectedDate.toString() == "-0001-11-30 00:00:00.000") {
                        return;
                      }

                      var dtls = "[LOGIN] Audit scan ID to save item.";

                      GlobalVariables.isAuditLogged = false;

                      customLogicalModal(
                        context,
                        Text("Are you sure you want to save this item?"),
                            () => Navigator.pop(context),
                            () async {
                          Navigator.pop(context);

                          await scanAuditModal(
                            context,
                            _sqfliteDBHelper,
                            dtls,
                          );

                          if (GlobalVariables.isAuditLogged != true) {
                            return;
                          }

                          DateFormat dateFormat1 = DateFormat("yyyy-MM-dd HH:mm:ss");
                          String dt = dateFormat1.format(DateTime.now());
                          String imageFilename = _imageFile?.path.split('/').last ?? '';
                          _itemCount.barcode = barcodeController.text.trim();
                          _itemCount.image = imageFilename;
                          _itemCount.itemcode = itemCode;
                          _itemCount.description = itemDescription;
                          _itemCount.desc = desc;
                          _itemCount.uom = itemUOM;
                          String lotno = lotnoController.text.trim().toUpperCase();
                          _itemCount.lotno = lotno.isNotEmpty ? lotno : null;
                          _itemCount.expiry = selectedDate != null
                              ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                              : null;
                          String qty = qtyController.text.trim();_itemCount.qty = qty;
                          _itemCount.conqty = (int.parse(qty) * convQty).toString();
                          _itemCount.company = GlobalVariables.currentCompany;
                          _itemCount.bu = GlobalVariables.currentBusinessUnit;
                          _itemCount.dept = GlobalVariables.currentDepartment;
                          _itemCount.area = GlobalVariables.currentSection;
                          _itemCount.rackno = GlobalVariables.currentRackDesc;
                          _itemCount.dateTimeCreated = dtItemScanned;
                          _itemCount.dateTimeSaved = dt;
                          _itemCount.empNo = GlobalVariables.logEmpNo;
                          _itemCount.exported = '';
                          _itemCount.locationid = GlobalVariables.currentLocationID;

                          await _sqfliteDBHelper.insertItemCount(
                            _itemCount,
                          );

                          _log.date = dateFormat.format(DateTime.now());
                          _log.time = timeFormat.format(DateTime.now());
                          _log.device = "${GlobalVariables.deviceInfo}""(${GlobalVariables.readdeviceInfo})";
                          _log.user = "${GlobalVariables.logFullName}""[Inventory Clerk]";
                          _log.empid = GlobalVariables.logEmpNo;
                          _log.details = "[ADD][${GlobalVariables.logFullName} "
                              "add item "
                              "(barcode: ${barcodeController.text.trim()} "
                              "description: $itemDescription) "
                              "with qty of $qtyController $itemUOM "
                              "to rack "
                              "(${GlobalVariables.currentBusinessUnit}/"
                              "${GlobalVariables.currentDepartment}/"
                              "${GlobalVariables.currentSection}/"
                              "${GlobalVariables.currentRackDesc})]";

                          await _sqfliteDBHelper.insertLog(_log);

                          GlobalVariables.prevBarCode = barcodeController.text.trim();
                          GlobalVariables.prevItemCode = itemCode;
                          GlobalVariables.prevItemDesc = itemDescription;
                          GlobalVariables.prevDesc = desc;
                          GlobalVariables.prevItemUOM = itemUOM;
                          GlobalVariables.prevLotno = lotno.isNotEmpty
                              ? lotno
                              : "null";
                          GlobalVariables.prevExpiry = selectedDate != null
                              ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                              : "null";
                          GlobalVariables.prevQty = qty;
                          GlobalVariables.prevDTCreated = dt;

                          barcodeController.clear();
                          lotnoController.clear();
                          qtyController.clear();
                          itemCode = "Unknown";
                          itemDescription = "Unknown";
                          desc = "Unknown";
                          itemUOM = "Unknown";
                          resetSelectedDate();
                          _imageFile = null;
                          btnSaveEnabled = false;

                          if (mounted) {
                            setState(() {
                              _refreshItemList();
                              _refreshNfItemList();
                            });
                          }

                          myFocusNodeBarcode.requestFocus();

                          Fluttertoast.showToast(
                            msg: 'Barcode successfully saved.',
                            toastLength: Toast.LENGTH_LONG,
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.black54,
                            textColor: Colors.white,
                            fontSize: 16.0,
                          );
                        },
                      );
                    }),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.blueGrey,
                      borderRadius: BorderRadius.all(Radius.circular(10))),
                  height: ags()
                      ? MediaQuery.of(context).size.height / 7
                      : MediaQuery.of(context).size.height / 5,
                  width: MediaQuery.of(context).size.width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                        child: Row(
                          children: [
                            Text("PREVIOUS ITEM SAVED\n",
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            Spacer(),
                            Text(
                                "Date & Time: " +
                                    GlobalVariables.prevDTCreated +
                                    "\n",
                                style: TextStyle(
                                    fontSize: 14, color: Colors.white)),
                          ],
                        ),
                      ),
                      ags()
                          ? SizedBox()
                          : Padding(
                              padding: const EdgeInsets.only(
                                  left: 20.0, right: 20.0),
                              child: Text(
                                  "Barcode: " + GlobalVariables.prevBarCode,
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.white)),
                            ),
                      Padding(
                        padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                        child: Text("Itemcode: " + GlobalVariables.prevItemCode,
                            style:
                                TextStyle(fontSize: 13, color: Colors.white)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                        child: Text(
                          "Description: " + GlobalVariables.prevItemDesc,
                          style: TextStyle(fontSize: 13, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      GlobalVariables.prevItemDesc.trim() !=
                              GlobalVariables.prevDesc.trim()
                          ? Padding(
                              padding: const EdgeInsets.only(
                                  left: 20.0, right: 20.0),
                              child: Text(
                                "Description2: " + GlobalVariables.prevDesc,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            )
                          : SizedBox(),
                      Padding(
                        padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                        child: Text(
                          "Unit of Measure: " + GlobalVariables.prevItemUOM,
                          style: TextStyle(fontSize: 13, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      ags()
                          ? SizedBox()
                          : Padding(
                              padding: const EdgeInsets.only(
                                  left: 20.0, right: 20.0),
                              child: Text(
                                "Lot/Batch Number: " +
                                    GlobalVariables.prevLotno,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.white),
                              ),
                            ),
                      ags()
                          ? SizedBox()
                          : Padding(
                              padding: const EdgeInsets.only(
                                  left: 20.0, right: 20.0),
                              child: Text(
                                "Expiry Date: " + GlobalVariables.prevExpiry,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.white),
                              ),
                            ),
                      Padding(
                        padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                        child: Text("Quantity: " + GlobalVariables.prevQty,
                            style:
                                TextStyle(fontSize: 13, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _refreshItemList() async {
    List<ItemCount> x = await _sqfliteDBHelper.fetchItemCountWhere(
        "empno = '${GlobalVariables.logEmpNo}' AND business_unit = '${GlobalVariables.currentBusinessUnit}' AND department = '${GlobalVariables.currentDepartment}' AND section  = '${GlobalVariables.currentSection}' AND rack_desc  = '${GlobalVariables.currentRackDesc}'");
    _items = x;
    if (mounted) setState(() {});
  }

  _refreshNfItemList() async {
    List<ItemNotFound> y = await _sqfliteDBHelper.fetchNfItemCountWhere(
        "empno = '${GlobalVariables.logEmpNo}' AND business_unit = '${GlobalVariables.currentBusinessUnit}' AND department = '${GlobalVariables.currentDepartment}' AND section  = '${GlobalVariables.currentSection}' AND rack_desc  = '${GlobalVariables.currentRackDesc}'");
    _nfitems = y;
    if (mounted) setState(() {});
  }

  searchItem(String value) async {
    print(GlobalVariables.byCategory);
    print(GlobalVariables.byVendor);
//------BY CATEGORY == TRUE AND BY VENDOR = TRUE------//
    if (GlobalVariables.byCategory == true &&
        GlobalVariables.byVendor == true) {
      print('//------BY CATEGORY == TRUE AND BY VENDOR = TRUE------//');
      var x = await _sqfliteDBHelper.selectItemWhereCatVen(value,
          "AND ggroup IN (${GlobalVariables.categories}) AND vendor_name IN (${GlobalVariables.vendors})");
      if (x.length > 0) {
        itemCode = x[0]['item_code'];
        itemDescription = x[0]['extended_desc'];
        desc = x[0]['desc'];
        itemUOM = x[0]['uom'];
        dtItemScanned = dateFormat.format(DateTime.now()) +
            " " +
            timeFormat.format(DateTime.now());
        convQty = int.parse(x[0]['conversion_qty']);
        if (mounted) setState(() {});
        myFocusNodeLotno.requestFocus();
      } else {
        itemNotFoundModal(
            context,
            Icon(
              CupertinoIcons.exclamationmark_circle,
              color: Colors.red,
              size: 40,
            ),
            Text(
                "Item not found. Reason(s): 1.) Barcode not registered 2.) Item is not belong to category ${GlobalVariables.categories} 3.) Item is not belong to vendor ${GlobalVariables.vendors}"));
        itemCode = "Unknown";
        itemDescription = "Unknown";
        desc = "Unknown";
        itemUOM = 'Unknown';
        barcodeController.clear();
        if (mounted) setState(() {});
        myFocusNodeBarcode.requestFocus();
        lotnoController.clear();
        qtyController.clear();
      }
    }
//------BY CATEGORY == TRUE AND BY VENDOR = TRUE------//

//------BY CATEGORY == FALSE AND BY VENDOR = FALSE------//
    if (GlobalVariables.byCategory == false &&
        GlobalVariables.byVendor == false) {
      print('//------BY CATEGORY == FALSE AND BY VENDOR = FALSE------//');
      var x = await _sqfliteDBHelper.selectItemWhere(value);
      print('VALUE : $value');
      if (x.length > 0) {
        itemCode = x[0]['item_code'];
        itemDescription = x[0]['extended_desc'];
        desc = x[0]['desc'];
        itemUOM = x[0]['uom'];
        dtItemScanned = dateFormat.format(DateTime.now()) +
            " " +
            timeFormat.format(DateTime.now());
        convQty = int.parse(x[0]['conversion_qty']);
        if (mounted) setState(() {});
        myFocusNodeLotno.requestFocus();
      } else {
        showAlertDialog();
        itemCode = "Unknown";
        itemDescription = "Unknown";
        desc = "Unknown";
        itemUOM = 'Unknown';
        if (mounted) setState(() {});
        myFocusNodeBarcode.requestFocus();
        barcodeController.clear();
        lotnoController.clear();
        // batnoController.clear();
        qtyController.clear();
      }
    }
//------BY CATEGORY == FALSE AND BY VENDOR = FALSE------//

//------BY CATEGORY == TRUE AND BY VENDOR = FALSE------//
    if (GlobalVariables.byCategory == true &&
        GlobalVariables.byVendor == false) {
      print('//------BY CATEGORY == TRUE AND BY VENDOR = FALSE------//');
      var x = await _sqfliteDBHelper.selectItemWhereCatVen(
          value, "AND ggroup IN (${GlobalVariables.categories})");
      if (x.length > 0) {
        itemCode = x[0]['item_code'];
        itemDescription = x[0]['extended_desc'];
        desc = x[0]['desc'];
        itemUOM = x[0]['uom'];
        dtItemScanned = dateFormat.format(DateTime.now()) +
            " " +
            timeFormat.format(DateTime.now());
        convQty = int.parse(x[0]['conversion_qty']);
        if (mounted) setState(() {});
        myFocusNodeLotno.requestFocus();
      } else {
        itemNotFoundModal(
            context,
            Icon(
              CupertinoIcons.exclamationmark_circle,
              color: Colors.red,
              size: 40,
            ),
            Text(
                "Item not found. Reason(s): 1.) Barcode not registered 2.) Item is not belong to category ${GlobalVariables.categories}"));
        itemCode = "Unknown";
        itemDescription = "Unknown";
        desc = "Unknown";
        itemUOM = 'Unknown';
        barcodeController.clear();
        if (mounted) setState(() {});
        myFocusNodeBarcode.requestFocus();
        lotnoController.clear();
        qtyController.clear();
      }
    }
//------BY CATEGORY == TRUE AND BY VENDOR = FALSE------//

//------BY CATEGORY == FALSE AND BY VENDOR = TRUE------//
    if (GlobalVariables.byCategory == false &&
        GlobalVariables.byVendor == true) {
      print('//------BY CATEGORY == FALSE AND BY VENDOR = TRUE------//');
      var x = await _sqfliteDBHelper.selectItemWhereCatVen(
          value, "AND vendor_name IN (${GlobalVariables.vendors})");
      if (x.length > 0) {
        itemCode = x[0]['item_code'];
        itemDescription = x[0]['extended_desc'];
        desc = x[0]['desc'];
        itemUOM = x[0]['uom'];
        dtItemScanned = dateFormat.format(DateTime.now()) +
            " " +
            timeFormat.format(DateTime.now());
        convQty = int.parse(x[0]['conversion_qty']);
        if (mounted) setState(() {});
        myFocusNodeLotno.requestFocus();
      } else {
        print(x);
        itemNotFoundModal(
            context,
            Icon(
              CupertinoIcons.exclamationmark_circle,
              color: Colors.red,
              size: 40,
            ),
            Text(
                "Item not found. Reason(s): 1.) Barcode not registered 2.) Item is not belong to vendor ${GlobalVariables.vendors}"));
        itemCode = "Unknown";
        itemDescription = "Unknown";
        desc = "Unknown";
        itemUOM = 'Unknown';
        barcodeController.clear();
        if (mounted) setState(() {});
        myFocusNodeBarcode.requestFocus();
        lotnoController.clear();
        qtyController.clear();
      }
    }
//------BY CATEGORY == FALSE AND BY VENDOR = TRUE------//
  }

  getUnits() async {
    units = await _sqfliteDBHelper.selectUnitsAll();
    List<ItemNotFound> x = await _sqfliteDBHelper.fetchItemNotFoundWhere(
        "location = '${GlobalVariables.currentLocationID}'");
    itemNotFound = x;
    _loading = false;
    if (mounted) setState(() {});
  }

  showAlertDialog() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: new Text("Item not found!"),
          content:
              new Text("Would you like to add the item to not found list?"),
          actions: <Widget>[
            new TextButton(
              child: new Text("Yes"),
              onPressed: () async {
                await saveNotFoundBarcode(context, _sqfliteDBHelper, units);
                Navigator.of(context).pop();
              },
            ),
            new TextButton(
              child: new Text("No"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  searchInputtedItem(String data) async {
    var x = await _sqfliteDBHelper.selectItemWhere(data);
    if (x.length > 0) {
      itemCode = x[0]['item_code'];
      itemDescription = x[0]['extended_desc'];
      desc = x[0]['desc'];
      itemUOM = x[0]['uom'];
      dtItemScanned = dateFormat.format(DateTime.now()) +
          " " +
          timeFormat.format(DateTime.now());
      convQty = int.parse(x[0]['conversion_qty']);
      if (mounted) setState(() {});
    } else {
      itemCode = 'Unknown';
      itemDescription = 'Unknown';
      desc = 'Unknown';
      itemUOM = 'Unknown';
      if (mounted) setState(() {});
    }
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

  searchItem2(String value1, String value2) async {
    if (GlobalVariables.byCategory == false &&
        GlobalVariables.byVendor == false) {
      print('//------BY CATEGORY == FALSE AND BY VENDOR = FALSE------//');
      var y = await _sqfliteDBHelper.selectItemCodeUom(value1, value2);
      // int isPdc = GlobalVariables.isPdc;
      // var y = isPdc == 1
      //     ? await _sqfliteDBHelper.selectPdcItemCodeUom(value1, value2)
      //     : await _sqfliteDBHelper.selectItemCodeUom(value1, value2);
      print('VALUE : $value1 and $value2');
      print('VALUE sa Y: $y');
      if (y.isNotEmpty) {
        // Accessing elements directly since y is confirmed to be non-empty
        itemCode = y[0]['item_code'];
        itemDescription = y[0]['extended_desc'];
        desc = y[0]['desc'];
        itemUOM = y[0]['uom'];
        dtItemScanned = dateFormat.format(DateTime.now()) +
            " " +
            timeFormat.format(DateTime.now());
        convQty = int.parse(y[0]['conversion_qty']);
        if (mounted) setState(() {});
      } else {
        // If y is empty, set default "Unknown" or "0.00" values
        showAlertDialog();
        itemCode = "Unknown";
        itemDescription = "Unknown";
        desc = "Unknown";
        itemUOM = 'Unknown';
        if (mounted) setState(() {});
        myFocusNodeBarcode.requestFocus();
        barcodeController.clear();
        qtyController.clear();
      }
    }
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

  Future<void> _takeImage() async {
    if (_isProcessingImage) return;

    if (itemCode == "Unknown" || itemCode.trim().isEmpty) {
      instantMsgModal(
          context,
          Icon(
            CupertinoIcons.exclamationmark_circle,
            color: Colors.red,
            size: 40,
          ),
          Text("Search for an item first"));
      return;
    }

    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
    );

    if (image == null) return;

    await _processImage(image, itemCode);
  }

  Future<void> _pickImageFromGallery() async {
    if (_isProcessingImage) return;

    if (itemCode == "Unknown" || itemCode.trim().isEmpty) {
      instantMsgModal(
          context,
          Icon(
            CupertinoIcons.exclamationmark_circle,
            color: Colors.red,
            size: 40,
          ),
          Text("Search for an item first"));
      return;
    }

    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null) return;

    await _processImage(image, itemCode);
  }

  Future<void> _processImage(
      XFile image,
      String itemCode,
      ) async {
    if (_isProcessingImage) return;
    if (!mounted) return;

    setState(() {
      _isProcessingImage = true;
    });

    await Future.delayed(
      const Duration(milliseconds: 1000),
    );

    try {
      print('========================================');
      print('IMAGE PROCESSING STARTED');
      print('Original image: ${image.path}');
      print('========================================');

      final File originalImage = File(image.path);

      final Uint8List imageBytes =
      await originalImage.readAsBytes();

      final img.Image? decodedImage =
      img.decodeImage(imageBytes);

      if (decodedImage == null) {
        throw Exception(
          'Unable to process selected image.',
        );
      }

      print(
        'Original size: '
            '${decodedImage.width} x ${decodedImage.height}',
      );

      final img.Image resizedImage = img.copyResize(
        decodedImage,
        width: 700,
      );

      final Uint8List compressedBytes =
      Uint8List.fromList(
        img.encodeJpg(
          resizedImage,
          quality: 80,
        ),
      );

      // Create directory.
      final Directory imagesDir = Directory(
        '/storage/emulated/0/Scrap Images',
      );

      if (!await imagesDir.exists()) {
        await imagesDir.create(
          recursive: true,
        );
      }

      // Generate filename.
      final timestamp = DateFormat(
        'MMddyyyyHHmmssSSS',
      ).format(DateTime.now());

      final fileName = '${itemCode}_$timestamp.jpg';

      final File newImage = File(
        '${imagesDir.path}/$fileName',
      );

      // Save physical image.
      await newImage.writeAsBytes(
        compressedBytes,
        flush: true,
      );

      print(
        'Processed image saved: ${newImage.path}',
      );

      print(
        'Compressed size: '
            '${compressedBytes.length} bytes',
      );

      // Delete previous physical image.
      if (_imageFile != null) {
        try {
          if (await _imageFile!.exists()) {
            await _imageFile!.delete();
          }
        } catch (e) {
          debugPrint(
            'Unable to delete previous image: $e',
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _imageFile = newImage;
      });

      Fluttertoast.showToast(
        msg: 'Image processed successfully.',
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.black54,
      );
    } catch (e) {
      debugPrint(
        'Image processing error: $e',
      );

      if (!mounted) return;

      Fluttertoast.showToast(
        msg: 'Failed to process image.',
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
        });
      }
    }
  }

  Future<void> _deleteImage() async {
    final file = _imageFile;

    if (file == null) return;

    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Failed to delete image: $e");
    }

    if (!mounted) return;

    setState(() {
      _imageFile = null;
    });
  }

  bool _validateQuantity({bool showMessage = false}) {
    final qty = qtyController.text.trim();

    // Empty quantity
    if (qty.isEmpty) {
      if (showMessage) {
        instantMsgModal(
          context,
          Icon(
            CupertinoIcons.exclamationmark_circle,
            color: Colors.red,
            size: 40,
          ),
          Text("Please enter a quantity."),
        );
      }

      return false;
    }

    // Must contain numbers only
    if (!validCharacters.hasMatch(qty)) {
      if (showMessage) {
        instantMsgModal(
          context,
          Icon(
            CupertinoIcons.exclamationmark_circle,
            color: Colors.red,
            size: 40,
          ),
          Text("Please enter a valid quantity."),
        );
      }

      return false;
    }

    // Decimal is not allowed
    if (qty.contains('.')) {
      if (showMessage) {
        instantMsgModal(
          context,
          Icon(
            CupertinoIcons.exclamationmark_circle,
            color: Colors.red,
            size: 40,
          ),
          Text("Please enter a whole number."),
        );
      }

      return false;
    }

    // Zero / leading zero is not allowed
    if (qty.startsWith('0')) {
      if (showMessage) {
        instantMsgModal(
          context,
          Icon(
            CupertinoIcons.exclamationmark_circle,
            color: Colors.red,
            size: 40,
          ),
          Text("Quantity cannot start with zero."),
        );
      }

      return false;
    }

    // Maximum 6 digits
    if (qty.length >= 7) {
      if (showMessage) {
        instantMsgModal(
          context,
          Icon(
            CupertinoIcons.exclamationmark_circle,
            color: Colors.red,
            size: 40,
          ),
          Text(
            "Quantity is substantial. Please input below 7 digits amount.",
          ),
        );
      }

      return false;
    }

    // AGS
    if (ags()) {
      return true;
    }

    // Non-AGS requires barcode
    if (barcodeController.text.trim().isEmpty) {
      if (showMessage) {
        instantMsgModal(
          context,
          Icon(
            CupertinoIcons.exclamationmark_circle,
            color: Colors.red,
            size: 40,
          ),
          Text("Please scan an item first."),
        );
      }

      return false;
    }

    return true;
  }


}
