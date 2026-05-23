import 'dart:async';

Future<String?> pickImageFromFile() async {
  // Not supported on non-web in this utility. Return null so callers
  // can fall back to camera plugin.
  return null;
}
