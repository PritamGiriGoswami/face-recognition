// Provides `pickImageFromFile()` via conditional imports.
export 'image_picker_io.dart' if (dart.library.html) 'image_picker_web.dart';
