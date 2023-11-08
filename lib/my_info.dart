import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

import 'notification.dart';
import 'provider.dart';
import 'image_edit.dart';

final FirebaseFirestore _store = FirebaseFirestore.instance;
final FirebaseStorage _storage = FirebaseStorage.instance;
final FirebaseAuth _auth = FirebaseAuth.instance;

class MyInfo extends StatefulWidget {
  const MyInfo({Key? key}) : super(key: key);

  @override
  State<MyInfo> createState() => _MyInfoState();
}

class _MyInfoState extends State<MyInfo> {
  bool isLoading = false;
  UserModel? userProvider;
  XFile? pickedFile;
  File? showImage;
  dynamic pickedImage;
  bool isChange = false;
  String? extend;
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
    userInfo['photoURL'] = userProvider?.photoURL;
    _displayNameController.text = userProvider?.displayName ?? '';
    _emailController.text = userProvider?.email ?? '';
  }

  selectImage(context) async {
    final ImagePicker picker = ImagePicker();
    pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    SelectImage selectImage = SelectImage();
    await selectImage.selectImage(context, pickedFile);
    final selectImg = selectImage.image;

    setState(() {
      extend = selectImg?.extend;
      pickedImage = selectImg?.pickedImage;
      showImage = selectImg?.showImage;
      userInfo['photoURL'] = File(pickedFile!.path);
      isChange = true;
    });
  }

  void updateMemberInfo(context) async {
    setState(() => isLoading = true);

    final currentUser = _auth.currentUser;

    try {
      // 기존 이미지 파일 삭제
      if (isChange) {
        try {
          final existingImageRef = _storage.refFromURL(userProvider!.photoURL!);
          await existingImageRef.delete();
        } catch (e) {
          showSnackBar(context, '에러: $e');
        }

        if (pickedFile != null) {
          final Reference storageReference = _storage
              .ref()
              .child('userProfileImages/${DateTime.now()}.$extend');
          final compressedImage = img.encodeJpg(pickedImage, quality: 80);
          final UploadTask uploadTask =
              storageReference.putData(compressedImage);

          await uploadTask.whenComplete(() async {
            final String downloadUrl = await storageReference.getDownloadURL();
            userInfo['photoURL'] = downloadUrl;
          });
        }
      }

      userProvider?.photoURL != userInfo['photoURL']
          ? await currentUser?.updatePhotoURL(
              userInfo['photoURL'],
            )
          : null;
      userProvider?.displayName != userInfo['displayName']
          ? await currentUser?.updateDisplayName(
              userInfo['displayName'],
            )
          : null;
      userProvider?.email != userInfo['email']
          ? await currentUser?.updateEmail(
              userInfo['email'],
            )
          : null;

      final getMember = await firestore
          .collection('members')
          .where('uid', isEqualTo: userInfo['uid'])
          .get();

      await _store.collection('members').doc(getMember.docs[0].id).update({
        'email': userInfo['email'],
        'displayName': userInfo['displayName'],
        'photoURL': userInfo['photoURL'],
        'follower': 0,
      });

      await currentUser?.reload();

      Provider.of<UserProvider>(context, listen: false).setUser(UserModel(
        uid: currentUser?.uid,
        displayName: currentUser?.displayName,
        email: currentUser?.email,
        photoURL: currentUser?.photoURL,
      ));

      await showSnackBar(context, '회원정보가 정상적으로 변경됐습니다.');
      Navigator.of(context).pushNamed('/');
    } catch (e) {
      showSnackBar(context, '에러: $e');

      if (e is FirebaseAuthException) {
        if (e.code == 'requires-recent-login') {
          await showSnackBar(context, '인증 정보가 만료되었습니다. 다시 로그인해주세요.');

          // 로그아웃 처리
          await _auth.signOut();

          // 로그인 페이지로 이동
          Navigator.of(context).pushNamed('/login');
        } else {
          await showSnackBar(context, '회원정보 변경 중 오류가 발생했습니다. 다시 시도해주세요.');
        }
      } else {
        await showSnackBar(context, '회원정보 변경 중 오류가 발생했습니다. 다시 시도해주세요.');
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
                    child: Text('${userProvider?.displayName ?? '사용자'}님의 정보',
                        style: titleStyle),
                  ),
                  Container(
                    alignment: Alignment.topCenter,
                    margin: const EdgeInsets.all(20),
                    child: showImage != null && showImage!.path != ''
                        ? Image.file(
                            showImage!,
                            fit: BoxFit.cover,
                            height: 250,
                          )
                        : userInfo['photoURL'].isNotEmpty
                            ? Image.network(userInfo['photoURL'],
                                fit: BoxFit.cover, height: 250)
                            : const Text('No Image',
                                style: TextStyle(height: 5)),
                  ),
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      child: ElevatedButton(
                        onPressed: () => selectImage(context),
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
                          height: 50,
                          margin: const EdgeInsets.only(top: 20),
                          child: FractionallySizedBox(
                            widthFactor: 0.8,
                            child: TextField(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
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
                          height: 50,
                          margin: const EdgeInsets.only(top: 20),
                          child: FractionallySizedBox(
                            widthFactor: 0.8,
                            child: TextField(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
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
