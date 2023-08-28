import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart'; // Navigator 클래스를 import

import 'notification.dart';

final firestore = FirebaseFirestore.instance;
final FirebaseAuth _auth = FirebaseAuth.instance;

class UserModel {
  final String uid;
  final String displayName;
  final String email;

  UserModel(
      {required this.uid, required this.displayName, required this.email});
}

// 프로바이더 클래스
class UserProvider extends ChangeNotifier {
  UserModel? _user;

  UserModel? get user => _user;

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  logout(context) async {
    await _auth.signOut();

    _user = null;

    await showNotification(5, '로그아웃 완료', '정상적으로 로그아웃 완료됐습니다.');
    Navigator.of(context).pushNamed('/');
    notifyListeners();
  }
}

class AppBarTitle extends ChangeNotifier {
  String _title = 'Home';

  String get title => _title;

  void setTitle(String title) {
    _title = title;
    notifyListeners();
  }
}

class DataProvider extends ChangeNotifier {
  // Map<String, dynamic> resultUser = {};
  // List<dynamic> resultGallery = [];

  // void getUserInfo() async {
  // Map getUser = {};
  // final url = Platform.isAndroid
  //     ? 'http://172.20.59.28:8080'
  //     : 'http://localhost:8080';
  // final result = await http.get(Uri.parse('$url/api/member/getMemberList'));

  // if (result.statusCode == 200) {
  //   getUser = jsonDecode(result.body);
  //   resultUser = getUser['data']
  //       .map((item) => {
  //             '_id': item['_id'],
  //             'name': item['name'],
  //             'image': item['image'],
  //             'follower': addCommasToNumber(item['follower']),
  //           })
  //       .toList();
  //   notifyListeners();
  //   await showNotification(1, '유저 정보 로드 완료', '유저 정보가 성공적으로 로드되었습니다.');
  //   // await showNotificationTime();
  // } else {
  //   print(result.statusCode);
  //   await showNotification(
  //       1, '유저 정보 로드 실패', '유저 정보 로드에 실패하였습니다. 다시 시도해 주세요.');
  // }
  // await getUserGallery();
  // }

  // getUserGallery() async {
  //   final result = await http
  //       .get(Uri.parse('https://codingapple1.github.io/app/profile.json'));

  //   if (result.statusCode == 200) {
  //     resultGallery = jsonDecode(result.body);
  //     resultGallery = [...resultGallery, ...resultGallery, ...resultGallery];
  //     notifyListeners();
  //   } else {
  //     print(result.statusCode);
  //   }
  // }

  String addCommasToNumber(int number) {
    if (number < 1000) return number.toString();

    String result = '';
    String numberStr = number.toString();

    int count = 0;
    for (int i = numberStr.length - 1; i >= 0; i--) {
      result = numberStr[i] + result;
      count++;

      if (count % 3 == 0 && i != 0) {
        result = ',' + result;
      }
    }

    return result;
  }
}
