import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'provider.dart';
import 'notification.dart';

final FirebaseStorage _storage = FirebaseStorage.instance;
final FirebaseAuth auth = FirebaseAuth.instance;
final FirebaseFirestore store = FirebaseFirestore.instance;

class Regester extends StatefulWidget {
  const Regester({Key? key}) : super(key: key);

  @override
  State<Regester> createState() => _RegesterState();
}

class _RegesterState extends State<Regester> {
  String email = '';
  String password = '';
  String passwordRe = '';
  String userName = '';
  String? image;

  bool isUploading = false;
  bool _obscureText = true;
  bool _obscureTextRe = true;
  File? userImage;
  XFile? pickedFile;

  // 앱 바의 제목 변경
  void setTitleText() {
    Provider.of<TitleProvider>(context, listen: false).setTitle('REGESTER');
  }

  Future<void> selectImage() async {
    final ImagePicker picker = ImagePicker();
    pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() => userImage = File(pickedFile?.path ?? ''));
  }

  Future<dynamic> submitRegester(context) async {
    if (email.isEmpty || password.isEmpty || passwordRe.isEmpty) {
      return await showInvalidInputNotification(context, "회원정보를 입력해주세요.");
    }
    if (password != passwordRe) {
      return await showInvalidInputNotification(context, "비밀번호가 다릅니다.");
    }

    // 게시물 업로드 중임을 표시
    setState(() => isUploading = true);

    if (userImage != null) {
      final Reference storageRef = _storage.ref().child(
          'userProfileImages/${DateTime.now()}.${userImage?.path.split('.').last}');
      final UploadTask uploadTask = storageRef.putFile(File(pickedFile!.path));

      await uploadTask.whenComplete(() async {
        image = await storageRef.getDownloadURL();
      });
    } else {
      image =
          'https://firebasestorage.googleapis.com/v0/b/fluttergram-f438d.appspot.com/o/userProfileImages%2Fdefault.png?alt=media&token=d2252bec-459d-4d80-912b-bd0eeca41690&_gl=1*u031bs*_ga*MjEzMzgyMzY5LjE2ODk1NTg3Njk.*_ga_CW55HF8NVT*MTY5NjkxMTU4OC4xMjAuMS4xNjk2OTI1MDkxLjMyLjAuMA';
    }

    // 회원가입
    try {
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user?.updateDisplayName(userName);
      await userCredential.user?.updatePhotoURL(image);
      await store.collection('members').add({
        'email': userCredential.user?.email,
        'displayName': userName,
        'photoURL': image,
        'uid': userCredential.user?.uid,
        'follower': 0,
      });

      // await showNotification(0, '회원가입 완료', '회원가입이 완료됐습니다.');
      setState(() => isUploading = false);

      Navigator.pop(context, true);
      Navigator.of(context).pushNamed('/');
    } on FirebaseAuthException catch (e) {
      setState(() => isUploading = false);

      if (e.code == 'weak-password') {
        return showInvalidInputNotification(context, '조금 더 강력한 비밀번호를 입력해주세요.');
      } else if (e.code == 'email-already-in-use') {
        return showInvalidInputNotification(context, '이미 사용중인 이메일입니다.');
      }
    } catch (e) {
      setState(() => isUploading = false);
      print(e);
    }

    await auth.signOut();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, setTitleText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isUploading
          ? const Center(child: CircularProgressIndicator())
          : SizedBox(
              child: ListView(
                children: [
                  Center(
                    child: Container(
                        margin: const EdgeInsets.only(top: 50),
                        child: const Text("회원가입",
                            style:
                                TextStyle(fontSize: 30, color: Colors.black))),
                  ),
                  Center(
                    child: Container(
                      child: userImage != null && userImage!.path != ''
                          ? Image.file(
                              userImage!,
                              fit: BoxFit.cover,
                              height: 250,
                            )
                          : const Text('No Image', style: TextStyle(height: 5)),
                    ),
                  ),
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      child: ElevatedButton(
                        onPressed: () => selectImage(),
                        child: const Text('이미지 선택'),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      height: 50,
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
                      height: 50,
                      margin: const EdgeInsets.only(top: 20),
                      child: FractionallySizedBox(
                        widthFactor: 0.9,
                        child: TextField(
                          // decoration: const InputDecoration(
                          //   border: OutlineInputBorder(),
                          //   labelText: '비밀번호',
                          // ),
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
                  Center(
                    child: Container(
                      height: 50,
                      margin: const EdgeInsets.only(top: 20),
                      child: FractionallySizedBox(
                        widthFactor: 0.9,
                        child: TextField(
                          // decoration: const InputDecoration(
                          //   border: OutlineInputBorder(),
                          //   labelText: '비밀번호 확인',
                          // ),
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: '비밀번호 확인',
                            suffixIcon: IconButton(
                              icon: Icon(_obscureTextRe
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () {
                                setState(() {
                                  _obscureTextRe = !_obscureTextRe;
                                });
                              },
                            ),
                          ),
                          obscureText: _obscureTextRe,
                          onChanged: (text) {
                            setState(
                              () => passwordRe = text,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      height: 50,
                      margin: const EdgeInsets.only(top: 20),
                      child: FractionallySizedBox(
                        widthFactor: 0.9,
                        child: TextField(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: '이름',
                          ),
                          onChanged: (text) {
                            setState(
                              () => userName = text,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 5),
                            child: ElevatedButton(
                              onPressed: () => submitRegester(context),
                              child: const Text('회원가입'),
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
                  ),
                ],
              ),
            ),
    );
  }
}
