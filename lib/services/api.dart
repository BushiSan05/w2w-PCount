import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:physicalcountv2/services/app_update.dart';
import 'package:physicalcountv2/services/server_url.dart';
import "package:http/http.dart" as http;
import 'package:physicalcountv2/values/globalVariables.dart';
import 'package:retry/retry.dart';

Future checkConnection() async {
  try {
    var url = Uri.parse(ServerUrl.current + "mapi/checkConnection");
    final response = await http.get(url).timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) {
      return 'connected';
    } else if (response.statusCode >= 400 || response.statusCode <= 499) {
      GlobalVariables.httpError =
          "Error: Client issued a malformed or illegal request.";
      return 'error';
    } else if (response.statusCode >= 500 || response.statusCode <= 599) {
      GlobalVariables.httpError = "Error: Internal server error.";
      return 'error';
    }
  } on TimeoutException {
    GlobalVariables.httpError =
        "Connection timed out. Please check internet connection or proxy server configurations.";
    return 'errornet';
  } on SocketException {
    GlobalVariables.httpError =
        "Connection timed out. Please check internet connection or proxy server configurations.";
    return 'errornet';
  } on HttpException {
    GlobalVariables.httpError =
        "Error: An HTTP error occurred. Please try again later.";
    return 'error';
  } on FormatException {
    GlobalVariables.httpError =
        "Error: Format exception error occurred. Please try again later.";
    return 'error';
  }
}

Future getUserMasterfile() async {
  var url = Uri.parse(ServerUrl.current + "mapi/getUserMasterfile");
  final response = await retry(
      () => http.post(url, headers: {"Accept": "Application/json"}, body: {}));
  var convertedDataToJson = jsonDecode(response.body);
  return convertedDataToJson;
}

Future checkUpdate(String version) async {
  var url = Uri.parse(AppUpdateVersion.urlCICheckUpdate + "mapi/CheckUpdate");
  final response = await retry(() => http.post(url, headers: {
        "Accept": "Application/json"
      }, body: {
        'version': version,
      }));
  try {
    return jsonDecode(response.body);
  } catch (e) {
    return {"status": "error", "message": "Invalid JSON", "raw": response.body};
  }
}

Future getAdmin(String haveFilter, String filters) async {
  var url = Uri.parse(AppUpdateVersion.urlCICheckUpdate + "mapi/getAdmin");
  final response = await retry(() => http.post(url, headers: {
        "Accept": "Application/json"
      }, body: {
        'haveFilter': haveFilter,
        'filters': filters,
      }));
  var convertedDataToJson = jsonDecode(response.body);
  return convertedDataToJson;
}

Future getAuditMasterfile() async {
  var url = Uri.parse(ServerUrl.current + "mapi/getAuditMasterifle");
  final response = await retry(
      () => http.post(url, headers: {"Accept": "Application/json"}, body: {}));
  var convertedDataToJson = jsonDecode(response.body);
  return convertedDataToJson;
}

Future getLocationMasterfile() async {
  var url = Uri.parse(ServerUrl.current + "mapi/getLocationMasterfile");
  final response = await retry(
      () => http.post(url, headers: {"Accept": "Application/json"}, body: {}));
  var convertedDataToJson = jsonDecode(response.body);
  return convertedDataToJson;
}

Future getItemMasterfileCount(String location) async {
  var url = Uri.parse(ServerUrl.current + "mapi/getItemMasterfileCount");
  final response = await retry(() => http.post(url, headers: {
        "Accept": "Application/json"
      }, body: {
        'location': location,
      }));
  var convertedDataToJson = jsonDecode(response.body);
  return convertedDataToJson;
}

Future getUnit(String haveFilter, String filters) async {
  var url = Uri.parse(ServerUrl.current + "mapi/getUnit");
  final response = await retry(() => http.post(url, headers: {
        "Accept": "Application/json"
      }, body: {
        'haveFilter': haveFilter,
        'filters': filters,
      }));
  var convertedDataToJson = jsonDecode(response.body);
  // print('convertedDataToJson $convertedDataToJson');
  return convertedDataToJson;
}

