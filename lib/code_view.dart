import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class CodeView extends StatefulWidget {
  const CodeView({Key? key}) : super(key: key);

  @override
  State<CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  bool isLoading = false;
  bool isEditText = false;
  File? selectedImage;
  String? recognizedText;
  String? selectedText;
  String? sendText;
  String? editedText;
  String? refactoringText;

  final _readyText = '텍스트를 인식하려면 이미지를 선택하세요';
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer textDetector = TextRecognizer();

  Future<void> _pickImage() async {
    final pickedImage = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      setState(() => isLoading = true);
      final imageFile = File(pickedImage.path);

      setState(() {
        selectedImage = imageFile;
        recognizedText = null;
        selectedText = null;
        sendText = null;
        editedText = null;
        refactoringText = null;
      });

      // 이미지에서 텍스트 추출
      final inputImage = InputImage.fromFile(imageFile);
      final text = await textDetector.processImage(inputImage);

      setState(() {
        isLoading = false;
        recognizedText = text.text;
      });
    }
  }

  Future<void> generateText() async {
    if (sendText == null) {
      if (selectedText != null) {
        sendText = selectedText;
      } else {
        return;
      }
    }
    sendText = selectedText != null ? '$sendText\n$selectedText' : sendText;

    setState(() {
      isLoading = true;
      recognizedText = null;
    });

    String content = '$sendText \n 코드 리팩토링';

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${dotenv.env['CHAT_API_KEY']}'
      },
      body: jsonEncode({
        'model': dotenv.env['CHAT_MODEL'],
        'messages': [
          {
            'role': 'user',
            'content': content,
          }
        ]
      }),
    );

    final Map<String, dynamic> responseData = json.decode(response.body);

    refactoringText = responseData['choices'][0]['message']['content'];

    setState(() {
      isLoading = false;
      sendText = null;
      selectedText = null;
    });
  }

  @override
  void dispose() {
    textDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CODE VIEW'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                margin: const EdgeInsets.only(top: 50),
                child: Column(
                  children: [
                    selectedImage == null
                        ? const Text('')
                        : Image.file(selectedImage!, height: 350),
                    const SizedBox(height: 20.0),
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: const Text('갤러리에서 이미지 선택'),
                    ),
                  ],
                ),
              ),
              isLoading
                  ? Container(
                      margin: const EdgeInsets.only(top: 50),
                      child: const CircularProgressIndicator(),
                    )
                  : Container(
                      margin: const EdgeInsets.only(top: 30),
                      child: Text(
                        selectedImage == null ? _readyText : '',
                        style:
                            const TextStyle(fontSize: 20, color: Colors.black),
                      ),
                    ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Container(
                  alignment: Alignment.topLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: recognizedText == null && refactoringText != null
                      ? SelectableText(refactoringText ?? '',
                          style: const TextStyle(
                              fontSize: 18, color: Colors.black))
                      : recognizedText == null && refactoringText == null
                          ? const Text('')
                          : TextSelectionTheme(
                              data: const TextSelectionThemeData(
                                cursorColor: Colors.blue,
                                selectionColor: Colors.blue,
                                selectionHandleColor: Colors.blue,
                              ),
                              child: SelectableText(
                                '$recognizedText',
                                style: const TextStyle(
                                    fontSize: 18, color: Colors.black),
                                showCursor: true,
                                contextMenuBuilder:
                                    (context, editableTextState) {
                                  return AdaptiveTextSelectionToolbar
                                      .buttonItems(
                                    anchors:
                                        editableTextState.contextMenuAnchors,
                                    buttonItems: <ContextMenuButtonItem>[
                                      ContextMenuButtonItem(
                                        onPressed: () {
                                          editableTextState.selectAll(
                                              SelectionChangedCause.toolbar);
                                        },
                                        type: ContextMenuButtonType.selectAll,
                                      ),
                                    ],
                                  );
                                },
                                onSelectionChanged: (selection, cause) {
                                  final text = recognizedText!.substring(
                                      selection.start, selection.end);
                                  text.isEmpty
                                      ? setState(() => selectedText = null)
                                      : setState(() => selectedText = text);
                                },
                              ),
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: refactoringText != null
          ? const SizedBox()
          : SizedBox(
              child: selectedText != null || sendText != null
                  ? ElevatedButton(
                      onPressed: () {
                        showPopup(context); // 팝업 띄우기
                      },
                      child: const Text('선택한 텍스트 보기'),
                    )
                  : ElevatedButton(
                      style: disabledButtonStyle,
                      onPressed: () {},
                      child: const Text('선택한 텍스트 보기'),
                    ),
            ),
    );
  }

  final enabledButtonStyle = ButtonStyle(
    backgroundColor: MaterialStateProperty.all(Colors.blue),
    foregroundColor: MaterialStateProperty.all(Colors.white),
  );
  final disabledButtonStyle = ButtonStyle(
    backgroundColor: MaterialStateProperty.all(Colors.grey),
    foregroundColor: MaterialStateProperty.all(Colors.white),
  );
  final double btnWidth = 50;
  final EdgeInsetsGeometry btnPadding =
      const EdgeInsets.only(left: 3, right: 3);

  void showPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Selected Text'),
          content: SizedBox(
            child: SingleChildScrollView(
              child: isEditText
                  ? FractionallySizedBox(
                      child: SizedBox(
                        height: 300,
                        child: TextField(
                          maxLines: 20,
                          controller: TextEditingController(text: editedText),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: '문구 수정',
                          ),
                          onChanged: (text) {
                            setState(() {
                              editedText = text;
                            });
                          },
                        ),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '저장: ${sendText ?? ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(height: 10),
                        Text('추가: ${selectedText ?? '추가할 문구가 없습니다'}'),
                      ],
                    ),
            ),
          ),
          actions: [
            isEditText
                ? SizedBox(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: btnWidth,
                          padding: btnPadding,
                          child: TextButton(
                            style: enabledButtonStyle,
                            onPressed: () {
                              setState(() => {
                                    isEditText = false,
                                    sendText = editedText,
                                    selectedText = null,
                                  });
                              Navigator.of(context).pop();
                              showPopup(context);
                            },
                            child: const Text('완료'),
                          ),
                        ),
                        Container(
                          width: btnWidth,
                          padding: btnPadding,
                          child: TextButton(
                            style: enabledButtonStyle,
                            onPressed: () {
                              setState(
                                () => isEditText = false,
                              );
                              Navigator.of(context).pop();
                              showPopup(context);
                            },
                            child: const Text('취소'),
                          ),
                        ),
                      ],
                    ),
                  )
                : SizedBox(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: btnWidth,
                          padding: btnPadding,
                          child: TextButton(
                            style: enabledButtonStyle,
                            onPressed: () {
                              String message = '선택된 코드를 리팩토링 하시겠습니까?';
                              Navigator.of(context).pop(); // 팝업을 닫습니다.
                              showYnPopup(context, message, generateText);
                            },
                            child: const Text('변환'),
                          ),
                        ),
                        Container(
                          width: btnWidth,
                          padding: btnPadding,
                          child: TextButton(
                            style: enabledButtonStyle,
                            onPressed: () {
                              const message = '선택한 문구를 추가하시겠습니까?';
                              void setFunction() {
                                setState(() {
                                  sendText == null
                                      ? sendText = selectedText ?? ''
                                      : sendText =
                                          '${sendText ?? ''}\n${selectedText ?? ''}';
                                  selectedText = null;
                                });
                              }

                              Navigator.of(context).pop();
                              showYnPopup(context, message, setFunction);
                            },
                            child: const Text('추가'),
                          ),
                        ),
                        Container(
                          width: btnWidth,
                          padding: btnPadding,
                          child: TextButton(
                            style: enabledButtonStyle,
                            onPressed: () {
                              setState(() {
                                isEditText = true;
                                editedText =
                                    '${sendText ?? ' '}${selectedText ?? ''}';
                              }); // 팝업을 닫습니다.
                              Navigator.of(context).pop();
                              showPopup(context);
                            },
                            child: const Text('수정'),
                          ),
                        ),
                        Container(
                          width: btnWidth,
                          padding: btnPadding,
                          child: TextButton(
                            style: enabledButtonStyle,
                            onPressed: () {
                              const message = '선택한 문구를 비우시겠습니까?';
                              void setFunction() {
                                setState(() {
                                  sendText = null;
                                  selectedText = null;
                                });
                              }

                              Navigator.of(context).pop();
                              showYnPopup(context, message, setFunction);
                            },
                            child: const Text('비움'),
                          ),
                        ),
                        Container(
                          width: btnWidth,
                          padding: btnPadding,
                          child: TextButton(
                            style: enabledButtonStyle,
                            onPressed: () {
                              Navigator.of(context).pop(); // 팝업을 닫습니다.
                            },
                            child: const Text('닫기'),
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
        );
      },
    );
  }

  void showYnPopup(
      BuildContext context, String? message, Function? executeFunction) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('알림'),
          content: SingleChildScrollView(
              child: Column(
            children: [
              Text(message ?? ''),
            ],
          )),
          actions: [
            TextButton(
              style: enabledButtonStyle,
              onPressed: () {
                executeFunction!();
                Navigator.of(context).pop(); // 팝업을 닫습니다.
              },
              child: const Text('예'),
            ),
            TextButton(
              style: enabledButtonStyle,
              onPressed: () {
                Navigator.of(context).pop(); // 팝업을 닫습니다.
                showPopup(context);
              },
              child: const Text('아니오'),
            ),
          ],
        );
      },
    );
  }
}
