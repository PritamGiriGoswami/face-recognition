import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String?> pickImageFromFile() {
  final completer = Completer<String?>();

  final input = html.FileUploadInputElement()..accept = 'image/*';

  void completeOnce([String? value]) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
  }

  input.onChange.listen((event) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completeOnce(null);
      return;
    }

    final file = files.first;
    final reader = html.FileReader();

    reader.onLoadEnd.listen((e) {
      final result = reader.result;

      if (result is ByteBuffer) {
        final bytes = Uint8List.view(result);
        final b64 = base64Encode(bytes);
        completeOnce('data:${file.type};base64,$b64');
      } else {
        completeOnce(null);
      }
    });

    reader.onError.listen((e) {
      completeOnce(null);
    });

    reader.readAsArrayBuffer(file);
  });

  input.click();
  return completer.future;
}
