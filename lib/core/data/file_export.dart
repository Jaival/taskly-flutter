import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'file_export_share.dart'
    if (dart.library.js_interop) 'file_export_browser.dart';

/// A file made by the app for the user to keep.
@immutable
class ExportFile {
  const ExportFile({
    required this.name,
    required this.mimeType,
    required this.text,
  });

  /// With its extension: `tasks.csv`.
  final String name;
  final String mimeType;
  final String text;
}

/// Hands a file to the user: a download in a browser, the share sheet
/// ("Save to Files", "Send to…") in the apps. False if they closed the
/// sheet without choosing anything.
typedef SaveFile = Future<bool> Function(ExportFile file);

final saveFileProvider = Provider<SaveFile>((ref) => saveFile);
