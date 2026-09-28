import 'package:flutter/material.dart';

import '../Widgets/SharedTask/SharedTaskView.dart';

class SharedTask extends StatelessWidget {
  final user;

  SharedTask({this.user});

  @override
  Widget build(BuildContext context) {
    return SharedTaskView(user: user);
  }
}
