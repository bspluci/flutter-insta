import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'provider.dart';

class MyInfo extends StatefulWidget {
  const MyInfo({Key? key}) : super(key: key);

  @override
  State<MyInfo> createState() => _MyInfoState();
}

class _MyInfoState extends State<MyInfo> {
  bool isLoading = false;
  UserModel? user;

  void setTitleText() {
    Provider.of<AppBarTitle>(context, listen: false).setTitle('MyInfo');
  }

  void getMyInfomationFromProvider() {
    user = Provider.of<UserProvider>(context, listen: false).user;
  }

  @override
  void initState() {
    super.initState();
    getMyInfomationFromProvider();
    Future.delayed(Duration.zero, setTitleText);
  }

  @override
  Widget build(BuildContext context) {
    TextStyle contentStyle = const TextStyle(fontSize: 20, color: Colors.black);
    TextStyle titleStyle = const TextStyle(fontSize: 30, color: Colors.black);

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  alignment: Alignment.topCenter,
                  margin: const EdgeInsets.only(top: 20),
                  child: Text('${user?.displayName ?? ''}님의 정보',
                      style: titleStyle),
                ),
                Container(
                    alignment: Alignment.topCenter,
                    margin: const EdgeInsets.all(20),
                    child: user?.photoURL != null
                        ? Image.network(
                            user?.photoURL ?? '',
                            fit: BoxFit.cover,
                            height: 250,
                          )
                        : const Text('No Image', style: TextStyle(height: 5))),
                Container(
                  alignment: Alignment.topLeft,
                  margin: const EdgeInsets.all(10),
                  child: Text('이름: ${user?.displayName}', style: contentStyle),
                ),
                Container(
                  alignment: Alignment.topLeft,
                  margin: const EdgeInsets.all(10),
                  child: Text('이메일: ${user?.email}', style: contentStyle),
                ),
                Container(
                  alignment: Alignment.topLeft,
                  margin: const EdgeInsets.all(10),
                  child: Text('UID: ${user?.uid}', style: contentStyle),
                ),
              ],
            ),
    );
  }
}
