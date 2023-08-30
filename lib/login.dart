import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'notification.dart';
import 'provider.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  String email = '';
  String password = '';
  bool isLoading = false;

  Future<dynamic> memberLogin(context) async {
    if (email.isEmpty || password.isEmpty) {
      await showInvalidInputNotification(context, "이메일과 비밀번호를 입력해주세요.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = UserModel(
        uid: userCredential.user!.uid,
        displayName: userCredential.user!.displayName,
        email: userCredential.user!.email,
        photoURL: userCredential.user!.photoURL,
      );
      Provider.of<UserProvider>(context, listen: false).setUser(user);

      await showNotification(1, '로그인 완료', '정상적으로 로그인 완료됐습니다.');

      setState(() => isLoading = false);
      Navigator.pop(context, true);
      Navigator.of(context).pushNamed('/');
    } on FirebaseAuthException catch (e) {
      print(e.code);
      setState(() => isLoading = false);

      if (e.code == 'user-not-found') {
        await showInvalidInputNotification(context, '사용자를 찾을 수 없습니다.');
      } else if (e.code == 'wrong-password') {
        await showInvalidInputNotification(context, '비밀번호가 틀렸습니다.');
      } else if (e.code == 'user-disabled') {
        await showInvalidInputNotification(context, '사용자가 비활성화되었습니다.');
      } else {
        // 그 외의 에러 처리
        await showInvalidInputNotification(context, '알 수 없는 오류입니다.');
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("로그인"),
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              margin: const EdgeInsets.only(top: 100),
              child: ListView(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 20),
                      child: FractionallySizedBox(
                        widthFactor: 0.9,
                        child: TextField(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: '이메일',
                          ),
                          onChanged: (text) {
                            setState(
                              () => email = text,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 20),
                      child: FractionallySizedBox(
                        widthFactor: 0.9,
                        child: TextField(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: '비밀번호',
                          ),
                          onChanged: (text) {
                            setState(
                              () => password = text,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 5),
                          child: ElevatedButton(
                            onPressed: () => memberLogin(context),
                            child: const Text('로그인'),
                          ),
                        ),
                        //
                        Container(
                          margin: const EdgeInsets.only(left: 5),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('취소'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
