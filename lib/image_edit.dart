import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import 'notification.dart';

class ImageData {
  XFile? pickedFile;
  String? extend;
  dynamic pickedImage;
  File? showImage;

  ImageData({this.pickedFile, this.extend, this.pickedImage, this.showImage});
}

class SelectImage extends ChangeNotifier {
  ImageData? _image;

  ImageData? get image => _image;

  img.Image resizeImageToMax800(img.Image image) {
    int newWidth, newHeight;

    if (image.width > image.height) {
      newWidth = 800;
      newHeight = (800 * image.height / image.width).round();
    } else {
      newHeight = 800;
      newWidth = (800 * image.width / image.height).round();
    }

    return img.copyResize(image, width: newWidth, height: newHeight);
  }

  Future<void> selectImage(context, XFile? pickedFile) async {
    _image = ImageData();
    _image?.pickedFile = pickedFile;
    _image?.extend = _image?.pickedFile?.path.split(".").last;

    dynamic resizedImage;

    if (_image?.pickedFile != null && _image?.extend != 'gif') {
      // 이미지를 읽어오고, 원하는 크기로 조절, 이미지 압축
      final imageFile =
          img.decodeImage(await _image!.pickedFile!.readAsBytes());
      resizedImage = imageFile != null ? resizeImageToMax800(imageFile) : null;

      if (resizedImage != null) {
        // 이미지를 파일로 저장
        File imageFile = File(_image!.pickedFile!.path);

        switch (_image?.extend) {
          case 'jpg':
            imageFile
                .writeAsBytesSync(img.encodeJpg(resizedImage, quality: 80));
            break;
          case 'jpeg':
            imageFile
                .writeAsBytesSync(img.encodeJpg(resizedImage, quality: 80));
            break;
          case 'png':
            imageFile.writeAsBytesSync(img.encodePng(resizedImage));
            break;
          default:
            return await showSnackBar(context, '지원하지 않는 파일형식입니다.');
        }
      }

      _image?.pickedImage = resizedImage;
    }
    _image?.showImage = File(_image!.pickedFile!.path);

    notifyListeners();
  }
}
