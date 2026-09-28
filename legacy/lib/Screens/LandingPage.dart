import 'package:flutter/material.dart';

import '../Widgets/LandingPage/LandingPageView.dart';
import '../Widgets/NavBar/navBar.dart';

class LandingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: SingleChildScrollView(
          child: Column(
            children: [
              NavBar(),
              Container(
                color: Color.fromRGBO(253, 204, 77, 1.0),
                padding: const EdgeInsets.symmetric(
                  vertical: 20.0,
                  horizontal: 100.0,
                ),
                child: LandingPageView(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
