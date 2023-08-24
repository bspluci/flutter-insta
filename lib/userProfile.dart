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

  @override
  void initState() {
    super.initState();
    getUserInfo();
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   Provider.of<DataProvider>(context, listen: false).getUserInfo();
    // });
  }

  getUserInfo() async {
    try {
      final result =
          await firestore.collection('members').doc(widget.userId).get();
      setState(() {
        resultUser = result.data()!;
      });
      await showNotification(1, '유저 정보 로드 완료', '유저 정보가 성공적으로 로드되었습니다.');
    } catch (e) {
      print(e);
      await showNotification(
          1, '유저 정보 로드 실패', '유저 정보 로드에 실패하였습니다. 다시 시도해 주세요.');
    }

    await getUserGallery();
  }

  getUserGallery() async {
    try {
      final result = await firestore
          .collection('mainPosts')
          .where('writerId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .get();

      final gallery = result.docs.map((e) => e.data()['image']).toList();

      setState(() => resultGallery = gallery);
    } catch (e) {
      print(e);
    }
  }

  void incFollower() {
    setState(() {
      clickFollower ? resultUser['follower']++ : resultUser['follower']--;
      clickFollower = !clickFollower;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<DataProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(resultUser['userName'] ?? ''),
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
                      resultUser['profileImg'],
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
                                fit: BoxFit.fill,
                                image: NetworkImage(resultUser['profileImg']),
                              ),
                              color: Colors.grey),
                        ),
                        // 팔로워수, 팔로우 버튼
                        Text(
                            '팔로워 ${store.addCommasToNumber(resultUser['follower'])}'),
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
                        resultGallery[index],
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
