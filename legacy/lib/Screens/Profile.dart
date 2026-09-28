import 'package:flutter/material.dart';

import '../Widgets/Profile/ProfileView.dart';

class Profile extends StatelessWidget {
  final user;

  Profile({this.user});

  @override
  Widget build(BuildContext context) {
    return ProfileView(
      user: user,
    );
  }
}
