import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'file_export.dart';

/// Downloads [file], as a link with `download` set does.
Future<bool> saveFile(ExportFile file) async {
  final blob = web.Blob(
    [utf8.encode(file.text).toJS].toJS,
    web.BlobPropertyBag(type: '${file.mimeType};charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = file.name
    ..style.display = 'none';
  web.document.body!.append(link);
  link.click();
  link.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
