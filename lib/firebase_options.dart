import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB7eMIBcjn3FPd2ttvYUTNvbY1lWdwmyUI',
    appId: '1:638501990674:web:9abf796a5a02671d1843cb',
    messagingSenderId: '638501990674',
    projectId: 'connectcall-b60a7',
    authDomain: 'connectcall-b60a7.firebaseapp.com',
    storageBucket: 'connectcall-b60a7.firebasestorage.app',
    measurementId: 'G-PM49TF1CKY',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC5bUZ6qmp-5gUMT5bl5BhwxUMtHWlMIMU',
    appId: '1:638501990674:android:994914b85d4cc6bd1843cb',
    messagingSenderId: '638501990674',
    projectId: 'connectcall-b60a7',
    storageBucket: 'connectcall-b60a7.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCQKgtyrjigHo7_Kcrq33yArnayMzt3Mi4',
    appId: '1:638501990674:ios:e514ea9cda5e1bc21843cb',
    messagingSenderId: '638501990674',
    projectId: 'connectcall-b60a7',
    storageBucket: 'connectcall-b60a7.firebasestorage.app',
    androidClientId: '638501990674-ckh6521n0nfo7b79i0o8bvcn3mcddi1d.apps.googleusercontent.com',
    iosClientId: '638501990674-n7g8vmd6mlm7n4igd8acg3iur0153a4i.apps.googleusercontent.com',
    iosBundleId: 'com.example.connectcall',
  );
}
