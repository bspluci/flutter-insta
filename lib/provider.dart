import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'notification.dart';

class DataProvider extends ChangeNotifier {
  List<dynamic> resultUser = [
    {'_id': '', 'image': '', 'name': '', 'fallower': 0}
  ];
  List<dynamic> resultGallery = [''];
  bool clickFallower = false;

  getUserInfo() async {
    Map getUser = {};
    final url = Platform.isAndroid
        ? 'http://172.20.59.28:8080'
        : 'http://localhost:8080';
    final result = await http.get(Uri.parse('$url/api/member/getMemberList'));

    if (result.statusCode == 200) {
      getUser = jsonDecode(result.body);
      resultUser = getUser['data']
          .map((item) => {
                '_id': item['_id'],
                'name': item['name'],
                'image': item['image'],
                'fallower': addCommasToNumber(item['fallower']),
              })
          .toList();
      notifyListeners();
      await showNotification(1, '유저 정보 로드 완료', '유저 정보가 성공적으로 로드되었습니다.');
      // await showNotificationTime();
    } else {
      print(result.statusCode);
      await showNotification(
          1, '유저 정보 로드 실패', '유저 정보 로드에 실패하였습니다. 다시 시도해 주세요.');
    }

    getUserGallery();
  }

  getUserGallery() async {
    final result = await http
        .get(Uri.parse('https://codingapple1.github.io/app/profile.json'));

    if (result.statusCode == 200) {
      resultGallery = jsonDecode(result.body);
      resultGallery = [...resultGallery, ...resultGallery, ...resultGallery];
      notifyListeners();
    } else {
      print(result.statusCode);
    }
  }

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

  void incFollower() {
    String fallower = resultUser[0]['fallower'];
    int fallowerInt = int.parse(fallower.replaceAll(',', ''));

    clickFallower ? fallowerInt-- : fallowerInt++;
    resultUser[0]['fallower'] = addCommasToNumber(fallowerInt);
    clickFallower = !clickFallower;
    notifyListeners();
  }
}
