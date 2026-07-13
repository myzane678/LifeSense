import 'package:flutter/foundation.dart';

bool get isWindowsLocalMode =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
