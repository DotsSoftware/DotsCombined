import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UploadRequest extends StatefulWidget {
  @override
  _UploadRequestState createState() => _UploadRequestState();
}

class _UploadRequestState extends State<UploadRequest> {
  final _formKey = GlobalKey<FormState>();
  final _typeController = TextEditingController();
  final _levelController = TextEditingController();
  final _regionController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _idController = TextEditingController();
  String _status = 'Active';

  void _uploadRequest() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection('requests').add({
        'type': _typeController.text,
        'level': _levelController.text,
        'region': _regionController.text,
        'date': _dateController.text,
        'time': _timeController.text,
        'id': _idController.text,
        'status': _status,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request Uploaded Successfully')),
      );

      _formKey.currentState!.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Request'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _typeController,
                decoration: InputDecoration(labelText: 'Type'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a type';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _levelController,
                decoration: InputDecoration(labelText: 'Level'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a level';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _regionController,
                decoration: InputDecoration(labelText: 'Region'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a region';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _dateController,
                decoration: InputDecoration(labelText: 'Date'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a date';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _timeController,
                decoration: InputDecoration(labelText: 'Time'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a time';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _idController,
                decoration: InputDecoration(labelText: 'ID'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an ID';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: InputDecoration(labelText: 'Status'),
                items: <String>['Active', 'Pending', 'Closed', 'Cancelled']
                    .map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _status = newValue!;
                  });
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _uploadRequest,
                child: Text('Upload Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _typeController.dispose();
    _levelController.dispose();
    _regionController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _idController.dispose();
    super.dispose();
  }
}
