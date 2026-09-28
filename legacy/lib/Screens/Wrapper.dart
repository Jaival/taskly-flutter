import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Screens/Home.dart';
import '../Screens/LandingPage.dart';
import '../Model/FirebaseUser.dart';

class Wrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<FirebaseUser>(context);

    // Returns home or landing page on basis of user value
    return user == null ? LandingPage() : Home();
  }
}
