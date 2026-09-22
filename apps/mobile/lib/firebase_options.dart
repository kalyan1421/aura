// Hand-written in the shape `flutterfire configure` generates (Firebase
// project aura-akvega, #956426842892). Values match
// ios/Runner/GoogleService-Info.plist and android/app/google-services.json.
// These identifiers are not secrets.
//
// Only Cloud Messaging is used. No Analytics (PostHog) and no Crashlytics
// (Sentry).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBKGOd7S4MXxIXYaFe7iElOIGJicdU04e8',
    appId: '1:956426842892:android:20ef7ce4eb781630054f29',
    messagingSenderId: '956426842892',
    projectId: 'aura-akvega',
    storageBucket: 'aura-akvega.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCxVndlwMR1OJFFmeYm84vfyZCBm0cu1PE',
    appId: '1:956426842892:ios:7647d941266f90c2054f29',
    messagingSenderId: '956426842892',
    projectId: 'aura-akvega',
    storageBucket: 'aura-akvega.firebasestorage.app',
    iosBundleId: 'com.akvega.aura',
  );
}