Future getItemMasterfileOffset(String offset, String location) async {
  var url = Uri.parse(ServerUrl.current + "mapi/getItemMasterfileOffset");
  final response = await retry(() => http.post(url, headers: {
        "Accept": "Application/json"
      }, body: {
        'offset': offset,
        'location': location,
      }));
  var convertedDataToJson = jsonDecode(response.body);
  return convertedDataToJson;
}

Future getFilteredItemMasterfile() async {
  var url = Uri.parse(ServerUrl.current + "mapi/getFilteredItemMasterfile");
  final response = await retry(
      () => http.post(url, headers: {"Accept": "Application/json"}, body: {}));
  var convertedDataToJson = jsonDecode(response.body);
  return convertedDataToJson;
}

Future syncCount(
    List items,
    String userSignature,
    String auditSignature,
    String location,
    ) async {
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout:
      const Duration(seconds: 30),
      sendTimeout:
      const Duration(minutes: 10),
      receiveTimeout:
      const Duration(minutes: 10),
    ),
  );

  final result = await syncItem(
    items,
    userSignature,
    auditSignature,
    location,
  );

  // Adjust this according to your actual API response.
  if (result == null) {
    throw Exception(
      'Upload failed.',
    );
  }

  await uploadImages(
    items,
    dio,
    onProgress: (progress, status) {
      print(
        '${(progress * 100).toStringAsFixed(1)}% '
            '$status',
      );
    },
  );

  return result;
}

Future syncItem(List items, String usersignature, String auditorsignature,
    String location) async {
  print("ACTUAL COUNT API");
  print("LOCATION ID :: ${GlobalVariables.currentLocationID}");
  var url = Uri.parse(ServerUrl.current + "mapi/insertCountDataList");
  final response = await retry(() => http.post(url, headers: {
        "Accept": "Application/json"
      }, body: {
        'items': json.encode(items),
        'empno': GlobalVariables.logEmpNo,
        'user_signature': usersignature,
        'audit_signature': auditorsignature,
        'locationid': GlobalVariables.currentLocationID,
        'location': location,
      }));
  print("Item ACTUAL count RESPONSE2 STATUS CODE :: ${response.body}");
  GlobalVariables.statusCode = response.statusCode;
  var convertedDataToJson = jsonDecode(response.body);
  print("Item ACTUAL RESPONSE2 :: $convertedDataToJson");
  return convertedDataToJson;
}

Future syncAdvCount(
    List items,
    String userSignature,
    String auditSignature,
    String location,
    ) async {
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout:
      const Duration(seconds: 30),
      sendTimeout:
      const Duration(minutes: 10),
      receiveTimeout:
      const Duration(minutes: 10),
    ),
  );

  final result = await syncItem_adv(
    items,
    userSignature,
    auditSignature,
    location,
  );

  // Adjust this according to your actual API response.
  if (result == null) {
    throw Exception(
      'Upload failed.',
    );
  }

  await uploadImages(
    items,
    dio,
    onProgress: (progress, status) {
      print(
        '${(progress * 100).toStringAsFixed(1)}% '
            '$status',
      );
    },
  );

  return result;
}

Future syncItem_adv(List items, String usersignature, String auditorsignature,
    String location) async {
  var url = Uri.parse(ServerUrl.current + "mapi/insertAdvanceCount");
  final response = await retry(() => http.post(url, headers: {
        "Accept": "Application/json"
      }, body: {
        'items': json.encode(items),
        'empno': GlobalVariables.logEmpNo,
        'user_signature': usersignature,
        'audit_signature': auditorsignature,
        'locationid': GlobalVariables.currentLocationID,
        'location': location,
      }));
  print("Item advance count RESPONSE2 STATUS CODE :: ${response.statusCode}");
  GlobalVariables.statusCode = response.statusCode;
  print("Item RESPONSE :: ${response.body}");
  var convertedDataToJson = jsonDecode(response.body);
  print("Item advance RESPONSE2 :: $convertedDataToJson");
  return convertedDataToJson;
}

