import 'package:flutter/material.dart';

class PayPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _appBarImage(),
            const SizedBox(width: 10),
            _title(),
          ],
        ),
        toolbarHeight: 72,
      ),
    );
  }

  Widget _title() {
    return const Text(
      'DOTS',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Color.fromARGB(225, 0, 74, 173),
        fontFamily: 'Quicksand',
      ),
    );
  }

  Widget _appBarImage() {
    return Image.network(
      'https://firebasestorage.googleapis.com/v0/b/dots-b3559.appspot.com/o/Dots%20logo.png?alt=media&token=2c2333ea-658a-4a70-9378-39c6c248f5ca',
      height: 55,
      width: 55,
      errorBuilder:
          (BuildContext context, Object exception, StackTrace? stackTrace) {
        return const Text('Image not found');
      },
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: PayPage(),
  ));
}
