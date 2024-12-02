# Fukuoka Glucose Sensor Code

The arduino directory contains the code that we would upload to the ESP-32 module on our PCB using Android Studio. The rest of the folders/files exist to support the glucose sensor mobile app. To run the app, run `flutter emulators --launch [EMULATOR]`, once the emulator launches run `flutter run` 

There is some Firebase configuration required, and there are some assumptions this app makes about the Firebase Realtime Database. Most are self-explanatory, but it's important to note that we have a Cloud Function setup to create a new test entry every time the 'SensorTest/CurrentTest' variable is changed in the Realtime Database.
