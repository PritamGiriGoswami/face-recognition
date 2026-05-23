import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<String?> pickImageFromFile() {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.click();
  input.onChange.listen((event) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = files.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoadEnd.listen((e) {
      final result = reader.result;
      if (result is ByteBuffer) {
        final bytes = Uint8List.view(result);
        final b64 = base64Encode(bytes);
        completer.complete('data:${file.type};base64,$b64');
      } else {
        completer.complete(null);
      }
    });
    reader.onError.listen((e) {
      completer.complete(null);
    });
  });
  return completer.future;
}