Future syncItem_freegoods(
    List items, String usersignature, String auditorsignature) async {
  var url = Uri.parse(ServerUrl.current + "mapi/insertFreeGoodsCount");
  final response = await retry(() => http.post(url, headers: {
        "Accept": "Application/json"
      }, body: {
        'items': json.encode(items),
        'empno': GlobalVariables.logEmpNo,
        'user_signature': usersignature,
        'audit_signature': auditorsignature,
        'locationid': GlobalVariables.currentLocationID,
      }));
  GlobalVariables.statusCode = response.statusCode;
  var convertedDataToJson = jsonDecode(response.body);
  return convertedDataToJson;
}

Future syncNfItem(
    List nfItems, String userSignature, String auditSignature) async {
  var url = Uri.parse(ServerUrl.current + "mapi/insertNFItemList");
  final response = await retry(() => http.post(url, headers: {
        "Accept": "Application/json"
      }, body: {
        'nfitems': json.encode(nfItems),
        'user_signature': userSignature,
        'audit_signature': auditSignature,
      }));
  GlobalVariables.statusCode = response.statusCode;
  var convertedDataToJson = jsonDecode(response.body);
  return convertedDataToJson;
}

Future syncNfItem_freegoods(
    List nfItems, String userSignature, String auditSignature) async {
  var url = Uri.parse(ServerUrl.current + "mapi/insertNFFreeGoods");
  final response = await retry(() => http.post(url, headers: {
        "Accept": "Application/json"
      }, body: {
        'nfitems': json.encode(nfItems),
        'user_signature': userSignature,
        'audit_signature': auditSignature,
      }));
  GlobalVariables.statusCode = response.statusCode;
  var convertedDataToJson = jsonDecode(response.body);
  return convertedDataToJson;
}

Future syncNfItem_adv(
    List nfItems, String userSignature, String auditSignature) async {
  var url = Uri.parse(ServerUrl.current + "mapi/insertNFAdvanceCount");
  final response = await retry(() => http.post(url, headers: {
        "Accept": "Application/json"
      }, body: {
        'nfitems': json.encode(nfItems),
        'user_signature': userSignature,
        'audit_signature': auditSignature,
      }));
  print("Item RESPONSE2 STATUS CODE :: ${response.statusCode}");
  GlobalVariables.statusCode = response.statusCode;
  print("RESPONSE :: ${response.body}");
  var convertedDataToJson = jsonDecode(response.body);
  print("RESPONSE2 :: $convertedDataToJson");
  return convertedDataToJson;
}

Future syncAuditTrail(List logs, String location) async {
  var url = Uri.parse(ServerUrl.current + "mapi/insertAuditTrail");
  final response = await retry(() => http.post(url, headers: {
        "Accept": "Application/json"
      }, body: {
        'logs': json.encode(logs),
        'location': location,
      }));
  GlobalVariables.statusCode = response.statusCode;
  print("AUDIT RESPONSE :: ${response.body}");
  var convertedDataToJson = jsonDecode(response.body);
  print("AUDIT RESPONSE :: $convertedDataToJson");
  return convertedDataToJson;
}

Future getAllUsers() async {
  var url = Uri.parse(ServerUrl.current + "mapi/getAllUsers");
  final response = await retry(
      () => http.post(url, headers: {"Accept": "Application/json"}, body: {}));
  var convertedDataToJson = jsonDecode(response.body);
  return convertedDataToJson;
}

Future updateSignature(
    String locationid, String userSig, String auditSig) async {
  var url = Uri.parse(ServerUrl.current + "mapi/updateSignature");
  final response = await retry(() => http.post(url, headers: {
        "Accept": "Application/json"
      }, body: {
        'location_id': locationid,
        'user_sig': userSig,
        'audit_sig': auditSig,
      }));
  var convertedDataToJson = jsonDecode(response.body);
  return convertedDataToJson;
}

Future getServer() async {
  var url = Uri.parse(ServerUrl.current + "mapi/updateSignature");
}

