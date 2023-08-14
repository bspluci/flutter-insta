import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'provider.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({Key? key}) : super(key: key);

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataProvider>(context, listen: false).getUserInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<DataProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(store.resultUser[0]['name']),
        automaticallyImplyLeading: false,
      ),
      body: store.resultUser[0]['image'] != '' && store.resultGallery[0] != ''
          ? CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Image.network(
                      store.resultUser[0]['image'],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  // Padding(
                  // padding: const EdgeInsets.all(10.0),
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
                              image: NetworkImage(store.resultUser[0]['image']),
                            ),
                            color: Colors.grey),
                      ),
                      // 팔로워수, 팔로우 버튼
                      Text('팔로워 ${store.resultUser[0]['fallower']}'),
                      ElevatedButton(
                        onPressed: () => store.incFollower(),
                        child: const Text('팔로우'),
                      ),
                    ],
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
                        store.resultGallery[index],
                        fit: BoxFit.cover,
                      );
                    },
                    childCount: store.resultGallery.length,
                  ),
                )
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
