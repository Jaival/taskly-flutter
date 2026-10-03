import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import 'file_export.dart';

/// Opens the share sheet with [file], from which it can be saved or sent.
Future<bool> saveFile(ExportFile file) async {
  final result = await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          utf8.encode(file.text),
          name: file.name,
          mimeType: file.mimeType,
        ),
      ],
      fileNameOverrides: [file.name],
    ),
  );
  return result.status != ShareResultStatus.dismissed;
}