Future<void> uploadImages(
    List items,
    Dio dio, {
      Function(double progress, String status)? onProgress,
    }) async {
  const String imageDirectory =
      '/storage/emulated/0/Scrap Images';

  const int batchSize = 20;

  final List<File> imageFiles = [];

  final Set<String> addedImages = {};

  for (final item in items) {
    final String imageName =
        item['image']?.toString().trim() ?? '';

    if (imageName.isEmpty) {
      continue;
    }

    final String imageKey =
    imageName.toLowerCase();

    // Prevent duplicate filenames
    if (addedImages.contains(imageKey)) {
      continue;
    }

    addedImages.add(imageKey);

    final File imageFile = File(
      '$imageDirectory/$imageName',
    );

    if (await imageFile.exists()) {
      imageFiles.add(imageFile);
    } else {
      debugPrint(
        'Count image not found locally: $imageName',
      );
    }
  }

  print('COUNT IMAGE SUMMARY');
  print(
    'Images found locally: ${imageFiles.length}',
  );

  if (imageFiles.isEmpty) {
    print('No count images to upload.');

    onProgress?.call(
      1.0,
      'No images to upload.',
    );

    return;
  }

  onProgress?.call(
    0.0,
    'Checking server images...\n'
        '${imageFiles.length} images',
  );

  final List<File> imagesToUpload =
  await getImagesNotOnServer(
    imageFiles,
    dio,
  );

  final int totalLocalImages =
      imageFiles.length;

  final int alreadyUploaded =
      totalLocalImages -
          imagesToUpload.length;

  print('SERVER IMAGE CHECK');
  print(
    'Total local images : $totalLocalImages',
  );
  print(
    'Already on server  : $alreadyUploaded',
  );
  print(
    'Need to upload     : ${imagesToUpload.length}',
  );

  if (imagesToUpload.isEmpty) {
    print(
      'All count images already exist on server.',
    );

    onProgress?.call(
      1.0,
      'Images already uploaded.',
    );

    return;
  }

  int totalUploaded = 0;
  int totalSkipped = alreadyUploaded;
  int totalFailed = 0;

  final int totalImages =
      imagesToUpload.length;

  for (
  int start = 0;
  start < totalImages;
  start += batchSize
  ) {
    final int end =
    (start + batchSize < totalImages)
        ? start + batchSize
        : totalImages;

    final List<File> batch =
    imagesToUpload.sublist(
      start,
      end,
    );

    print(
      'Uploading count image batch '
          '${start + 1}-$end '
          'of $totalImages',
    );

    final double imageProgress =
        start / totalImages;

    onProgress?.call(
      imageProgress.clamp(0.0, 1.0),
      'Preparing image batch...\n'
          '${start + 1}-$end of $totalImages',
    );

    final FormData formData =
    FormData();

    for (final File imageFile in batch) {
      final String imageName =
          imageFile.path.split('/').last;

      formData.files.add(
        MapEntry(
          'images[]',
          await MultipartFile.fromFile(
            imageFile.path,
            filename: imageName,
          ),
        ),
      );
    }

    try {
      final Response response =
      await dio.post(
        '${ServerUrl.current}mapi/uploadImagesBatch',
        data: formData,
        options: Options(
          headers: {
            'Content-Type':
            'multipart/form-data',
          },
          responseType:
          ResponseType.plain,
        ),
        onSendProgress: (
            int sent,
            int total,
            ) {
          if (total <= 0) {
            return;
          }

          final double batchProgress =
          (sent / total)
              .clamp(0.0, 1.0);

          final double currentImagePosition =
              start +
                  (batchProgress *
                      batch.length);

          final double overallProgress =
              currentImagePosition /
                  totalImages;

          onProgress?.call(
            overallProgress.clamp(
              0.0,
              1.0,
            ),
            'Uploading images...\n'
                '${currentImagePosition.round()} '
                'of $totalImages',
          );
        },
      );

      final String responseText =
      response.data
          .toString()
          .trim();

      if (!responseText.startsWith('{')) {
        throw Exception(
          'Image server did not return '
              'valid JSON:\n$responseText',
        );
      }

      final dynamic decoded =
      jsonDecode(responseText);

      if (decoded is! Map) {
        throw Exception(
          'Invalid image upload response.',
        );
      }

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(
        decoded,
      );

      if (data['status'] != 'success') {
        throw Exception(
          data['message'] ??
              'Image upload failed.',
        );
      }

      final int uploaded =
          int.tryParse(
            data['uploaded']
                ?.toString() ??
                '0',
          ) ??
              0;

      final int skipped =
          int.tryParse(
            data['skipped']
                ?.toString() ??
                '0',
          ) ??
              0;

      final int failed =
          int.tryParse(
            data['failed']
                ?.toString() ??
                '0',
          ) ??
              0;

      totalUploaded += uploaded;
      totalSkipped += skipped;
      totalFailed += failed;

      print('COUNT IMAGE BATCH COMPLETE');
      print('Uploaded: $uploaded');
      print('Skipped : $skipped');
      print('Failed  : $failed');

      if (failed > 0) {
        throw Exception(
          '$failed image(s) failed '
              'in batch $start-$end',
        );
      }
    } catch (e) {
      print('COUNT IMAGE BATCH FAILED');
      print(
        'Batch: ${start + 1}-$end '
            'of $totalImages',
      );
      print('Error: $e');

      // Do not mark the count as fully synced.
      rethrow;
    }
  }

  print('COUNT IMAGE UPLOAD COMPLETE');
  print(
    'Total local images: $totalLocalImages',
  );
  print(
    'Already on server: $alreadyUploaded',
  );
  print(
    'Uploaded: $totalUploaded',
  );
  print(
    'Skipped: $totalSkipped',
  );
  print(
    'Failed: $totalFailed',
  );

  onProgress?.call(
    1.0,
    'Images upload complete!',
  );
}

