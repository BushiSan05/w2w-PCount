import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FullScreenImagePage extends StatelessWidget {
  final String imagePath;

  const FullScreenImagePage({
    // super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.file(
            File(imagePath),
          ),
        ),
      ),
    );
  }
}