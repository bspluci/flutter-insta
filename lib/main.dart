import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'style.dart' as style;
import 'login.dart';
import 'provider.dart';
import 'notification.dart';
import 'post_upload.dart';
import 'text_detector.dart';
import 'user_profile.dart';
import 'shop.dart';
import 'register.dart';
import 'my_info.dart';
import 'full_screen_image.dart';
import 'test.dart';

FirebaseStorage _storage = FirebaseStorage.instance;
FirebaseFirestore _store = FirebaseFirestore.instance;
FirebaseAuth _auth = FirebaseAuth.instance;

void main() async {
  await dotenv.load(fileName: ".env");

  WidgetsFlutterBinding.ensureInitialized();
  KakaoSdk.init(
    nativeAppKey: dotenv.env['KAKAO_APP_KEY'],
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        '/test': (context) => const Test(),
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

  // SharedPreferences에 postList를 저장하는 함수(미사용)
  savePostListFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
        'postData', postData.map((post) => json.encode(post)).toList());
    prefs.setInt('page', page);
  }

  Future<void> getPostList({String? divi, postId}) async {
    setState(() {
      parentLoading = true;
    });

    int perPage = 3;
    QuerySnapshot result;
    Query query =
        _store.collection('mainPosts').orderBy('timestamp', descending: true);

    if (divi == 'add' && postData.isNotEmpty) {
      query = query.startAfterDocument(postData.last).limit(perPage);
    } else if (divi == null) {
      postData = []; // 초기화
      query = query.limit(perPage);
    }

    try {
      result = await query.get();

      setState(() {
        if (divi == 'like') {
          int index = 0;

          for (QueryDocumentSnapshot newPost in result.docs) {
            final postIndex =
                postData.indexWhere((post) => postId == newPost.id);

            if (postIndex != -1) {
              postData[index] = newPost;
              break;
            }
            index++;
          }
        } else {
          postData.addAll(result.docs);
        }
      });
    } catch (e) {
      SnackBar(
        content: Text('에러: $e'),
      );
    }

    if (mounted) {
      setState(() {
        parentLoading = false;
      });
    }
  }

  void setTitleText() {
    Provider.of<TitleProvider>(context, listen: false).setTitle('HOME');
  }

  dynamic setUserInfoProvider(context) async {
    final user = _auth.currentUser;
    final userProvider = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null || userProvider != null) return;

    try {
      final member = await _store
          .collection('members')
          .where('uid', isEqualTo: user.uid)
          .get();

      Provider.of<UserProvider>(context, listen: false).setUser(UserModel(
        uid: member.docs[0]['uid'],
        displayName: member.docs[0]['displayName'],
        email: member.docs[0]['email'],
        photoURL: member.docs[0]['photoURL'],
      ));

      await showSnackBar(
          context, '${member.docs[0]['displayName']} 회원님 로그인이 완료되었습니다.');
    } catch (e) {
      await showSnackBar(context, '에러: $e');
    }
  }

  DateTime? currentBackPressTime;
  Future<bool> onWillPop() async {
    DateTime now = DateTime.now();

    if (currentBackPressTime == null ||
        now.difference(currentBackPressTime!) > const Duration(seconds: 2)) {
      currentBackPressTime = now;
      await showSnackBar(context, "'뒤로'버튼을 한 번 더 누르면 종료됩니다.");

      return Future.value(false);
    }

    SystemNavigator.pop();
    return Future.value(true);
  }

  @override
  void initState() {
    super.initState();
    initNotification(context);
    requestPermission();
    getPostList();
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
            icon: const Icon(Icons.question_mark_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/test');
            },
          ),
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
      body: WillPopScope(
        onWillPop: onWillPop,
        child: RefreshIndicator(
          key: _refreshIndicatorKey,
          onRefresh: getPostList,
          child: [
            PostList(
                postData: postData,
                getPostList: getPostList,
                parentLoading: parentLoading),
            const Shop(),
            isLogin ? const MyInfo() : const Register()
          ][tabIndex],
        ),
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
              label: 'register',
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
        widget.getPostList(divi: 'add').then((value) {
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
                Navigator.pop(dialogContext);
              },
            ),
            TextButton(
              child: const Text('삭제'),
              onPressed: () async {
                if (post['contentImage'] != null &&
                    post['contentImage'].isNotEmpty) {
                  final Reference imageRef =
                      _storage.refFromURL(post['contentImage']);
                  await imageRef.delete();
                }

                await _store.collection('mainPosts').doc(post!.id).delete();

                if (!mounted) return;
                await showSnackBar(dialogContext, '게시물 삭제가 완료됐습니다.');

                // 삭제가 완료됐다면 화면 갱신
                setState(() {
                  widget.postData.remove(post);
                  Navigator.pop(dialogContext);
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

  createLikeIcon(List<dynamic> likedBy) {
    final uid = _auth.currentUser?.uid;
    final isLiked = likedBy.contains(uid);

    if (isLiked) {
      return const Icon(Icons.favorite, color: Colors.red);
    } else {
      return const Icon(Icons.favorite_border_outlined);
    }
  }

  void chackLogin(context) async {
    if (_auth.currentUser == null) {
      await showSnackBar(context, '로그인이 필요한 서비스입니다.');
      Navigator.pushNamed(context, '/login');
    }
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
                                    fontSize: 22,
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
                                              onTap: () async {
                                                Navigator.pop(context);
                                                String? updatedPostId =
                                                    await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        PostUpload(
                                                            propsData: widget
                                                                .postData[idx],
                                                            editMode: true),
                                                  ),
                                                );
                                                if (updatedPostId != null) {
                                                  DocumentSnapshot result =
                                                      await _store
                                                          .collection(
                                                              'mainPosts')
                                                          .doc(updatedPostId)
                                                          .get();
                                                  setState(() => widget
                                                      .postData[idx] = result);
                                                }
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.delete),
                                              title: const Text('삭제'),
                                              onTap: () {
                                                Navigator.pop(context);
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
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImage(
                            imageUrls: [widget.postData[idx]['contentImage']],
                            initialIndex: 0,
                          ),
                        ),
                      );
                    },
                    child: widget.postData[idx]['contentImage'].isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.postData[idx]['contentImage'],
                            height: 300,
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
                        : const SizedBox(),
                  ),
                  Container(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          constraints: const BoxConstraints(minHeight: 80),
                          alignment: Alignment.centerLeft,
                          child: Text('${widget.postData[idx]["content"]}',
                              style: const TextStyle(
                                  color: Colors.black, fontSize: 20)),
                        ),
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
                                          builder: (c) => UserProfile(
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
                            Row(
                              children: [
                                IconButton(
                                  icon: createLikeIcon(
                                      widget.postData[idx]["likedBy"]),
                                  onPressed: () async {
                                    chackLogin(context);
                                    final post = widget.postData[idx];
                                    String? uid = _auth.currentUser?.uid;
                                    final curPostId =
                                        await toggleLikeBtn(uid, post);
                                    widget.getPostList(
                                        divi: 'like',
                                        postId: curPostId['postId']);
                                  },
                                ),
                                Text(' ${widget.postData[idx]["like"]}',
                                    style: const TextStyle(
                                        color: Colors.black, fontSize: 20)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
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
              child: CircularProgressIndicator(),
            )
          : const Center(
              child: Text("게시물이 없습니다."),
            );
    }
  }

  Future<Map<String, dynamic>> toggleLikeBtn(
      String? uid, QueryDocumentSnapshot post) async {
    final DocumentSnapshot postData =
        await _store.collection('mainPosts').doc(post.id).get();
    final List<dynamic> likedBy = postData['likedBy'];
    final bool isLiked = likedBy.contains(uid);

    // 좋아요 버튼을 누른 게시물의 좋아요 수와 좋아요를 누른 사람의 목록을 업데이트
    post.reference.update({
      'like': FieldValue.increment(isLiked ? -1 : 1),
      'likedBy': isLiked
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
    });

    return {
      'postId': post.id,
    };
  }
}
