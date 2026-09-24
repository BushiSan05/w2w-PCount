import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:physicalcountv2/services/location_list.dart';

Future<void> loadLocationSettings() async {
  final prefs = await SharedPreferences.getInstance();
  String? jsonString = prefs.getString("enabled_locations");

  if (jsonString != null) {
    Map<String, dynamic> decoded = jsonDecode(jsonString);
    LocationList.locations =
        decoded.map((key, value) => MapEntry(key, value as bool));
  }
}

Future<void> saveLocationSettings() async {
  final prefs = await SharedPreferences.getInstance();
  String jsonString = jsonEncode(LocationList.locations);
  await prefs.setString("enabled_locations", jsonString);
}

Future<void> showLocationManager(BuildContext context) async {
  Map<String, bool> tempLocations = Map.from(LocationList.locations);

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Location Manager"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: tempLocations.entries.map((entry) {
                  return SwitchListTile(
                    title: Text(entry.key),
                    value: entry.value,
                    onChanged: (val) {
                      setState(() {
                        tempLocations[entry.key] = val;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  LocationList.locations = tempLocations;
                  await saveLocationSettings();
                  Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      );
    },
  );
}
