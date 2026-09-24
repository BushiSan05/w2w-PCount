import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:physicalcountv2/db/sqfLite_dbHelper.dart';
import 'package:physicalcountv2/values/globalVariables.dart';

class BarcodeInputSearchScreen extends StatefulWidget {
  const BarcodeInputSearchScreen({Key? key}) : super(key: key);

  @override
  _BarcodeInputSearchScreenState createState() =>
      _BarcodeInputSearchScreenState();
}

class _BarcodeInputSearchScreenState extends State<BarcodeInputSearchScreen> {
  late FocusNode myFocusNodeBarcode;
  final searchController = TextEditingController();
  late SqfliteDBHelper _sqfliteDBHelper;
  // List items = [];
  List<Map<String, dynamic>> items = [];
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();
  bool showScrollHint = false;
  bool noResults = false;
  bool showScrollToTop = false;
  String bu = GlobalVariables.currentBusinessUnit.trim();

  bool ags() {
    return bu == 'GLASS SERVICE - TAGBILARAN';
  }

  @override
  void initState() {
    items.sort((a, b) => a['item_code'].compareTo(b['item_code']));
    _sqfliteDBHelper = SqfliteDBHelper.instance;
    if (mounted) setState(() {});
    myFocusNodeBarcode = FocusNode();
    _scrollController.addListener(() {
      final position = _scrollController.position;

      if (items.length > 10 &&
          position.pixels < position.maxScrollExtent - 50) {
        if (!showScrollHint) setState(() => showScrollHint = true);
      }

      if (position.pixels >= position.maxScrollExtent) {
        if (showScrollHint) setState(() => showScrollHint = false);
      }

      if (position.pixels > 300) {
        if (!showScrollToTop) setState(() => showScrollToTop = true);
      } else {
        if (showScrollToTop) setState(() => showScrollToTop = false);
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 0.0,
        elevation: 0.0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context, false),
          icon: Icon(Icons.close, color: Colors.red),
        ),
        title: Row(
          children: [
            Flexible(
              child: Material(
                type: MaterialType.transparency,
                child: Text(
                  "Search Item by Description/Itemcode",
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
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: TextFormField(
                    autofocus: true,
                    focusNode: myFocusNodeBarcode,
                    style: TextStyle(fontSize: 50),
                    textAlign: TextAlign.center,
                    controller: searchController,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.all(8.0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    onChanged: (value) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce = Timer(Duration(milliseconds: 500), () {
                        searchItembyitemcode(value);
                      });
                    },
                  ),
                ),
              ),

              if (noResults)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "No Results Found",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // MAKES LISTVIEW SCROLL CORRECTLY
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return RepaintBoundary(
                        child: GestureDetector(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ListTile(
                          tileColor: Colors.lightBlue[50],
                          title: ags()
                              ? SizedBox()
                              : Text(
                                  "${items[index]['barcode']}",
                                  style: TextStyle(fontSize: 23),
                                ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Divider(
                                color: Colors.grey.shade400,
                                thickness: 1,
                                height: 1,
                              ),
                              SizedBox(height: 5),
                              ags()
                                  ? Text.rich(TextSpan(children: [
                                      const TextSpan(
                                        text: "ITEMCODE: ",
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.normal,
                                          color: Colors.black,
                                        ),
                                      ),
                                      highlightMatch(
                                          "${items[index]['item_code']}",
                                          searchController.text,
                                          fontSize: 20),
                                    ]))
                                  : Text.rich(
                                      highlightMatch(
                                        "ITEMCODE: ${items[index]['item_code']}",
                                        searchController.text,
                                      ),
                                    ),
                              ags()
                                  ? Text.rich(TextSpan(children: [
                                      const TextSpan(
                                        text: "DESC: ",
                                        style: TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.normal,
                                          color: Colors.black,
                                        ),
                                      ),
                                      highlightMatch(
                                          "${items[index]['extended_desc']}",
                                          searchController.text,
                                          fontSize: 25),
                                    ]))
                                  : Text.rich(
                                      highlightMatch(
                                        "DESC: ${items[index]['extended_desc']}",
                                        searchController.text,
                                      ),
                                    ),
                              ags()
                                  ? SizedBox()
                                  : Text.rich(
                                      highlightMatch(
                                        "DESC2: ${items[index]['desc']}",
                                        searchController.text,
                                      ),
                                    ),
                              ags()
                                  ? Text.rich(TextSpan(children: [
                                      const TextSpan(
                                        text: "UOM: ",
                                        style: TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.normal,
                                          color: Colors.black,
                                        ),
                                      ),
                                      highlightMatch("${items[index]['uom']}",
                                          searchController.text,
                                          fontSize: 25),
                                    ]))
                                  : Text(
                                      "UOM: ${items[index]['uom']}",
                                      style: TextStyle(color: Colors.black),
                                    ),
                              SizedBox(height: 5),
                              Divider(
                                color: Colors.grey.shade400,
                                thickness: 1,
                                height: 1,
                              ),
                            ],
                          ),
                        ),
                      ),

                      onTap: () {
                        GlobalVariables.searchItemBarcode =
                            items[index]['barcode'];
                        GlobalVariables.searchItemCode =
                            items[index]['item_code'];
                        GlobalVariables.searchUom = items[index]['uom'];
                        Navigator.pop(context, true);
                      },
                    ),
                    );
                  },
                ),
              ),
            ],
          ),

          /// Floating hint
          if (showScrollHint)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 18),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "👇🏻 Scroll down for more results 👇🏻",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),

          if (showScrollToTop)
            Positioned(
              bottom: 20,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.minScrollExtent,
                      duration: Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(2, 2),
                      )
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_upward_sharp,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> searchItembyitemcode(String value) async {
    print(value);

    if (value.isEmpty || value == null) {
      setState(() {
        items = [];
        noResults = true;
      });
      return;
    }

    setState(() {
      noResults = false;
    });

    var x = await _sqfliteDBHelper.searchItems(value);

    if (x.length > 10) {
      // or any threshold you like
      showScrollHint = true;
    } else {
      showScrollHint = false;
    }

    if (x.isNotEmpty) {
      items = List<Map<String, dynamic>>.from(x)
        ..sort((a, b) => a['item_code'].compareTo(b['item_code']));
      print("mao nig items $items");
    } else {
      items = [];
      noResults = true;
      // _showItemNotFoundModal();
    }

    if (mounted) setState(() {});
  }

  TextSpan highlightMatch(
    String source,
    String query, {
    double fontSize = 20,
  }) {
    final textStyle = TextStyle(
      color: Colors.black,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    );

    final highlightStyle = TextStyle(
      color: Colors.blue,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    );

    if (query.isEmpty) {
      return TextSpan(text: source, style: textStyle);
    }

    final lowerSource = source.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final List<TextSpan> spans = [];

    int start = 0;

    while (start < source.length) {
      final index = lowerSource.indexOf(lowerQuery, start);

      if (index < 0) {
        // No more matches, add remaining text
        spans.add(TextSpan(
          text: source.substring(start),
          style: textStyle,
        ));
        break;
      }

      // Add text before the match
      if (index > start) {
        spans.add(TextSpan(
          text: source.substring(start, index),
          style: textStyle,
        ));
      }

      // Add the matched text
      spans.add(TextSpan(
        text: source.substring(index, index + query.length),
        style: highlightStyle,
      ));

      start = index + query.length;
    }

    return TextSpan(children: spans);
  }

// void _showItemNotFoundModal() {
  //   itemNotFoundModal(
  //     context,
  //     Icon(
  //       CupertinoIcons.exclamationmark_circle,
  //       color: Colors.red,
  //       size: 40,
  //     ),
  //     Text("ERROR! \n\n"
  //         "Item not found.",
  //       textAlign: TextAlign.center,
  //     ),
  //   );
  // }
}
