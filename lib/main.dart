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
  Map<String, Set<String>> foundText = {"Vegan": <String>{}, "Vegetarian": <String>{}};
  late Map vDict;
  var expansionData = {"Vegan": false, "Vegetarian": false};
  var containsExclusionary = false;

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
                aspectRatio: 0.7,
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
                if (containsExclusionary) {
                  print("Doing it!");
                  return Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Card(
                      child: ExpansionPanelList(
                      expansionCallback: (index, isExpanded) {
                        setState(() {
                          if (foundText["Vegan"]!.isEmpty) {
                            expansionData["Vegetarian"] = isExpanded;
                            return;
                          }
                          if (foundText["Vegetarian"]!.isEmpty) {
                            expansionData["Vegan"] = isExpanded;
                            return;
                          }
                          expansionData[["Vegan", "Vegetarian"][index]] = isExpanded;
                            
                        });
                      },
                      children: [
                        for (var key in foundText.keys.where((item) => foundText[item]!.isNotEmpty))
                          //if (foundText[key]!.isNotEmpty)
                          ExpansionPanel(headerBuilder: (context, isExpanded) {
                            return Center(child: Text("Non-$key"));
                          }, 
                          body: Column(
                            children: [
                              for (var item in foundText[key]!) 
                                Text(item),
                            ],
                          ),
                          isExpanded: expansionData[key]!
                          ),
                        // ExpansionPanel(headerBuilder: (context, isExpanded) {
                        //   return Center(child: Text("Non-Vegetarian"));
                        // }, 
                        // body: Column(
                        //   children: [
                        //     for (var item in foundText["Vegetarian"]!) 
                        //       Text(item),
                        //   ],
                        // ),
                        // isExpanded: expansionData[1]
                        // ),
                      ],),
                    ),
                  
                  );
                } else {
                  if (inCapture) {
                    return Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text("Looks good to me!"),
                        )),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text("Take a photo to scan"),
                        )
                      ),
                    );
                  }
                }
              }
            ),

            Builder(
              builder: (context) {
                if (!inCapture) {
                  return FloatingActionButton(
                    onPressed: () async {
                      try {
                        // print(await rootBundle.loadString('assets/v_data.json'));
                        // print(await File("assets/v_data.json").readAsString());
                        image = await controller.takePicture();
                        inCapture = true;
                        var recognizedText = (await textRecognizer.processImage(InputImage.fromFile(File(image!.path)))).text;
                        
                        containsExclusionary = false;
                        foundText = {"Vegan": {}, "Vegetarian": {}};

                        RegExp exp = RegExp(r'(\w+)');
                        Iterable<RegExpMatch> matches = exp.allMatches(recognizedText);
                        for (final m in matches) {
                          var mStr = m.group(0)!.toUpperCase();
                          print(mStr);
                          if (vDict.containsKey(mStr)) {
                            containsExclusionary = true;
                            foundText[vDict[mStr]!]!.add(mStr);
                          }
                        }
                        print(foundText);
                        
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

          ],
        )
      ),
    );
  }
}

class Expandable extends StatelessWidget {
  Expandable({required this.title, required this.items, super.key});

  final String title;
  final List<String> items;

  @override Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        ExpandIcon(onPressed: (_) {}),
        Text(title)
      ],),
    ],);
  }
}
