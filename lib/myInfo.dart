import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'notification.dart';
import 'provider.dart';

class MyInfo extends StatefulWidget {
  const MyInfo({Key? key}) : super(key: key);

  @override
  State<MyInfo> createState() => _MyInfoState();
}

class _MyInfoState extends State<MyInfo> {
  bool isLoading = false;

  void setTitleText() {
    Provider.of<AppBarTitle>(context, listen: false).setTitle('MyInfo');
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, setTitleText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : const SizedBox(
              child: Text('내정보'),
            ),
    );
  }
}
