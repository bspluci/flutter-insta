import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart'; // Navigator 클래스를 import

import 'notification.dart';

final firestore = FirebaseFirestore.instance;
final FirebaseAuth _auth = FirebaseAuth.instance;

class UserModel {
  String? uid;
  String? displayName;
  String? email;
  String? photoURL;

  UserModel(
      {required this.uid,
      required this.displayName,
      required this.email,
      required this.photoURL});
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

class TitleProvider extends ChangeNotifier {
  String _title = 'Home';

  String get title => _title;

  void setTitle(String title) {
    _title = title;
    notifyListeners();
  }
}

class DataProvider extends ChangeNotifier {
  String addCommasToNumber(int number) {
    if (number < 1000) return number.toString();
    String result = '';
    String numberStr = number.toString();
    int count = 0;

    for (int i = numberStr.length - 1; i >= 0; i--) {
      result = numberStr[i] + result;
      count++;

      if (count % 3 == 0 && i != 0) {
        result = ',$result';
      }
    }
    return result;
  }
}
