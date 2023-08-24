import 'dart:io';
import 'dart:io' show Platform;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'text/vision_detector_views/text_detector_view.dart';
import 'style.dart' as style;
import 'postUpload.dart' as postpublish;
import 'userProfile.dart' as userprofile;
import 'provider.dart';
import 'notification.dart';
import 'shop.dart';

final firestore = FirebaseFirestore.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (context) => DataProvider()),
    ],
    child: MaterialApp(
      theme: style.theme,
      // home: const MyApp()
      initialRoute: '/',
      routes: {
        '/': (context) => const MyApp(),
        '/text': (context) => TextRecognizerView(),
        '/shop': (context) => const Shop(),
        '/post/publish': (context) => const postpublish.PostUpload(),
      },
    ),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int page = 0;
  int tabIndex = 0;
  List<dynamic> postData = [];
  bool parentLoading = false;

  // SharedPreferences에 postList를 저장하는 함수
  savePostListFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
        'postData', postData.map((post) => json.encode(post)).toList());
    prefs.setInt('page', page);
  }

  // sharedPreferences에서 postList를 불러오는 함수
  getPostListFromSharedPreferences() async {
    getPostList();
    return;

    // SharedPreferences - 캐시에 데이터를 저장해 빠르게 불러올 수 있음
    // final prefs = await SharedPreferences.getInstance();
    // // prefs.remove('postData');
    // // prefs.remove('page');
    // final savedPostData = prefs.getStringList('postData');
    // final savedPage = prefs.getInt('page');

    // // 저장된 데이터가 있으면 setState로 상태를 변경
    // if (savedPostData != null && savedPage != null) {
    //   setState(() {
    //     postData = savedPostData.map((post) => json.decode(post)).toList();
    //     page = savedPage;
    //   });
    // } else {
    //   getPostList();
    // }
  }

  getPostList() async {
    setState(() {
      parentLoading = true;
    });

    // int itemLimit = 5;
    // page = page + 1;
    // final origin = Platform.isAndroid
    //     ? 'http://172.20.59.28:8080'
    //     : 'http://localhost:8080';
    // final url = '$origin/api/post/getAllPostList?limit=$itemLimit&page=$page';
    // final response = await http.get(
    //   Uri.parse(url),
    // );

    // if (response.statusCode == 200) {
    //   final jsonData = json.decode(response.body);
    //   await Future.delayed(const Duration(seconds: 1));

    //   setState(() {
    //     postData = [...postData, ...jsonData['data']];
    //   });
    // } else {
    //   final jsonData = response.statusCode != 404
    //       ? json.decode(response.body)
    //       : {'message': 'not found'};

    //   await showInvalidInputNotification(context,
    //       '통신 실패: ${response.statusCode} ERROR, ${jsonData['message']}');
    // }

    const int _perPage = 2;
    QuerySnapshot result;

    await Future.delayed(Duration(seconds: 1));

    try {
      if (postData.isEmpty) {
        result = await FirebaseFirestore.instance
            .collection('mainPosts')
            .orderBy('timestamp', descending: true)
            .limit(_perPage)
            .get();
      } else {
        result = await FirebaseFirestore.instance
            .collection('mainPosts')
            .orderBy('timestamp', descending: true)
            .startAfterDocument(postData.last)
            .limit(_perPage)
            .get();
      }

      setState(() {
        postData.addAll(result.docs);
      });
    } catch (e) {
      print(e);
    }

    // savePostListFromSharedPreferences();
    setState(() => parentLoading = false);
  }

  @override
  void initState() {
    super.initState();
    initNotification(context);
    getPostListFromSharedPreferences();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Instagram"),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_snippet_rounded),
            onPressed: () {
              Navigator.pushNamed(context, '/text');
            },
          ),
          IconButton(
            icon: const Icon(Icons.card_giftcard_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/shop');
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () {
              // Navigator.push(context,
              //   MaterialPageRoute(builder: (context) => const postPublish())
              // );
              Navigator.pushNamed(context, '/post/publish');
            },
          ),
        ],
      ),
      // PageView 를 사용하면 슬라이드 형태로 페이지를 나눌 수 있음.
      body: [
        PostList(
            postData: postData,
            getPostList: getPostList,
            parentLoading: parentLoading),
        const SizedBox(child: Text("샵 페이지")),
      ][tabIndex],
      bottomNavigationBar: BottomNavigationBar(
        showSelectedLabels: false,
        showUnselectedLabels: false,
        unselectedItemColor: Colors.black,
        selectedItemColor: Colors.black,
        onTap: (value) => setState(() => tabIndex = value),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(
                Icons.home_outlined,
              ),
              label: 'home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined), label: 'bag'),
        ],
      ),
    );
  }
}

