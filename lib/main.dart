import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'login.dart';
import 'provider.dart';
import 'notification.dart';
import 'post_upload.dart';
import 'text_detector.dart';
import 'style.dart' as style;
import 'user_profile.dart' as userprofile;
import 'shop.dart' as shop;
import 'regester.dart' as regester;
import 'my_info.dart' as myinfo;
import 'full_screen_image.dart';

FirebaseStorage _storage = FirebaseStorage.instance;
FirebaseFirestore _store = FirebaseFirestore.instance;
FirebaseAuth _auth = FirebaseAuth.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await dotenv.load(fileName: ".env");

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (context) => DataProvider()),
      ChangeNotifierProvider(create: (context) => UserProvider()),
      ChangeNotifierProvider(create: (context) => TitleProvider()),
    ],
    child: MaterialApp(
      theme: style.theme,
      initialRoute: '/',
      routes: {
        '/': (context) => const MyApp(),
        '/text': (context) => const TextDetector(),
        '/login': (context) => const Login(),
        '/post/publish': (context) => const PostUpload(propsData: null),
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

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

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

  // Future<void> getPostList({String? divi}) async {
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

  //   await showSnackBar(context,
  //       '통신 실패: ${response.statusCode} ERROR, ${jsonData['message']}');
  // }

  Future<void> getPostList({String? divi}) async {
    setState(() {
      parentLoading = true;
    });

    int perPage = 3;
    QuerySnapshot result;
    Query query =
        _store.collection('mainPosts').orderBy('timestamp', descending: true);

    if (divi == 'add' && postData.isNotEmpty) {
      query = query.startAfterDocument(postData.last).limit(perPage);
    } else {
      postData = []; // 초기화
      query = query.limit(perPage);
    }

    try {
      result = await query.get();
      setState(() {
        postData.addAll(result.docs);
      });
    } catch (e) {
      SnackBar(
        content: Text('에러: $e'),
      );
    }

    // savePostListFromSharedPreferences();
    setState(() {
      parentLoading = false;
    });
  }

  addPostList() async {
    await getPostList(divi: 'add');
  }

  void setTitleText() {
    Provider.of<TitleProvider>(context, listen: false).setTitle('HOME');
  }

  dynamic setUserInfoProvider(context) async {
    final user = _auth.currentUser;

    try {
      final member = await _store
          .collection('members')
          .where('uid', isEqualTo: user!.uid)
          .get();

      Provider.of<UserProvider>(context, listen: false).setUser(UserModel(
        uid: member.docs[0]['uid'],
        displayName: member.docs[0]['displayName'],
        email: member.docs[0]['email'],
        photoURL: member.docs[0]['photoURL'],
      ));
    } catch (e) {
      showSnackBar(context, '에러: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    initNotification(context);
    requestPermission();
    getPostListFromSharedPreferences();
    Future.delayed(Duration.zero, setTitleText);
    Future.delayed(Duration.zero, () {
      setUserInfoProvider(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    // final mediaQuery = MediaQuery.of(context).size.width > 640; // 기기 반응형 넓이
    final logout = Provider.of<UserProvider>(context).logout;
    final title = Provider.of<TitleProvider>(context).title;
    bool isLogin = _auth.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        // 타이틀 좌측정렬
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: Text(title),
        actions: [
          IconButton(
            iconSize: 25,
            icon: Icon(isLogin ? Icons.logout : Icons.login),
            onPressed: () {
              isLogin
                  ? logout(context)
                  : Navigator.pushNamed(context, '/login');
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
              if (isLogin) {
                Navigator.pushNamed(context, '/post/publish');
              } else {
                Navigator.pushNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      // PageView 를 사용하면 슬라이드 형태로 페이지를 나눌 수 있음.
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: getPostList,
        child: [
          PostList(
              postData: postData,
              getPostList: addPostList,
              parentLoading: parentLoading),
          const shop.Shop(),
          isLogin ? const myinfo.MyInfo() : const regester.Regester()
        ][tabIndex],
      ),
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
          if (isLogin)
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
  List<dynamic>? userPhotoUrl;

  // 앱 바의 제목 변경
  void setTitleText() {
    Provider.of<TitleProvider>(context, listen: false).setTitle('HOME');
  }

  getScrollAddPost() {
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

  deleteMainPost(context, post, idx) {
    // 게시물을 삭제할 건 물어본 후 게시물과 이미지 삭제
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('게시물 삭제'),
          content: const Text('게시물을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: const Text('삭제'),
              onPressed: () async {
                final Reference imageRef =
                    _storage.refFromURL(post['contentImage']);

                await imageRef.delete();
                await _store.collection('mainPosts').doc(post!.id).delete();
                showSnackBar(context, '게시물이 정상적으로 삭제됐습니다.');

                // 삭제가 완료됐다면 화면 갱신
                setState(() {
                  widget.postData.remove(post);
                  Navigator.pop(context);
                });
              },
            ),
          ],
        );
      },
    );
  }

  getCurrentUserData(userId) async {
    final currentUserInfo = await _store
        .collection('members')
        .where('uid', isEqualTo: userId)
        .get()
        .then((value) => value.docs.first.data());

    return currentUserInfo;
  }

  @override
  void initState() {
    super.initState();
    getScrollAddPost();
    Future.delayed(Duration.zero, setTitleText);
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
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
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
                        widget.postData[idx]['writerId'] ==
                                _auth.currentUser?.uid
                            ? SizedBox(
                                // 게시물 삭제/수정 버튼 추가
                                child: IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(Icons.edit),
                                              title: const Text('수정'),
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        PostUpload(
                                                            propsData: widget
                                                                .postData[idx],
                                                            editMode: true),
                                                  ),
                                                );
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.delete),
                                              title: const Text('삭제'),
                                              onTap: () {
                                                deleteMainPost(context,
                                                    widget.postData[idx], idx);
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              )
                            : const SizedBox(),
                      ],
                    ),
                  ),
                  widget.postData[idx]['contentImage'] != null &&
                          widget.postData[idx]['contentImage'] != ''
                      ? GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullScreenImage(
                                  imageUrls: [
                                    widget.postData[idx]['contentImage']
                                  ],
                                  initialIndex: 0,
                                ),
                              ),
                            );
                            // showDialog(
                            //   context: context,
                            //   builder: (BuildContext context) {
                            //     return Dialog(
                            //       backgroundColor: Colors.green,
                            //       child: FullScreenImage(
                            //           imageUrl: widget.postData[idx]
                            //               ['contentImage']),
                            //     );
                            //   },
                            // );
                          },
                          child: Image.network(
                            widget.postData[idx]['contentImage'],
                            height: 300,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset('assets/default.png');
                            },
                          ))
                      : const SizedBox(height: 300),
                  Container(
                    padding:
                        const EdgeInsets.only(top: 20, left: 20, right: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            FutureBuilder(
                              future: getCurrentUserData(
                                  widget.postData[idx]['writerId']),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  // 에러 발생 시 에러 메시지를 반환
                                  return Text('Error: ${snapshot.error}');
                                } else if (snapshot.hasData) {
                                  final userInfo =
                                      snapshot.data as Map<String, dynamic>;
                                  final writerPhoto = userInfo["photoURL"];
                                  final writerName = userInfo['displayName'];

                                  return GestureDetector(
                                    child: Row(
                                      children: [
                                        Container(
                                          margin:
                                              const EdgeInsets.only(right: 10),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            child: Image.network(
                                              writerPhoto,
                                              width: 30,
                                              height: 30,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Image.asset(
                                                    'assets/default.png');
                                              },
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          child: Text(
                                            writerName,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                          builder: (c) =>
                                              userprofile.UserProfile(
                                            userId: widget.postData[idx]
                                                ["writerId"],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                } else {
                                  return const Text('No data available.');
                                }
                              },
                            ),
                            Text('좋아요 ${widget.postData[idx]["like"]}',
                                style: const TextStyle(color: Colors.black)),
                          ],
                        ),
                        Container(
                          constraints: const BoxConstraints(minHeight: 80),
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.only(top: 15),
                          child: Text('${widget.postData[idx]["content"]}',
                              style: const TextStyle(
                                  color: Colors.black, fontSize: 20)),
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
