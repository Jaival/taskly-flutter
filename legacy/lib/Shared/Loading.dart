import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class Loading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        child: SpinKitFoldingCube(
          color: Color.fromRGBO(54, 65, 86, 1.0),
          size: 50.0,
        ),
      ),
    );
  }
}
