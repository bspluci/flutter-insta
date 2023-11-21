import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import 'notification.dart';

final FirebaseFirestore _store = FirebaseFirestore.instance;
final FirebaseAuth _auth = FirebaseAuth.instance;

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  String email = '';
  String password = '';
  bool isLoading = false;
  bool _obscureText = true;

  // 로그인 완료 후 홈으로 이동
  loginSuccess(context) async {
    setState(() => isLoading = true);
    Navigator.of(context).pushReplacementNamed('/');
  }

  Future<void> signInWithKakao(context) async {
    setState(() => isLoading = true);
    Map<String, dynamic> firebaseAuthDataSource;
    // 카카오톡 실행 가능 여부 확인
    // 카카오톡 실행이 가능하면 카카오톡으로 로그인, 아니면 카카오계정으로 로그인
    try {
      kakao.OAuthToken token = await kakao.isKakaoTalkInstalled()
          ? await kakao.UserApi.instance.loginWithKakaoTalk()
          : await kakao.UserApi.instance.loginWithKakaoAccount();
      final kakao.User kakaoUser = await kakao.UserApi.instance.me();

      firebaseAuthDataSource = ({
        'uid': kakaoUser.id.toString(),
        'displayName': kakaoUser.kakaoAccount!.profile!.nickname,
        'email': kakaoUser.kakaoAccount!.email,
        'photoURL': kakaoUser.kakaoAccount!.profile!.profileImageUrl,
        'token': token.accessToken,
        'provider': 'kakao',
      });

      String url = 'https://createcustomtoken-q76gx7it5q-uc.a.run.app';
      final firebaseToken =
          await http.post(Uri.parse(url), body: firebaseAuthDataSource);

      await _auth.signInWithCustomToken(jsonEncode(firebaseToken.body));

      final user = _auth.currentUser;
      if (user != null) {
        await _store.collection('members').doc(user.uid).set({
          'uid': user.uid,
          'displayName': user.displayName ?? '', // 사용자 이름
          'email': user.email ?? '', // 사용자 이메일
          'photoURL': user.photoURL ?? '', // 프로필 사진 URL
          // 추가 정보 추가 가능
        });
      }

      loginSuccess(context);
    } catch (error) {
      if (error is PlatformException && error.code == 'CANCELED') {
        await showSnackBar(context, '로그인 취소: 카카오 로그인을 취소하였습니다.');
        setState(() => isLoading = false);
        return;
      }
      setState(() => isLoading = false);
      await showSnackBar(context, '에러: $error');
    }
  }

  // 페이스북 로인
  Future<void> signInWithFacebook(context) async {
    setState(() => isLoading = true);
    // Trigger the sign-in flow
    final LoginResult loginResult = await FacebookAuth.instance.login();

    if (loginResult.accessToken == null) {
      await showSnackBar(context, '로그인 취소: 페이스북 로그인을 취소하였습니다.');
      setState(() => isLoading = false);
      return;
    }

    // Create a credential from the access token
    final OAuthCredential facebookAuthCredential =
        FacebookAuthProvider.credential(loginResult.accessToken!.token);

    // Once signed in, return the UserCredential
    try {
      await _auth.signInWithCredential(facebookAuthCredential);
      final user = _auth.currentUser;

      if (user != null) {
        await _store.collection('members').doc(user.uid).set({
          'uid': user.uid,
          'displayName': user.displayName ?? '', // 사용자 이름
          'email': user.email ?? '', // 사용자 이메일 (Facebook으로부터 얻을 수 있다면)
          'photoURL': user.photoURL ?? '', // 프로필 사진 URL (Facebook으로부터 얻을 수 있다면)
          // 추가 정보 추가 가능
        });
      }

      loginSuccess(context);
    } catch (e) {
      await showSnackBar(context, '에러: $e');
      setState(() => isLoading = false);
    }
  }

  // 구글 로그인
  Future<void> signInWithGoogle(context) async {
    setState(() => isLoading = true);

    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

    final GoogleSignInAuthentication? googleAuth =
        await googleUser?.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );

    try {
      await _auth.signInWithCredential(credential).then(
        (value) {
          loginSuccess(context);
        },
      );
    } on FirebaseAuthException catch (e) {
      await showSnackBar(context, '에러: $e');

      setState(() => isLoading = false);
    }
  }

  // 이메일 로그인
  Future<dynamic> memberLogin(context) async {
    if (email.isEmpty || password.isEmpty) {
      await showSnackBar(context, "이메일과 비밀번호를 입력해주세요.");
      return;
    }

    setState(() => isLoading = true);

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      loginSuccess(context);
    } on FirebaseAuthException catch (e) {
      await showSnackBar(context, '에러: $e');
      setState(() => isLoading = false);

      if (e.code == 'user-not-found') {
        await showSnackBar(context, '사용자를 찾을 수 없습니다.');
      } else if (e.code == 'wrong-password') {
        await showSnackBar(context, '비밀번호가 틀렸습니다.');
      } else if (e.code == 'user-disabled') {
        await showSnackBar(context, '사용자가 비활성화되었습니다.');
      } else {
        // 그 외의 에러 처리
        await showSnackBar(context, '알 수 없는 오류입니다.');
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ListView(
                shrinkWrap: true, // shrinkWrap을 true로 설정
                children: [
                  const Center(
                    heightFactor: 2,
                    child: Text("로그인",
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.bold)),
                  ),
                  Center(
                    child: Container(
                      height: 50,
                      margin: const EdgeInsets.only(bottom: 20),
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
                    child: SizedBox(
                      height: 50,
                      child: FractionallySizedBox(
                        widthFactor: 0.9,
                        child: TextField(
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: '비밀번호',
                            suffixIcon: IconButton(
                              icon: Icon(_obscureText
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () {
                                setState(() {
                                  _obscureText = !_obscureText;
                                });
                              },
                            ),
                          ),
                          obscureText: _obscureText,
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
                          width: 80,
                          margin: const EdgeInsets.only(right: 5),
                          child: ElevatedButton(
                            onPressed: () => memberLogin(context),
                            child: const Text('로그인'),
                          ),
                        ),
                        Container(
                          width: 80,
                          margin: const EdgeInsets.only(left: 5),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('취소'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 170,
                          child: ElevatedButton(
                            onPressed: () => signInWithGoogle(context),
                            child: const Text('구글 로그인'),
                          ),
                        ),
                        SizedBox(
                          width: 170,
                          child: ElevatedButton(
                            onPressed: () => signInWithFacebook(context),
                            child: const Text('페이스북 로그인'),
                          ),
                        ),
                        SizedBox(
                          width: 170,
                          child: ElevatedButton(
                            onPressed: () => signInWithKakao(context),
                            child: const Text('카카오 로그인'),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
