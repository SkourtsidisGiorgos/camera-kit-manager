import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web platform is not supported');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS platform is not configured');
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBBVtq8McPekM87Kkq8cffHCJIZsEWZnXY',
    appId: '1:118094697619:android:0df95814bf78a0352f6966',
    messagingSenderId: '118094697619',
    projectId: 'camera-kit-manager-89acd',
    storageBucket: 'camera-kit-manager-89acd.firebasestorage.app',
  );
}
