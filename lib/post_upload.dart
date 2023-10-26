import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'notification.dart';
import 'provider.dart';

final FirebaseStorage _storage = FirebaseStorage.instance;
final FirebaseAuth _auth = FirebaseAuth.instance;

class PostUpload extends StatefulWidget {
  final dynamic propsData;
  final dynamic editMode;
  const PostUpload({Key? key, this.propsData, this.editMode}) : super(key: key);

  @override
  State<PostUpload> createState() => _PostUploadState();
}

class _PostUploadState extends State<PostUpload> {
  String writerId = '';
  String writer = '';
  String contentImage = '';
  int like = 0;
  bool isUploading = false;
  File? userImage;
  dynamic pickedFile;
  bool isEdit = false;
  bool changeImage = false;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  setInitData() {
    if (widget.propsData != null) {
      writerId = widget.propsData['writerId'] ?? '';
      writer = widget.propsData['writer'] ?? '';
      _titleController.text = widget.propsData['title'] ?? '';
      _contentController.text = widget.propsData['content'] ?? '';
      contentImage = widget.propsData['contentImage'] ?? '';
      like = widget.propsData['like'] ?? 0;
    }
    if (widget.editMode == true) {
      isEdit = true;
    }
  }

  Future<void> selectImage() async {
    final ImagePicker picker = ImagePicker();
    pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      userImage = File(pickedFile?.path ?? '');
      changeImage = true;
    });
  }

  Future<void> uploadPost(context, postDivi) async {
    UserModel? user = Provider.of<UserProvider>(context, listen: false).user;

    if (_contentController.text.isEmpty || _titleController.text.isEmpty) {
      return await showInvalidInputNotification(context, "제목과 내용을 입력해주세요.");
    }

    // 게시물 업로드 중임을 표시
    setState(() => isUploading = true);

    if (isEdit == true && changeImage == true) {
      // 이미지 삭제
      final Reference imageRef =
          FirebaseStorage.instance.refFromURL(widget.propsData['contentImage']);
      await imageRef.delete();
    }

    if (changeImage == true) {
      // 새운 이미지 업로드
      final Reference storageRef = _storage.ref().child(
          'postImages/${DateTime.now()}.${userImage?.path.split('.').last}');
      final UploadTask uploadTask = storageRef.putFile(File(pickedFile.path));

      await uploadTask.whenComplete(() async {
        contentImage = await storageRef.getDownloadURL();
      });
    }

    // 파이어스토어에 게시물 업로드
    try {
      if (postDivi == 'Upload') {
        await FirebaseFirestore.instance.collection('mainPosts').add({
          'contentImage': contentImage,
          'like': like,
          'writerId': user?.uid,
          'writer': user?.displayName,
          'writerPhoto': user?.photoURL,
          'title': _titleController.text,
          'content': _contentController.text,
          'timestamp': DateTime.now(),
        });
      } else if (postDivi == 'Update') {
        await FirebaseFirestore.instance
            .collection('mainPosts')
            .doc(widget.propsData?.id)
            .update({
          'contentImage': contentImage,
          'title': _titleController.text,
          'content': _contentController.text,
        });
      }

      await showNotification(0, '게시물 업로드 완료', '게시물이 성공적으로 업로드되었습니다.');
    } catch (e) {
      await showNotification(0, '게시물 업로드 실패', '게시물 업로드에 실패하였습니다. 다시 시도해 주세요.');
      print(e);
    }

    // 로딩바 최소시간 설정
    isEdit = false;
    changeImage = false;
    await Future.delayed(const Duration(milliseconds: 500));

    Navigator.of(context).pushNamed('/');
  }

  // Map<String, dynamic> userPost = {
  //   'memberId': '641422cdafc7faa9f6a674d0',
  //   'writer': '박정호',
  //   'title': '',
  //   'content': '',
  // };

  // bool isUploading = false;
  // File? userImage;
  // dynamic pickedFile;

  // Future<void> selectImage() async {
  //   final ImagePicker picker = ImagePicker();
  //   pickedFile = await picker.pickImage(source: ImageSource.gallery);
  //   setState(() => userImage = File(pickedFile?.path ?? ''));
  // }

  // uploadPost(context) async {
  //   final url = Platform.isAndroid
  //       ? 'http://172.20.59.28:8080'
  //       : 'http://localhost:8080';
  //   final request = http.MultipartRequest(
  //     'post',
  //     Uri.parse('$url/api/post/uploadPost'),
  //   );

  //   request.fields['memberId'] = userPost['memberId'];
  //   request.fields['writer'] = userPost['writer'];
  //   request.fields['title'] = userPost['title'];
  //   request.fields['like'] = userPost['like'].toString();
  //   request.fields['content'] = userPost['content'];

  //   if (userImage != null) {
  //     request.files.add(
  //       await http.MultipartFile.fromPath(
  //         'image',
  //         userImage?.path ?? '',
  //       ),
  //     );
  //   }

  //   final response = await request.send();

  //   if (response.statusCode == 200) {
  //     await showNotification(0, '게시물 업로드 완료', '게시물이 성공적으로 업로드되었습니다.');
  //   } else {
  //     await showNotification(0, '게시물 업로드 실패', '게시물 업로드에 실패하였습니다. 다시 시도해 주세요.');
  //   }

  //   // 업로드 후 실행될 로직
  //   await Future.delayed(const Duration(milliseconds: 500));
  //   Navigator.pop(context, true);
  //   Navigator.of(context).pushNamed('/');
  // }

  // 사용자 로그인 체크
  void chackLogin() {
    if (_auth.currentUser == null) {
      showNotification(0, '로그인 필요', '로그인이 필요한 서비스입니다.');
      Navigator.of(context).pushNamed('/login');
    }
  }

  @override
  void initState() {
    super.initState();
    setInitData();
    chackLogin();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postDivi = widget.propsData != null ? 'Update' : 'Upload';
    return Scaffold(
      appBar: AppBar(
        title: const Text("POST"),
        automaticallyImplyLeading: false,
      ),
      body: isUploading
          ? const Center(child: CircularProgressIndicator())
          : SizedBox(
              child: ListView(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 20),
                      child: userImage != null && userImage!.path != ''
                          ? Image.file(
                              userImage!,
                              fit: BoxFit.cover,
                              height: 250,
                            )
                          : contentImage.isNotEmpty
                              ? Image.network(contentImage,
                                  fit: BoxFit.cover, height: 250)
                              : const Text('No Image',
                                  style: TextStyle(height: 5)),
                    ),
                  ),
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      child: ElevatedButton(
                        onPressed: () => selectImage(),
                        child: const Text('select image'),
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
                            labelText: 'Title',
                          ),
                          controller: _titleController,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 20),
                      height: 10 * 24.0,
                      child: FractionallySizedBox(
                        widthFactor: 0.9,
                        child: TextField(
                          maxLines: 10,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Content',
                          ),
                          // content의 데이터가 있다면 기존 데이터를 보여줌
                          controller: _contentController,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 5),
                          child: ElevatedButton(
                            onPressed: () => uploadPost(context, postDivi),
                            child: Text(postDivi),
                          ),
                        ),
                        //
                        Container(
                          margin: const EdgeInsets.only(left: 5),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
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
