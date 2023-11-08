import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class TextDetector extends StatefulWidget {
  const TextDetector({Key? key}) : super(key: key);

  @override
  State<TextDetector> createState() => _TextDetectorState();
}

class _TextDetectorState extends State<TextDetector> {
  bool isLoading = false;
  bool isEditText = false;
  File? selectedImage;
  String? recognizedText;
  String? selectedText;
  String? sendText;
  String? editedText;
  String? refactoringText;
  String doSeomthing = '코드 리팩토링';

  final _doController = TextEditingController();
  final _doFocus = FocusNode();
  final _readyText = '텍스트를 인식하려면 이미지를 선택하세요';
  final ImagePicker _picker = ImagePicker();
  var _script = TextRecognitionScript.latin;
  var _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

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
      final extractedText = await _textRecognizer.processImage(inputImage);
      setState(() {
        isLoading = false;
        recognizedText = extractedText.text;
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

    String content = '$sendText \n $doSeomthing';

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${dotenv.env['GPT_API_KEY']}'
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
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
  void initState() {
    super.initState();
    _doController.text = doSeomthing;
  }

  @override
  void dispose() async {
    _textRecognizer.close();
    _doController.dispose();
    _doFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Detector'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Positioned(
              top: 10,
              left: 100,
              right: 100,
              child: Row(
                children: [
                  const Spacer(),
                  Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: _buildDropdown(),
                      )),
                  const Spacer(),
                ],
              ),
            ),
            Column(
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
                      Container(
                        height: 50,
                        margin: const EdgeInsets.only(top: 20),
                        child: FractionallySizedBox(
                          widthFactor: 0.8,
                          child: TextField(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            onTap: () {
                              _doFocus.requestFocus();
                            },
                            focusNode: _doFocus,
                            controller: _doController,
                            onChanged: (text) {
                              setState(() => doSeomthing = text);
                            },
                          ),
                        ),
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
                          style: const TextStyle(
                              fontSize: 20, color: Colors.black),
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
          ],
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
                              String message = '$doSeomthing 하시겠습니까?';
                              Navigator.of(context).pop(); // 팝업을 닫습니다.
                              showYnPopup(context, message, generateText);
                            },
                            child: const Text('GPT'),
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

  Widget _buildDropdown() => DropdownButton<TextRecognitionScript>(
        value: _script,
        dropdownColor: Colors.black54,
        iconEnabledColor: Colors.white,
        padding: const EdgeInsets.only(left: 10, right: 10),
        icon: const Icon(Icons.arrow_downward),
        elevation: 16,
        style: const TextStyle(color: Colors.white),
        underline: Container(
          height: 2,
          color: Colors.white,
        ),
        onChanged: (TextRecognitionScript? script) {
          if (script != null) {
            setState(() {
              _script = script;
              _textRecognizer.close();
              _textRecognizer = TextRecognizer(script: _script);
            });
          }
        },
        items: TextRecognitionScript.values
            .map<DropdownMenuItem<TextRecognitionScript>>((script) {
          return DropdownMenuItem<TextRecognitionScript>(
            value: script,
            child: Text(script.name.toUpperCase()),
          );
        }).toList(),
      );

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
