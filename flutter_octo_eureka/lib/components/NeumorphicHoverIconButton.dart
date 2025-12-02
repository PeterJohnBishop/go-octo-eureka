import 'package:flutter/material.dart';

class NeumorphicHoverIconButton extends StatefulWidget {
  final VoidCallback? onTap; 

  const NeumorphicHoverIconButton({Key? key, this.onTap}) : super(key: key);

  @override
  _NeumorphicHoverIconButtonState createState() => _NeumorphicHoverIconButtonState();
}

class _NeumorphicHoverIconButtonState extends State<NeumorphicHoverIconButton> {
  bool isPressed = false;

  void _handleTap() async {
    setState(() {
      isPressed = true;
    });

    await Future.delayed(Duration(milliseconds: 100));

    if (mounted) {
      setState(() {
        isPressed = false;
      });
    }

    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap, 
      child: AnimatedContainer(
        duration: Duration(milliseconds: 100),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Color(0xFFA3B1C6),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isPressed ? Color.fromARGB(255, 152, 165, 181) : Color(0xFFA3B1C6),
            width: 2,
          ),
          boxShadow: [
            isPressed
                ? BoxShadow(
                    color: Color(0xFFA3B1C6),
                    offset: Offset(0, 0),
                    blurRadius: 16,
                  )
                : BoxShadow(
                    color: Color.fromARGB(255, 197, 208, 224),
                    offset: Offset(-6, -6),
                    blurRadius: 16,
                  ),
            isPressed
                ? BoxShadow(
                    color: Color(0xFFA3B1C6),
                    offset: Offset(0, 0),
                    blurRadius: 16,
                  )
                : BoxShadow(
                    color: Color.fromARGB(255, 123, 136, 155),
                    offset: Offset(6, 6),
                    blurRadius: 16,
                  ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.add,
            color: Color(0xFF6F7C8A),
          ),
        ),
      ),
    );
  }
}