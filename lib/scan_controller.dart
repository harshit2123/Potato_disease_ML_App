import 'dart:typed_data';
import 'package:tensorflow_lite_flutter/tensorflow_lite_flutter.dart';
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
  int _imageCount = 0;

  @override
  void dispose() {
    _isInitialized.value = false;
    _cameraController.dispose();
    super.dispose();
    Tflite.close();
  }

  Future<void> _initTensorFlow() async {
    String? res = await Tflite.loadModel(
        model: "assets/mobilenet_v1_1.0_224.tflite",
        labels: "assets/labels.txt",
        numThreads: 1, // defaults to 1
        isAsset:
            true, // defaults to true, set to false to load resources outside assets
        useGpuDelegate:
            false // defaults to false, set to true to use GPU delegate
        );
  }

  Future<void> _ObjectRecognition(CameraImage cameraImage) async {
    var recognitions = await Tflite.runModelOnFrame(
        bytesList: cameraImage.planes.map((plane) {
          return plane.bytes;
        }).toList(), // required
        imageHeight: cameraImage.height,
        imageWidth: cameraImage.width,
        imageMean: 127.5, // defaults to 127.5
        imageStd: 127.5, // defaults to 127.5
        rotation: 90, // defaults to 90, Android only
        numResults: 2, // defaults to 5
        threshold: 0.1, // defaults to 0.1
        asynch: true // defaults to true
        );

    print(recognitions);
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
          _imageCount++;
          if (_imageCount % 10 == 0) {
            _imageCount = 0;
            _ObjectRecognition(image);
          }
          ;
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
    _initTensorFlow();
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
