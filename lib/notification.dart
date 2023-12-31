import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'shop.dart';

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

//1. 앱로드시 실행할 기본설정
initNotification(context) async {
  void onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) async {
    final String payload = notificationResponse.payload ?? '';
    if (payload == 'shop') {
      // 페이지 이동
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => const Shop(),
      ));
    }
  }

  //안드로이드용 아이콘파일 이름
  const AndroidInitializationSettings androidSetting =
      AndroidInitializationSettings('@drawable/ic_launcher');

  //ios에서 앱 로드시 유저에게 권한요청하려면
  const DarwinInitializationSettings iosSetting = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings =
      InitializationSettings(android: androidSetting, iOS: iosSetting);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);
}

requestPermission() {
  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
}

showNotification(int id, String title, String content) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'instagramPost',
    'channel_instagramPost',
    priority: Priority.high,
    importance: Importance.max,
    color: Color.fromARGB(255, 255, 0, 0),
    ticker: 'ticker',
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  // 알림 id, 제목, 내용 맘대로 채우기
  flutterLocalNotificationsPlugin.show(id, title, content,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: 'main');
}

showNotificationTime() async {
  tz.initializeTimeZones();

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    '유니크한 알림 ID',
    '알림종류 설명',
    priority: Priority.high,
    importance: Importance.max,
    color: Color.fromARGB(255, 255, 0, 0),
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  flutterLocalNotificationsPlugin.zonedSchedule(
      2,
      '제목2',
      '내용2',
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '');
}

/// 스낵바 함수, 필수 파라메터로 context 와 문자열이 필요하며 노출 시간과 버튼클릭 함수를 넣을 수 있다.
Future<void> showSnackBar(BuildContext context, String message,
    {int? time, Function? onPressed}) async {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: Duration(seconds: time ?? 2), // 알림이 화면에 표시되는 기간을 지정합니다.
      content: Text(message),
      // action: SnackBarAction(
      //   label: '확인',
      //   onPressed: () {
      //     // Some code to undo the change.
      //     onPressed ?? ScaffoldMessenger.of(context).hideCurrentSnackBar();
      //   },
      // ),
    ),
  );
}
