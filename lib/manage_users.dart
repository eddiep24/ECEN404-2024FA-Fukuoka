import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageUsersPage extends StatefulWidget {
  @override
  _ManageUsersPageState createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  final _nameRegex = RegExp(r'^[a-zA-Z\s-]+$');
  bool _isFormValid = false;

  TextEditingController _emailController = TextEditingController();
  TextEditingController _firstNameController = TextEditingController();
  TextEditingController _lastNameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    setState(() {
      _isFormValid = _formKey.currentState?.validate() ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Users',style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              _showAddUserDialog(context);
            },
          ),
        ],
      ),
      body: _buildUserList(),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text('No users available.'),
          );
        } else {
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final userData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              final userEmail = userData['email'];
              final userFirstName = userData['firstname'];
              final userLastName = userData['lastname'];

              return Card(
                elevation: 4,
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('$userFirstName $userLastName'),
                  subtitle: Text(userEmail),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {
                      _showDeleteConfirmationDialog(context, snapshot.data!.docs[index].id);
                    },
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add User'),
              content: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: () {
                  setState(() {
                    _isFormValid = _formKey.currentState?.validate() ?? false;
                  });
                },
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Email is required';
                          }
                          if (!_emailRegex.hasMatch(value)) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'First name is required';
                          }
                          if (!_nameRegex.hasMatch(value)) {
                            return 'Only letters, spaces, and hyphens allowed';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Last name is required';
                          }
                          if (!_nameRegex.hasMatch(value)) {
                            return 'Only letters, spaces, and hyphens allowed';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _clearTextFields();
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: _isFormValid ? () {
                    _addUser();
                    _clearTextFields();
                    Navigator.pop(context);
                  } : null,
                  child: Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _clearTextFields() {
    _emailController.clear();
    _firstNameController.clear();
    _lastNameController.clear();
    _passwordController.clear();
    if (_formKey.currentState != null) {
      _formKey.currentState!.reset();
    }
    setState(() {
      _isFormValid = false;
    });
  }

  void _addUser() {
    FirebaseFirestore.instance
      .collection('users')
      .where('email', isEqualTo: _emailController.text.trim())
      .get()
      .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email already exists'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        FirebaseFirestore.instance.collection('users').add({
          'email': _emailController.text.trim(),
          'firstname': _firstNameController.text.trim(),
          'lastname': _lastNameController.text.trim(),
          'password': _passwordController.text.trim(),
        }).then((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }).catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding user: $error'),
              backgroundColor: Colors.red,
            ),
          );
        });
      });
  }

  void _showDeleteConfirmationDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text('Are you sure you want to delete this user?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteUser(userId);
                Navigator.pop(context);
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _deleteUser(String userId) {
    FirebaseFirestore.instance.collection('users').doc(userId).delete().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting user: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }
}