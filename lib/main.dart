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
import 'package:firebase_auth/firebase_auth.dart';

import 'text/vision_detector_views/text_detector_view.dart';
import 'style.dart' as style;
import 'postUpload.dart' as postpublish;
import 'userProfile.dart' as userprofile;
import 'provider.dart';
import 'notification.dart';
import 'shop.dart' as shop;
import 'regester.dart' as regester;
import 'login.dart';
import 'myInfo.dart' as myinfo;

final firestore = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (context) => DataProvider()),
      ChangeNotifierProvider(create: (context) => UserProvider()),
      ChangeNotifierProvider(create: (context) => AppBarTitle()),
    ],
    child: MaterialApp(
      theme: style.theme,
      // home: const MyApp()
      initialRoute: '/',
      routes: {
        '/': (context) => const MyApp(),
        '/text': (context) => TextRecognizerView(),
        '/login': (context) => const Login(),
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
    final user = Provider.of<UserProvider>(context).user;
    final logout = Provider.of<UserProvider>(context).logout;
    final title = Provider.of<AppBarTitle>(context);

    return Scaffold(
      appBar: AppBar(
        // 타이틀 좌측정렬
        centerTitle: false,
        title: Text(title.title),
        actions: [
          IconButton(
            iconSize: 25,
            icon: Icon(user == null ? Icons.login : Icons.logout),
            onPressed: () {
              user == null
                  ? Navigator.pushNamed(context, '/login')
                  : logout(context);
            },
          ),
          IconButton(
            iconSize: 25,
            icon: const Icon(Icons.text_snippet_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/text');
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () {
              if (_auth.currentUser == null || _auth.currentUser!.uid == null) {
                Navigator.pushNamed(context, '/login');
                return;
              } else {
                Navigator.pushNamed(context, '/post/publish');
              }
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
        const shop.Shop(),
        user == null ? const regester.Regester() : const myinfo.MyInfo(),
      ][tabIndex],
      bottomNavigationBar: BottomNavigationBar(
        showSelectedLabels: false,
        showUnselectedLabels: false,
        unselectedItemColor: Colors.black,
        selectedItemColor: Colors.black,
        onTap: (value) => setState(() => tabIndex = value),
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'home'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined), label: 'bag'),
          if (user != null)
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outlined),
              label: 'info',
            )
          else
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_add_alt_1_outlined),
              label: 'regester',
            )
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

  // 앱 바의 제목 변경
  void setTitleText() {
    Provider.of<AppBarTitle>(context, listen: false).setTitle('HOME');
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, setTitleText);
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
