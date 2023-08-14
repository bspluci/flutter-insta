import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'notification.dart';

final FirebaseStorage _storage = FirebaseStorage.instance;

class PostUpload extends StatefulWidget {
  const PostUpload({Key? key}) : super(key: key);

  @override
  State<PostUpload> createState() => _PostUploadState();
}

class _PostUploadState extends State<PostUpload> {
  String writerId = '641422cdafc7faa9f6a674d0';
  String writer = '박정호';
  String title = '';
  String content = '';
  String image = '';
  int like = 0;

  bool isUploading = false;
  File? userImage;
  dynamic pickedFile;

  Future<void> selectImage() async {
    final ImagePicker picker = ImagePicker();
    pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() => userImage = File(pickedFile?.path ?? ''));
  }

  Future<void> uploadPost(context) async {
    if (content.isEmpty || title.isEmpty) {
      // Show a notification for invalid price input
      return await showInvalidInputNotification(context, "제목과 내용을 입력해주세요.");
    }

    // 게시물 업로드 중임을 표시
    setState(() => isUploading = true);

    final Reference storageRef = _storage.ref().child(
        'postImages/${DateTime.now()}.${userImage?.path.split('.').last}');
    final UploadTask uploadTask = storageRef.putFile(File(pickedFile.path));

    await uploadTask.whenComplete(() async {
      image = await storageRef.getDownloadURL();
    });

    // 파이어스토어에 게시물 업로드
    try {
      await FirebaseFirestore.instance.collection('mainPosts').add({
        'image': image,
        'like': like,
        'writerId': writerId,
        'writer': writer,
        'title': title,
        'content': content,
        'timestamp': DateTime.now(),
      });

      await showNotification(0, '게시물 업로드 완료', '게시물이 성공적으로 업로드되었습니다.');
    } catch (e) {
      await showNotification(0, '게시물 업로드 실패', '게시물 업로드에 실패하였습니다. 다시 시도해 주세요.');
      print(e);
    }

    await Future.delayed(const Duration(milliseconds: 500));

    Navigator.pop(context, true);
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

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Instagram"),
        automaticallyImplyLeading: false,
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.done),
        //     onPressed: () {
        //       Navigator.push(context,
        //           MaterialPageRoute(builder: (context) => uploadPost())
        //       );
        //     },
        //   ),
        // ],
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
                          : const Text('No Image', style: TextStyle(height: 5)),
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
                      margin: const EdgeInsets.only(top: 20),
                      child: FractionallySizedBox(
                        widthFactor: 0.9,
                        child: TextField(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Title',
                          ),
                          onChanged: (text) {
                            setState(
                              () => title = text,
                            );
                          },
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
                          onChanged: (text) {
                            setState(
                              () => content = text,
                            );
                          },
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
                            onPressed: () => uploadPost(context),
                            child: const Text('Publish'),
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
