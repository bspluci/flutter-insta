import 'dart:convert';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

FirebaseStorage _storage = FirebaseStorage.instance;
FirebaseFirestore _store = FirebaseFirestore.instance;
FirebaseAuth _auth = FirebaseAuth.instance;

class Test extends StatefulWidget {
  const Test({super.key});

  @override
  State<Test> createState() => _TestState();
}

class _TestState extends State<Test> {
  _init() {
    print('hello');
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AboutDialog(
        applicationName: 'test',
        applicationVersion: '1.0.0',
        applicationIcon: Icon(Icons.ac_unit),
        children: [
          Text('test'),
          Text('test'),
          Text('test'),
          Text('test'),
          Text('test'),
          Text('test'),
        ],
      ),
    );
  }
}
