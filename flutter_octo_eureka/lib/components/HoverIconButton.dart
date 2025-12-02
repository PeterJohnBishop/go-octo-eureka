import 'package:flutter/material.dart';

class HoverIconButton extends StatelessWidget {
  final onTap;
  const HoverIconButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Color(0xFFE0E5EC),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.white,
              offset: Offset(-6, -6),
              blurRadius: 16,
            ),
            BoxShadow(
              color: Color(0xFFA3B1C6),
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