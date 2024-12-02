import 'package:flutter/material.dart';
import 'menu.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController _usernameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  String? _errorText;
  bool _isObscured = true; // Indicates whether the password is obscured or not

  void _togglePasswordVisibility() {
    setState(() {
      _isObscured = !_isObscured;
    });
  }

  void _login() async {
    setState(() {
      _errorText = null;
    });

    String username = _usernameController.text;
    String password = _passwordController.text;

    final usersCollection = FirebaseFirestore.instance.collection('users');
    final querySnapshot = await usersCollection.get();

    bool isLoggedIn = false;

    for (var doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userEmail = data["email"];
      final userPassword = data["password"];

      if (username == userEmail && password == userPassword) {
        isLoggedIn = true;
        break;
      }
    }

    if (!isLoggedIn) {
      setState(() {
        _errorText = 'Incorrect username or password';
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MenuPage()),
      );
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    // backgroundColor: Color(0xFFFFF8E1), // Cream color
    appBar: AppBar(
        title: Text(
    'Fukuoka',
    style: TextStyle(color: Colors.white),
  ),

    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Glucose Monitoring Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20.0),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20.0),
            TextField(
              controller: _passwordController,
              obscureText: _isObscured, 
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_isObscured ? Icons.visibility : Icons.visibility_off),
                  onPressed: _togglePasswordVisibility,
                ),
              ),
            ),
            SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: _login,
              child: Text('Login'),
            ),
            SizedBox(height: 10.0),
            if (_errorText != null)
              Text(
                _errorText!,
                // style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    ),
  );
}


}
