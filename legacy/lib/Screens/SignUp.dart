import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Model/FirebaseUser.dart';
import '../Widgets/SignUp/SignUpView.dart';
import 'Home.dart';

class SignUp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<FirebaseUser>(context);

    // Returns home or signup page on basis of user value
    return user == null ? SignUpView() : Home();
  }
}
