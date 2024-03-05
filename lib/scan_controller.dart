import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image/image.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanController extends GetxController {
  late List<CameraDescription> _cameras;
  late CameraController _cameraController;
  final RxBool _isInitialized = RxBool(false);
  CameraImage? _cameraImage;
  final RxList<Uint8List> _imageList = RxList([]);

  CameraController get cameraController => _cameraController;
  bool get isInitialized => _isInitialized.value;
  List<Uint8List> get imageList => _imageList;

  @override
  void dispose() {
    _isInitialized.value = false;
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> checkAndRequestCameraPermissions() async {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      var permissionResult = await Permission.camera.request();
      if (permissionResult != PermissionStatus.granted) {
        print('User denied camera permission.');
      }
    }
  }

  Future<void> initCamera() async {
    await checkAndRequestCameraPermissions(); // Ensure permission first

    _cameras = await availableCameras();

    // Check if cameras are available before accessing them
    if (_cameras.isEmpty) {
      print('No cameras found on device');
      return;
    }

    _cameraController = CameraController(
      _cameras[0],
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );

    _cameraController.initialize().then((value) {
      _isInitialized.value = true;

      _cameraController.startImageStream((image) {
        if (image != null) {
          _cameraImage = image;
          _isInitialized.refresh();
        }
      });
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            print('User denied camera access.');
            break;
          default:
            print('Handle other errors: ${e.code}');
            break;
        }
      }
    });
  }

  @override
  void onInit() {
    initCamera();
    super.onInit();
  }

 void capture() async {
  if (_cameraImage != null &&
      _cameraImage!.width != null &&
      _cameraImage!.height != null &&
      _cameraImage!.planes.isNotEmpty &&
      _cameraImage!.planes[0].bytes != null) {
    try {
      // Extract image data from CameraImage
      final imagePlane = _cameraImage!.planes[0];
      final width = imagePlane.width;
      final height = imagePlane.height;
      final bytes = imagePlane.bytes;

      // Decode the image using the available decoder
      final image = await decodeImage(bytes);

      // Handle potential decoding errors
      if (image == null) {
        print('Error decoding image');
        return;
      }

      // Encode the image as JPEG (assuming suitable format)
      final encodedJpg = img.encodeJpg(image);

      // Add the encoded image data to the image list
      _imageList.add(encodedJpg);
      _imageList.refresh();
    } catch (error) {
      print('Error capturing image: $error');
    }
  }
}


}
