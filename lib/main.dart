import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'homepage.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts package
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
     return MaterialApp(
      locale: Locale('zh'),
      title: AppLocalizations.of(context)?.appTitle ?? 'Fukuoka',
  
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('en'), 
        Locale('zh'),
      ],
      theme: ThemeData(        
        primaryColor: Color.fromRGBO(139, 0, 41, 1), // Waseda burgundy
        scaffoldBackgroundColor: Colors.grey[200],
        fontFamily: GoogleFonts.openSans().fontFamily,
        appBarTheme: AppBarTheme(
          color: Color.fromRGBO(139, 0, 41, 1), // Waseda burgundy
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: LoginPage(),
    );
  }
}