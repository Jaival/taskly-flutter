import 'package:flutter/material.dart';

class Error extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          "404 Not Found",
          style: Theme.of(context)
              .textTheme
              .headline5
              .copyWith(color: Colors.black),
        ),
      ),
    );
  }
}