class PostList extends StatefulWidget {
  final List<dynamic> postData;
  final dynamic getPostList;
  final bool parentLoading;

  const PostList({
    Key? key,
    required this.postData,
    required this.getPostList,
    required this.parentLoading,
  }) : super(key: key);

  @override
  State<PostList> createState() => _PostListState();
}

class _PostListState extends State<PostList> {
  ScrollController scroll = ScrollController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (scroll.position.pixels == scroll.position.maxScrollExtent &&
          !isLoading) {
        setState(() {
          isLoading = true;
        });
        widget.getPostList().then((value) {
          setState(() {
            isLoading = false;
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.postData.isNotEmpty) {
      return ListView.separated(
        controller: scroll,
        itemCount: widget.postData.length + (isLoading ? 1 : 0),
        itemBuilder: (context, idx) {
          if (idx < widget.postData.length) {
            return Container(
              padding: const EdgeInsets.only(top: 15, bottom: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.only(bottom: 10, left: 10),
                    child: Title(
                        color: const Color(0xff000000),
                        child: Text(
                          widget.postData[idx]['title'],
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 25,
                              fontWeight: FontWeight.bold),
                        )),
                  ),
                  widget.postData[idx]['image'] != null &&
                          widget.postData[idx]['image'] != ''
                      ? Image.network(widget.postData[idx]['image'],
                          height: 300, fit: BoxFit.cover)
                      : const SizedBox(height: 300),
                  Container(
                    padding:
                        const EdgeInsets.only(top: 20, left: 20, right: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('좋아요 ${widget.postData[idx]["like"]}',
                            style: const TextStyle(color: Colors.black)),
                        GestureDetector(
                          child: Text('글쓴이 ${widget.postData[idx]["writer"]}',
                              style: const TextStyle(color: Colors.black)),
                          onTap: () {
                            Navigator.push(
                              context,
                              // PageRouteBuilder(
                              //   pageBuilder: (c, a1, a2) =>
                              //       const userprofile.UserProfile(),
                              //   transitionsBuilder: (c, a1, a2, child) =>
                              //       // FadeTransition(opacity: a1, child: child),
                              //       SlideTransition(
                              //           position: Tween<Offset>(
                              //             begin: const Offset(0.1, 0.0),
                              //             end: Offset.zero,
                              //           ).animate(a1),
                              //           child: child),
                              //   transitionDuration:
                              //       const Duration(milliseconds: 200),
                              // ));
                              CupertinoPageRoute(
                                builder: (c) => userprofile.UserProfile(
                                    userId: widget.postData[idx]["writerId"]),
                              ),
                            );
                          },
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 15),
                          child: Text('${widget.postData[idx]["content"]}',
                              style: const TextStyle(color: Colors.black)),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            return const Center(
              child: LoadingCircle(), // 로딩바
            );
          }
        },
        separatorBuilder: (context, index) => const Divider(
          thickness: 1.5,
          color: Colors.black12,
        ), // 구분선
      );
    } else {
      return widget.parentLoading
          ? const Center(
              child: LoadingCircle(),
            )
          : const Center(
              child: Text("게시물이 없습니다."),
            );
    }
  }
}

// 로딩바 위젯
class LoadingCircle extends StatelessWidget {
  const LoadingCircle({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 20, bottom: 20),
      child: CircularProgressIndicator.adaptive(
        value: null, // 진행 상태 (0.0 ~ 1.0)를 나타내는 값. null인 경우에는 애니메이션 효과를 나타냄
        strokeWidth: 5.0, // 인디케이터의 두께
        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue), // 인디케이터의 색상
      ),
    );
  }
}
