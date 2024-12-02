import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:volume_controller/volume_controller.dart';
import 'dart:async';
import 'analytics.dart';
import 'manage_users.dart';

class MenuPage extends StatefulWidget {
  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.reference();
  final VolumeController _volumeController = VolumeController();
  String? _activeSensor;
  List<String> _sensorList = [];
  bool _isLoading = true;
  Timer? _volumeTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _volumeTimer?.cancel();
    super.dispose();
  }


  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DataSnapshot snapshot = await _dbRef.once().then((event) => event.snapshot);
      Map<dynamic, dynamic>? data = snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        setState(() {
          _sensorList = data.keys.where((key) => key != 'CurrentTest').cast<String>().toList();
          _activeSensor = data['CurrentTest'] as String?;
          
          if (_activeSensor == null || !_sensorList.contains(_activeSensor)) {
            _activeSensor = _sensorList.isNotEmpty ? _sensorList.first : null;
            _dbRef.child('CurrentTest').set(_activeSensor);
          }
        });
      }
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addNewEntry() async {
    String? newEntryName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String entryName = '';
        String? errorText;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add New Entry'),
              content: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter new entry name',
                  errorText: errorText,
                ),
                onChanged: (value) async {
                  entryName = value;
                  
                  if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
                    setState(() {
                      errorText = 'Only alphanumeric characters allowed';
                    });
                    return;
                  }
                  
                  // Check if entry already exists
                  DataSnapshot snapshot = await _dbRef.child(value).once()
                      .then((event) => event.snapshot);
                  
                  setState(() {
                    errorText = snapshot.value != null 
                        ? 'Entry already exists' 
                        : null;
                  });
                },
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('Add'),
                  onPressed: errorText == null && entryName.isNotEmpty
                    ? () => Navigator.of(context).pop(entryName)
                    : null,
                ),
              ],
            );
          },
        );
      },
    );

    if (newEntryName != null && newEntryName.isNotEmpty) {
      try {
        await _dbRef.child(newEntryName).set({
          'time_created': ServerValue.timestamp,
        });
        await _loadData();
      } catch (e) {
        print('Firebase error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
appBar: AppBar(
  title: Text(
    'Menu Page',
    style: TextStyle(color: Colors.white),
  ),
  actions: [
    IconButton(
      icon: Icon(Icons.manage_accounts, color: Colors.white),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ManageUsersPage()),
        );
      },
    ),
  ],
),

      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildActiveSensorDropdown(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: _buildChildrenList(),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewEntry,
        child: Icon(Icons.add),
        tooltip: 'Add New Sensor Test',
      ),
    );
  }

  Widget _buildActiveSensorDropdown() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Text('Active Sensor: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _activeSensor,
              items: _sensorList.map((String sensor) {
                return DropdownMenuItem<String>(
                  value: sensor,
                  child: Text(sensor),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _activeSensor = newValue;
                  });
                  _dbRef.child('CurrentTest').set(newValue);
                }
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildrenList() {
    return ListView.builder(
      physics: AlwaysScrollableScrollPhysics(),
      itemCount: _sensorList.length,
      itemBuilder: (context, index) {
        final childKey = _sensorList[index];
        
        return Dismissible(
          key: Key(childKey),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 20.0),
            color: Colors.red,
            child: Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Confirm Delete'),
                  content: Text('Are you sure you want to delete $childKey?'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('Delete'),
                    ),
                  ],
                );
              },
            );
          },
          onDismissed: (direction) async {
            await _dbRef.child(childKey).remove();
            await _loadData();
          },
          child: Card(
            elevation: 4,
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(
                childKey,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AnalyticsPage(childKey)),
                );
              },
            ),
          ),
        );
      },
    );
  }
}