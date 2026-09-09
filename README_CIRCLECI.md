# ELIM — version finale CircleCI

Projet Flutter Android préparé pour CircleCI.

Variables CircleCI :
- API_BASE_URL : URL HTTPS du backend ELIM.
- FIREBASE_ANDROID_JSON_B64 : base64 de google-services.json, si Firebase Android est activé.

Pipeline :
1. installation Flutter
2. flutter pub get
3. injection Firebase optionnelle
4. flutter analyze
5. flutter test
6. flutter build apk --release
7. flutter build appbundle --release
8. publication APK et AAB comme artifacts

La signature Play Store doit être ajoutée via les secrets CircleCI ; aucun keystore ne doit être envoyé dans Git.
