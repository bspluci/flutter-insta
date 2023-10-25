import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'notification.dart';
import 'provider.dart';

final firestore = FirebaseFirestore.instance;

class Shop extends StatefulWidget {
  const Shop({Key? key}) : super(key: key);

  @override
  State<Shop> createState() => _ShopState();
}

class _ShopState extends State<Shop> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? productList;

  void setTitleText() {
    Provider.of<TitleProvider>(context, listen: false).setTitle('Shop');
  }

  @override
  void initState() {
    super.initState();
    _fetchData(); // 데이터 가져오는 비동기 함수 호출

    Future.delayed(Duration.zero, setTitleText);
  }

  Future<void> _fetchData() async {
    try {
      final result = await firestore
          .collection('product')
          .orderBy('createdAt', descending: false)
          .get();

      setState(() {
        productList = result.docs;
      });
    } catch (e) {
      print(e);
    }
  }

  // 선택한 아이템 지우기
  Future<void> _deleteItem(String id) async {
    try {
      await firestore.collection('product').doc(id).delete();
      await showNotification(3, '삭제 완료', '정상적으로 삭제 완료됐습니다.');
      _fetchData();
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<DataProvider>(context);

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('SHOP'),
      //   automaticallyImplyLeading: false,
      //   actions: [
      //     IconButton(
      //       onPressed: () => Navigator.push(
      //         context,
      //         MaterialPageRoute(
      //             builder: (context) =>
      //                 AddShopItem(fetchData: _fetchData, itemState: 'ADD')),
      //       ),
      //       icon: const Icon(Icons.add),
      //     ),
      //   ],
      // ),
      body: productList == null
          ? const Center(child: CircularProgressIndicator())
          : (productList!.isNotEmpty
              ? ListView.builder(
                  itemCount: productList!.length + 1,
                  itemBuilder: (context, index) {
                    index = index - 1;
                    if (index == -1) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => AddShopItem(
                                        fetchData: _fetchData,
                                        itemState: 'ADD')),
                              ),
                              child: const Text('ADD'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddShopItem(
                                fetchData: _fetchData,
                                itemState: 'EDIT',
                                itemData: productList![index],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                '${productList![index]["name"]} : ',
                                style: const TextStyle(
                                    color: Colors.black, fontSize: 19),
                              ),
                              Text(
                                store.addCommasToNumber(
                                    productList![index]['price']),
                                style: const TextStyle(
                                    color: Colors.black, fontSize: 19),
                              ),
                              IconButton(
                                  onPressed: () {
                                    _deleteItem(productList![index].id);
                                  },
                                  icon: const Icon(Icons.close)),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Column(
                    children: [
                      const Text('No data'),
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => AddShopItem(
                                        fetchData: _fetchData,
                                        itemState: 'ADD')),
                              ),
                              child: const Text('ADD'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
    );
  }
}

class AddShopItem extends StatefulWidget {
  final dynamic fetchData;
  final String itemState;
  final dynamic itemData;

  const AddShopItem({
    Key? key,
    required this.fetchData,
    required this.itemState,
    this.itemData,
  }) : super(key: key);

  @override
  State<AddShopItem> createState() => _AddShopItemState();
}

class _AddShopItemState extends State<AddShopItem> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.itemState == 'EDIT') {
      _nameController.text = widget.itemData['name'];
      _priceController.text = widget.itemData['price'].toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _addItemData() async {
    final String name = _nameController.text;
    final String priceStr = _priceController.text;

    if (int.tryParse(priceStr) == null) {
      // Show a notification for invalid price input
      await showInvalidInputNotification(context, "aaaaaaaaaa");
      return;
    }

    try {
      await firestore.collection('product').add({
        'name': name,
        'price': int.parse(priceStr),
        'createdAt': DateTime.now(),
      });
      await showNotification(4, '아이템 추가 완료', '아이템 추가가 완료됐습니다.');
      widget.fetchData();
    } catch (e) {
      print(e);
    }
  }

  Future<void> _editItem() async {
    final String name = _nameController.text;
    final String priceStr = _priceController.text;

    if (int.tryParse(priceStr) == null) {
      // Show a notification for invalid price input
      await showInvalidInputNotification(context, "bbbbbbbbbb");
      return;
    }

    try {
      await firestore.collection('product').doc(widget.itemData?.id).update({
        'name': name,
        'price': int.parse(priceStr),
      });
      await showNotification(5, '아이템 수정 완료', '아이템 수정이 완료됐습니다.');
      widget.fetchData();
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.itemState} SHOP ITEM'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'price',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter price';
                  }
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      widget.itemState == 'EDIT' ? _editItem() : _addItemData();
                      Navigator.pop(context);
                    }
                  },
                  child: Text(widget.itemState),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
