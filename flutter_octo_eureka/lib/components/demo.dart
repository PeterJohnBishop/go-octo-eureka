import 'package:flutter/material.dart';

import 'NeumorphicHoverIconButton.dart';

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {

  bool isPressed = false;
 
  void buttonPressed() {
    setState(() {
      print("Button was pressed.");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: NeumorphicHoverIconButton(
        onTap: buttonPressed,
      ),
    );
  }
}