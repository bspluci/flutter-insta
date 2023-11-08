import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification.dart';
import 'provider.dart';

final firestore = FirebaseFirestore.instance;

class UserProfile extends StatefulWidget {
  final String userId;
  const UserProfile({Key? key, required this.userId}) : super(key: key);

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  Map<String, dynamic> resultUser = {};
  List<dynamic> resultGallery = [];
  bool clickFollower = false;

  getUserInfo(context) async {
    try {
      final result = await firestore
          .collection('members')
          .where('uid', isEqualTo: widget.userId)
          .get();

      final getUser = result.docs.map((e) => e.data()).toList()[0];

      setState(() {
        resultUser = getUser;
      });

      await getUserGallery(context);
      await showSnackBar(context, '유저 정보가 성공적으로 로드되었습니다.');
    } catch (e) {
      showSnackBar(context, '에러: $e');
      await showSnackBar(context, '유저 정보 로드에 실패하였습니다. 다시 시도해 주세요.');
    }
  }

  getUserGallery(context) async {
    try {
      final result = await firestore
          .collection('mainPosts')
          .where('writerId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .get();

      final gallery = result.docs.map((e) => e.data()['contentImage']).toList();

      setState(() => resultGallery = gallery);
    } catch (e) {
      showSnackBar(context, '에러: $e');
    }
  }

  void incFollower() {
    setState(() {
      !clickFollower ? resultUser['follower']++ : resultUser['follower']--;
      clickFollower = !clickFollower;
    });
  }

  @override
  void initState() {
    super.initState();
    getUserInfo(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<DataProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(resultUser['displayName'] ?? ''),
        automaticallyImplyLeading: false,
      ),
      body: resultUser.isNotEmpty && resultGallery.isNotEmpty
          ? CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Image.network(
                      resultUser['photoURL'] ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  // Padding(
                  // padding: const EdgeInsets.all(10.0),
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 유져 프로필 사진
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                fit: BoxFit.cover,
                                image:
                                    NetworkImage(resultUser['photoURL'] ?? ''),
                              ),
                              color: Colors.grey),
                        ),
                        // 팔로워수, 팔로우 버튼
                        Text(
                            '팔로워 ${store.addCommasToNumber(resultUser['follower'] ?? 0)}'),
                        ElevatedButton(
                          onPressed: () => incFollower(),
                          child: const Text('팔로우'),
                        ),
                      ],
                    ),
                  ),
                  // ),
                ),
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 3,
                    crossAxisSpacing: 3,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      return Image.network(
                        resultGallery[index] ?? '',
                        fit: BoxFit.cover,
                      );
                    },
                    childCount: resultGallery.length,
                  ),
                )
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
