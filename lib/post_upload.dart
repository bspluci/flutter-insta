import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:gif_resize/gif_resize.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image/image.dart' as img;

import 'notification.dart';
import 'provider.dart';
import 'image_edit.dart';

final FirebaseStorage _storage = FirebaseStorage.instance;
final FirebaseFirestore _store = FirebaseFirestore.instance;
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
  File? showImage;
  XFile? pickedFile;
  dynamic pickedImage;
  bool isEdit = false;
  bool isChange = false;
  dynamic extend;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  setInitData() {
    if (widget.propsData != null) {
      setState(() {
        writerId = widget.propsData['writerId'] ?? '';
        writer = widget.propsData['writer'] ?? '';
        _titleController.text = widget.propsData['title'] ?? '';
        _contentController.text = widget.propsData['content'] ?? '';
        contentImage = widget.propsData['contentImage'] ?? '';
        like = widget.propsData['like'] ?? 0;
      });
    }
    if (widget.editMode == true) {
      setState(() {
        isEdit = true;
      });
    }
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
      isChange = true;
    });
  }

  Future<void> uploadPost(context, postDivi) async {
    UserModel? user = Provider.of<UserProvider>(context, listen: false).user;

    if (_contentController.text.isEmpty || _titleController.text.isEmpty) {
      return await showSnackBar(context, "제목과 내용을 입력해주세요.");
    }

    // 게시물 업로드 중임을 표시
    setState(() => isUploading = true);

    try {
      if (isEdit == true && isChange == true) {
        // 이미지 삭제
        final Reference imageRef =
            _storage.refFromURL(widget.propsData['contentImage']);
        Future(() async {
          try {
            await imageRef.delete();
          } catch (e) {
            if (e is FirebaseException &&
                e.code == 'firebase_storage/object-not-found') {
              await showSnackBar(context, '삭제할 이미지가 없습니다.');
            }
          }
        });
      }

      if (isChange && extend != 'gif') {
        // 새운 이미지 업로드
        final Reference storageRef =
            _storage.ref().child('postImages/${DateTime.now()}.$extend');
        final compressedImage = img.encodeJpg(pickedImage, quality: 80);
        final UploadTask uploadTask = storageRef.putData(compressedImage);

        await uploadTask.whenComplete(() async {
          contentImage = await storageRef.getDownloadURL();
        });
      } else if (isChange && extend == 'gif') {
        // GIF 파일의 용량 체크
        const int maxSize = 10 * 1024 * 1024; // 5MB로 제한
        if (showImage!.lengthSync() > maxSize) {
          // 용량 초과 시 처리
          await showSnackBar(context, 'GIF 파일 용량이 5MB를 초과했습니다.');

          setState(() {
            isEdit = false;
            isChange = false;
            isUploading = false;
            showImage = null;
          });
          return;
        }

        Uint8List? dataImage;
        final gifResizePlugin = GifResize();
        final fileSize = img.decodeImage(await pickedFile!.readAsBytes());
        final gifWidth = fileSize!.width;
        final gifheight = fileSize.height;

        File imageFile = File(pickedFile!.path);
        List<int> imageBytes = imageFile.readAsBytesSync();
        ByteData byteData =
            ByteData.sublistView(Uint8List.fromList(imageBytes));
        Uint8List bytes = byteData.buffer.asUint8List();

        try {
          await gifResizePlugin.init(h: 200, w: 200);

          if (gifWidth > gifheight) {
            await gifResizePlugin.setWidth(w: 200);
            await gifResizePlugin.setHeight(
                h: (200 * gifheight / gifWidth).round());
          } else {
            await gifResizePlugin.setHeight(h: 200);
            await gifResizePlugin.setWidth(
                w: (200 * gifWidth / gifheight).round());
          }
        } catch (e) {
          await showSnackBar(context, '에러: $e');
        }

        Uint8List resized = await gifResizePlugin.process(bytes);
        setState(() {
          dataImage = resized;
        });

        final Reference storageRef = _storage.ref().child(
            'postImages/${DateTime.now()}.${showImage?.path.split('.').last}');
        final UploadTask uploadTask = storageRef.putData(dataImage!);
        await uploadTask.whenComplete(() async {
          contentImage = await storageRef.getDownloadURL();
        });
      }

      // 파이어스토어에 게시물 업로드
      if (postDivi == 'Upload') {
        await _store.collection('mainPosts').add({
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
        await _store.collection('mainPosts').doc(widget.propsData?.id).update({
          'contentImage': contentImage,
          'title': _titleController.text,
          'content': _contentController.text,
        });
      }

      await showSnackBar(context, '게시물이 성공적으로 업로드되었습니다.');
    } catch (e) {
      await showSnackBar(context, '게시물 업로드에 실패하였습니다. 다시 시도해 주세요.');

      await showSnackBar(context, '에러: $e');
    }

    setState(() {
      isEdit = false;
      isChange = false;
    });

    Navigator.of(context).pushReplacementNamed('/');
  }

  // 사용자 로그인 체크
  void chackLogin(context) async {
    if (_auth.currentUser == null) {
      await showSnackBar(context, '로그인이 필요한 서비스입니다.');
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  void initState() {
    super.initState();
    setInitData();
    chackLogin(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext buildContext) {
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
                      child: showImage != null && showImage!.path != ''
                          ? Image.file(
                              showImage!,
                              fit: BoxFit.cover,
                              height: 250,
                            )
                          : contentImage.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: contentImage,
                                  height: 250,
                                  fit: BoxFit.cover,
                                  progressIndicatorBuilder:
                                      (context, url, downloadProgress) {
                                    return SizedBox(
                                      child: Center(
                                        child: CircularProgressIndicator(
                                            value: downloadProgress.progress),
                                      ),
                                    );
                                  },
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.error),
                                )
                              : const Text('No Image',
                                  style: TextStyle(height: 5)),
                    ),
                  ),
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      child: ElevatedButton(
                        onPressed: () => selectImage(context),
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
                            onPressed: () => uploadPost(buildContext, postDivi),
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
