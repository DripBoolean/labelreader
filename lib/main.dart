import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/services.dart' show rootBundle;


enum FoodType {nonVegetarian, nonVegan}

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _cameras = await availableCameras();
  runApp(const CameraApp());
}

/// CameraApp is the Main Application.
class CameraApp extends StatefulWidget {
  /// Default Constructor
  const CameraApp({super.key});

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController controller;
  var inCapture = false;
  var textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  XFile? image;
  var imageText = "I Like Pizza";
  late Map vDict;

  void initVDict() async {
    var temp = jsonDecode(await rootBundle.loadString('assets/v_data.json'));

    vDict = {};
    for (String key in temp.keys) {
      for (String item in temp[key]) {
        vDict[item] = key;
      }
    } 
  } 

  @override
  void initState() {
    super.initState();

    initVDict();

    controller = CameraController(_cameras[0], ResolutionPreset.max, enableAudio: false);
    controller.initialize().then((_) async {
      if (!mounted) {
        return;
      }
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            // Handle access errors here.
            break;
          default:
            // Handle other errors here.
            break;
        }
      }
    });
    
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)
      ),
      home: Container(
        color: Theme.of(context).colorScheme.primaryContainer,
        child:  Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Builder(
                    builder: (context) {
                      if (!inCapture) {
                        return CameraPreview(controller);
                      } else {
                        return FittedBox(
                          fit: BoxFit.cover,
                          child: Image.file(File(image!.path))
                        );
                      }
                    }
                  )
                ),
              )
            ),
            Builder(
              builder: (context) {
                if (!inCapture) {
                  return FloatingActionButton(
                    onPressed: () async {
                      try {
                        print(await rootBundle.loadString('assets/v_data.json'));
                        // print(await File("assets/v_data.json").readAsString());
                        image = await controller.takePicture();
                        inCapture = true;
                        var recognizedText = (await textRecognizer.processImage(InputImage.fromFile(File(image!.path)))).text;
                        
                        imageText = "";

                        RegExp exp = RegExp(r'(\w+)');
                        Iterable<RegExpMatch> matches = exp.allMatches(recognizedText);
                        for (final m in matches) {
                          var mStr = m.group(0)!.toUpperCase();
                          if (vDict.containsKey(mStr)) {
                            imageText += "$mStr ";
                          }
                        }

                        
                        setState(() {});
                      } catch (e) {
                        // If an error occurs, log the error to the console.
                      }
                    },
                    child: const Icon(Icons.camera_alt),
                  );
                } else {
                  return  FloatingActionButton(
                    onPressed: () {
                      inCapture = false;
                      setState(() {});
                    },
                    child: const Icon(Icons.check),
                  );
                }
              }
            ),
            Text(imageText),
          ],
        )
      ),
    );
  }
}
