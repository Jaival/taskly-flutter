import 'package:flutter/material.dart';

import '../LeftSideLoginSignUp/LeftSide.dart';
import '../RightSideLoginSignUp/RightSideSignup.dart';

class SignUpView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: width / 3,
            color: Color.fromRGBO(54, 65, 86, 1),
            child: LeftSide(
              pageName: "Sign Up",
              pageFooterStarting: "Already have an account?",
              pageFooterEnding: "Login",
            ),
          ),
          Container(
            width: width * 2 / 3,
            color: Color.fromRGBO(84, 69, 141, 1),
            child: RightSideSignUp(),
          ),
        ],
      ),
    );
  }
}
