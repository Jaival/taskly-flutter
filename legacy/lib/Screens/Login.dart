import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Model/FirebaseUser.dart';
import '../Widgets/Login/LoginView.dart';
import 'Home.dart';

class LogIn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<FirebaseUser>(context);

    // Returns home or login page on basis of user value
    return user == null ? LoginView() : Home();
  }
}
