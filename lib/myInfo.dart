import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification.dart';
import 'provider.dart';

class MyInfo extends StatefulWidget {
  const MyInfo({Key? key}) : super(key: key);

  @override
  State<MyInfo> createState() => _MyInfoState();
}

class _MyInfoState extends State<MyInfo> {
  bool isLoading = false;
  UserModel? userProvider;
  File? selectedImage;
  XFile? pickedFile;
  Map<String, dynamic> userInfo = {
    'displayName': '',
    'email': '',
    'photoURL': '',
    'uid': ''
  };

  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _displayNameFocus = FocusNode();
  final _emailFocus = FocusNode();

  void setTitleText() {
    Provider.of<TitleProvider>(context, listen: false).setTitle('MyInfo');
  }

  // 내정보 처음 셋팅
  void getMyInfomationFromProvider() {
    userProvider = Provider.of<UserProvider>(context, listen: false).user;
    userInfo['displayName'] = userProvider?.displayName;
    userInfo['email'] = userProvider?.email;
    userInfo['uid'] = userProvider?.uid;
    _displayNameController.text = userProvider?.displayName ?? '';
    _emailController.text = userProvider?.email ?? '';
  }

  Future<void> selectImage() async {
    final ImagePicker picker = ImagePicker();
    pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() => selectedImage = File(pickedFile?.path ?? ''));
    setState(() => userInfo['photoURL'] = File(pickedFile?.path ?? ''));
  }

  void updateMemberInfo(context) async {
    setState(() => isLoading = true);

    try {
      // 최근 로그인된 상태 확인
      await FirebaseAuth.instance.currentUser?.reload();
      // 기존 이미지 파일 삭제
      if (!userProvider!.photoURL!.contains('default')) {
        final existingImageRef =
            FirebaseStorage.instance.refFromURL(userProvider!.photoURL ?? '');
        await existingImageRef.delete();
      }

      if (pickedFile != null) {
        final Reference storageReference = FirebaseStorage.instance.ref().child(
            'userProfileImages/${DateTime.now()}.${selectedImage?.path.split('.').last}');
        final UploadTask uploadTask = storageReference.putFile(
          File(pickedFile!.path),
        );

        await uploadTask.whenComplete(() async {
          final String downloadUrl = await storageReference.getDownloadURL();
          userInfo['photoURL'] = downloadUrl;
        });
      } else {
        userInfo['photoURL'] =
            'https://firebasestorage.googleapis.com/v0/b/fluttergram-f438d.appspot.com/o/userProfileImages%2Fdefault.png?alt=media&token=d2252bec-459d-4d80-912b-bd0eeca41690';
      }

      await FirebaseAuth.instance.currentUser?.updatePhotoURL(
        userInfo['photoURL'],
      );
      await FirebaseAuth.instance.currentUser?.updateDisplayName(
        userInfo['displayName'],
      );
      await FirebaseAuth.instance.currentUser?.updateEmail(
        userInfo['email'],
      );

      final getMember = await firestore
          .collection('members')
          .where('uid', isEqualTo: userInfo['uid'])
          .get();

      await FirebaseFirestore.instance
          .collection('members')
          .doc(getMember.docs[0].id)
          .update({
        'email': userInfo['email'],
        'displayName': userInfo['displayName'],
        'photoURL': userInfo['photoURL'],
        'follower': 0,
      });

      final newUser = FirebaseAuth.instance.currentUser;
      await newUser?.reload();

      Provider.of<UserProvider>(context, listen: false).setUser(UserModel(
        uid: newUser?.uid,
        displayName: newUser?.displayName,
        email: newUser?.email,
        photoURL: newUser?.photoURL,
      ));

      await showNotification(5, '회원정보 변경 완료', '회원정보가 정상적으로 변경됐습니다.');
      Navigator.of(context).pushNamed('/');
    } catch (e) {
      print('Error during user info update: $e');

      if (e is FirebaseAuthException) {
        if (e.code == 'requires-recent-login') {
          await showNotification(5, '오류', '인증 정보가 만료되었습니다. 다시 로그인해주세요.');

          // 로그아웃 처리
          await FirebaseAuth.instance.signOut();

          // 로그인 페이지로 이동
          Navigator.of(context).pushNamed('/login');
        } else {
          await showNotification(5, '오류', '회원정보 변경 중 오류가 발생했습니다. 다시 시도해주세요.');
        }
      } else {
        await showNotification(5, '오류', '회원정보 변경 중 오류가 발생했습니다. 다시 시도해주세요.');
      }
    }

    setState(() => isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    getMyInfomationFromProvider();
    Future.delayed(Duration.zero, setTitleText);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _displayNameFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TextStyle contentStyle = const TextStyle(fontSize: 20, color: Colors.black);
    TextStyle titleStyle = const TextStyle(fontSize: 30, color: Colors.black);

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    alignment: Alignment.topCenter,
                    margin: const EdgeInsets.only(top: 20),
                    child: Text('${userProvider?.displayName ?? ''}님의 정보',
                        style: titleStyle),
                  ),
                  Container(
                      alignment: Alignment.topCenter,
                      margin: const EdgeInsets.all(20),
                      child: selectedImage != null
                          ? Image.file(
                              selectedImage!,
                              fit: BoxFit.cover,
                              height: 250,
                            )
                          : userProvider?.photoURL != null
                              ? Image.network(
                                  userProvider?.photoURL ?? '',
                                  fit: BoxFit.cover,
                                  height: 250,
                                )
                              : const Text('No Image',
                                  style: TextStyle(height: 5))),
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      child: ElevatedButton(
                        onPressed: () => selectImage(),
                        child: const Text('이미지 선택'),
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      Container(
                        width: 70,
                        margin: const EdgeInsets.only(left: 20, top: 20),
                        child: Text('이름:', style: contentStyle),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(top: 20),
                          child: FractionallySizedBox(
                            widthFactor: 0.8,
                            child: TextField(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              onTap: () {
                                _displayNameFocus.requestFocus();
                                setState(
                                    () => _displayNameController.text = '');
                              },
                              focusNode: _displayNameFocus,
                              controller: _displayNameController,
                              onChanged: (text) {
                                setState(
                                  () => userInfo['displayName'] = text,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 70,
                        margin: const EdgeInsets.only(left: 20, top: 20),
                        child: Text('이메일:', style: contentStyle),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(top: 20),
                          child: FractionallySizedBox(
                            widthFactor: 0.8,
                            child: TextField(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              onTap: () {
                                _emailFocus.requestFocus();
                                setState(() => _emailController.text = '');
                              },
                              focusNode: _emailFocus,
                              controller: _emailController,
                              onChanged: (text) {
                                setState(() => userInfo['email'] = text);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 70,
                        margin: const EdgeInsets.only(left: 20, top: 20),
                        child: Text('UID:', style: contentStyle),
                      ),
                      Expanded(
                        child: Container(
                          alignment: Alignment.topLeft,
                          margin: const EdgeInsets.only(left: 20, top: 20),
                          child: Text(userProvider?.uid ?? '',
                              style: contentStyle, maxLines: null),
                        ),
                      ),
                    ],
                  ),
                  // 회원정보 수정 버튼
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 5),
                            child: ElevatedButton(
                              onPressed: () => updateMemberInfo(context),
                              child: const Text('정보변경'),
                            ),
                          ),
                          //
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
