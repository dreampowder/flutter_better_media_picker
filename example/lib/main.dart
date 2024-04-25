import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_better_media_picker/media_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ScreenMain(),
    );
  }
}

class ScreenMain extends StatefulWidget {
  const ScreenMain({Key? key}) : super(key: key);

  @override
  State<ScreenMain> createState() => _ScreenMainState();
}

class _ScreenMainState extends State<ScreenMain> {

  File? pickedFile;

  void pickAsset(BuildContext context){
    MediaPicker.pickAssets(
      context,
      maxAssets: 1,
      assetType: MediaPickerAssetType.image,
    ).then((value) async{
      debugPrint("Completed");
      if(value?.isEmpty ?? true){
        return;
      }
      pickedFile = await value!.first.file;
      setState(() {

      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: Column(
        children: [
          if(pickedFile !=null)Image.file(pickedFile!,height: 400,width: 400,fit: BoxFit.contain,),
          Center(
            child: ElevatedButton(child: const Text("Show picker?"),onPressed:()=>pickAsset(context),),
          ),
        ],
      ),
    );
  }
}