Future<List<File>> getImagesNotOnServer(
    List<File> imageFiles,
    Dio dio,
    ) async {
  if (imageFiles.isEmpty) {
    return [];
  }

  final List<File> missingFiles = [];

  // Check in groups so we don't create
  // an excessively large request.
  const int checkBatchSize = 500;

  for (
  int start = 0;
  start < imageFiles.length;
  start += checkBatchSize
  ) {
    final int end =
    (start + checkBatchSize < imageFiles.length)
        ? start + checkBatchSize
        : imageFiles.length;

    final List<File> batch =
    imageFiles.sublist(start, end);

    final List<String> filenames = batch
        .map(
          (file) => file.path.split('/').last,
    )
        .toList();

    print(
      'Checking server images '
          '${start + 1}-$end of ${imageFiles.length}',
    );

    final FormData formData = FormData();

    formData.fields.add(
      MapEntry(
        'filenames',
        jsonEncode(filenames),
      ),
    );

    final response = await dio.post(
      '${ServerUrl.current}mapi/checkImages',
      data: formData,
      options: Options(
        headers: {
          'Content-Type': 'multipart/form-data',
        },
        responseType: ResponseType.plain,
      ),
    );
    print(
      'CHECK IMAGE STATUS: ${response.statusCode}',
    );

    print(
      'CHECK IMAGE RESPONSE: ${response.data}',
    );

    final String responseText =
    response.data.toString().trim();

    if (!responseText.startsWith('{')) {
      throw Exception(
        'Server did not return valid JSON while checking images:\n'
            '$responseText',
      );
    }

    final dynamic decoded =
    jsonDecode(responseText);

    if (decoded is! Map) {
      throw Exception(
        'Invalid server response while checking images.',
      );
    }

    final Map<String, dynamic> data =
    Map<String, dynamic>.from(decoded);

    if (data['status'] != 'success') {
      throw Exception(
        data['message'] ??
            'Failed to check server images',
      );
    }

    final List<dynamic> missing =
    data['missing'] is List
        ? List<dynamic>.from(data['missing'])
        : [];

    final Set<String> missingNames = missing
        .map(
          (value) => value
          .toString()
          .trim()
          .toLowerCase(),
    )
        .where(
          (value) => value.isNotEmpty,
    )
        .toSet();

    // Add only files that the server reported as missing.
    for (final File file in batch) {
      final String filename =
          file.path.split('/').last;

      if (missingNames.contains(
        filename.toLowerCase(),
      )) {
        missingFiles.add(file);
      }
    }

    final int existingCount =
        int.tryParse(
          data['existing_count']?.toString() ?? '0',
        ) ??
            0;

    final int missingCount =
        int.tryParse(
          data['missing_count']?.toString() ?? '0',
        ) ??
            0;

    print(
      'Server existing: $existingCount',
    );
    print(
      'Server missing : $missingCount',
    );
    print(
      'Local files selected for upload so far: '
          '${missingFiles.length}',
    );
  }

  return missingFiles;
}
