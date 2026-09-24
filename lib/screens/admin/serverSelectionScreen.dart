// import 'package:flutter/material.dart';
// import 'package:physicalcountv2/screens/admin/adminDashboardScreen.dart';
// import 'package:physicalcountv2/services/location_list.dart';
// import 'package:physicalcountv2/services/server_url.dart';
// import 'package:physicalcountv2/values/globalVariables.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class ServerSelectionScreen extends StatefulWidget {
//   const ServerSelectionScreen({Key? key}) : super(key: key);
//
//   @override
//   _ServerSelectionScreenState createState() => _ServerSelectionScreenState();
// }
//
// class _ServerSelectionScreenState extends State<ServerSelectionScreen> {
//   String _selectedServer = 'LOCAL';
//   String? _selectedLocation;
//   final List<String> serverNames = ServerUrl.servers.keys.toList();
//   final Map<String, bool> locations = LocationList.locations;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Select Server and Location")),
//       body: Padding(
//         padding: const EdgeInsets.all(20.0),
//         child: Column(
//           children: [
//
//             // Server Dropdown
//             DropdownButtonFormField<String>(
//               value: _selectedServer,
//               decoration: InputDecoration(labelText: "Select Server"),
//               items: serverNames.map((s) {
//                 return DropdownMenuItem(value: s, child: Text(s));
//               }).toList(),
//               onChanged: (val) {
//                 setState(() => _selectedServer = val!);
//                 // Reset location when server changes
//                 _selectedLocation = null;
//               },
//             ),
//
//             SizedBox(height: 20),
//
//             // Location Button
//             ElevatedButton(
//               onPressed: () async {
//                 String? loc = await showDialog<String>(
//                   context: context,
//                   builder: (_) => SimpleDialog(
//                     title: Text("Select Location"),
//                     children: locations.map((l) {
//                       return SimpleDialogOption(
//                         child: Text(l),
//                         onPressed: () => Navigator.pop(context, l),
//                       );
//                     }).toList(),
//                   ),
//                 );
//
//                 if (loc != null) {
//                   setState(() => _selectedLocation = loc);
//                 }
//               },
//               child: Text(_selectedLocation ?? "Select Location"),
//             ),
//
//             SizedBox(height: 40),
//
//             // Continue Button
//             ElevatedButton(
//               onPressed: _selectedLocation != null
//                   ? () async {
//                 // Save server and location
//                 SharedPreferences prefs = await SharedPreferences.getInstance();
//                 await prefs.setString("new_server", _selectedServer);
//                 GlobalVariables.selectedServer = _selectedServer;
//                 GlobalVariables.currentBusinessUnit = _selectedLocation!;
//                 ServerUrl.setServer(_selectedServer);
//
//                 // Navigate to AdminDashboardScreen
//                 Navigator.pushReplacement(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => AdminDashboardScreen(
//                       user: "ADMIN",
//                       id: "ADMIN",
//                       businessUnit: "All",
//                     ),
//                   ),
//                 );
//               }
//                   : null,
//               child: Text("Continue"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
