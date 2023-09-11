import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CodeView extends StatefulWidget {
  const CodeView({Key? key}) : super(key: key);

  @override
  State<CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  File? _image;
  bool isLoading = false;
  String? _recognizedText;
  String? selectedText;
  String? sendText;
  String? refactoringCode;

  final _readyText = '텍스트를 인식하려면 이미지를 선택하세요';
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer textDetector = GoogleMlKit.vision.textRecognizer();

  Future<void> _pickImage() async {
    final pickedImage = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      setState(() => isLoading = true);
      final imageFile = File(pickedImage.path);

      setState(() {
        _image = imageFile;
        _recognizedText = null;
      });

      // 이미지에서 텍스트 추출
      final inputImage = InputImage.fromFile(imageFile);
      final text = await textDetector.processImage(inputImage);

      setState(() {
        isLoading = false;
        _recognizedText = text.text;
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

    setState(() {
      isLoading = true;
      _recognizedText = null;
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

    refactoringCode = responseData['choices'][0]['message']['content'];

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
                      _image == null
                          ? const Text('')
                          : Image.file(_image!, height: 350),
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
                          _image == null ? _readyText : '',
                          style: const TextStyle(
                              fontSize: 20, color: Colors.black),
                        ),
                      ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Container(
                    alignment: Alignment.topLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _recognizedText == null && refactoringCode != null
                        ? SelectableText(refactoringCode ?? '',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.black))
                        : _recognizedText == null && refactoringCode == null
                            ? const Text('')
                            : TextSelectionTheme(
                                data: const TextSelectionThemeData(
                                  cursorColor: Colors.blue,
                                  selectionColor: Colors.blue,
                                  selectionHandleColor: Colors.blue,
                                ),
                                child: SelectableText(
                                  '$_recognizedText',
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
                                    final text = _recognizedText!.substring(
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
        floatingActionButton: SizedBox(
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
        ));
  }

  final enabledButtonStyle = ButtonStyle(
    backgroundColor: MaterialStateProperty.all(Colors.blue),
    foregroundColor: MaterialStateProperty.all(Colors.white),
  );
  final disabledButtonStyle = ButtonStyle(
    backgroundColor: MaterialStateProperty.all(Colors.grey),
    foregroundColor: MaterialStateProperty.all(Colors.white),
  );

  void showPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Selected Text'),
          content: Container(
            child: SingleChildScrollView(
              child: Column(
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
            TextButton(
              style: enabledButtonStyle,
              onPressed: () {
                Navigator.of(context).pop(); // 팝업을 닫습니다.
                generateText();
              },
              child: const Text('변환'),
            ),
            TextButton(
              style: enabledButtonStyle,
              onPressed: () {
                const message = '선택한 문구를 추가하시겠습니까?';
                void setFunction() {
                  setState(() {
                    sendText == null
                        ? sendText = selectedText ?? ''
                        : sendText = '${sendText ?? ''}\n${selectedText ?? ''}';
                    selectedText = null;
                  });
                }

                Navigator.of(context).pop();
                showYnPopup(context, message, setFunction);
              },
              child: const Text('추가'),
            ),
            TextButton(
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
              child: const Text('비우기'),
            ),
            TextButton(
              style: enabledButtonStyle,
              onPressed: () {
                Navigator.of(context).pop(); // 팝업을 닫습니다.
              },
              child: const Text('닫기'),
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
                setState(() {
                  executeFunction!();
                });
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
