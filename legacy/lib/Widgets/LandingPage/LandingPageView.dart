import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../Screens/SignUp.dart';
import '../../Screens/ContactUs.dart';

class LandingPageView extends StatelessWidget {
  final String taskText =
      "Why is task management tool important? It helps us to keep track of the tasks from the beginning, setting deadlines, prioritizing the tasks.";
  final String organizationText =
      "Why is task management tool important? It helps us to keep track of the tasks from the beginning, setting deadlines, prioritizing the tasks.";

  List<Widget> pageContainerRow(double width, BuildContext context) {
    return <Widget>[
      Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.only(right: 30.0),
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Text(
                        taskText,
                        style: Theme.of(context)
                            .textTheme
                            .headline6
                            .copyWith(color: Colors.black),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              vertical: 20.0, horizontal: 40.0),
                          primary: Theme.of(context).primaryColor),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (BuildContext context) => SignUp(),
                          ),
                        );
                      },
                      child: Text(
                        "Get Started",
                        style: Theme.of(context)
                            .textTheme
                            .button
                            .copyWith(color: Colors.white),
                      ),
                    )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Image.asset(
                  "assets/images/1.jpg",
                  width: width,
                  scale: 1.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Image.asset(
                "assets/images/2.jpg",
                width: width,
                scale: 2.0,
              ),
              Container(
                padding: EdgeInsets.only(left: 30.0),
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Text(
                        organizationText,
                        style: Theme.of(context)
                            .textTheme
                            .headline6
                            .copyWith(color: Colors.black),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            vertical: 20.0, horizontal: 40.0),
                        primary: Theme.of(context).primaryColor,
                      ),
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (BuildContext context) => ContactUs(),
                            ));
                      },
                      child: Text(
                        "Contact Us",
                        style: Theme.of(context)
                            .textTheme
                            .button
                            .copyWith(color: Colors.white),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ];
  }

  List<Widget> pageContainerColumn(double width, context) {
    return <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Image.asset(
          "assets/images/1.jpg",
          width: width,
        ),
      ),
      Container(
        padding: EdgeInsets.only(right: 10.0),
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                taskText,
                style: Theme.of(context)
                    .textTheme
                    .headline6
                    .copyWith(color: Colors.black),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  padding:
                      EdgeInsets.symmetric(vertical: 20.0, horizontal: 40.0),
                  primary: Theme.of(context).primaryColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (BuildContext context) => SignUp(),
                  ),
                );
              },
              child: Text(
                "Get Started",
                style: Theme.of(context)
                    .textTheme
                    .button
                    .copyWith(color: Colors.white),
              ),
            )
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Image.asset(
          "assets/images/2.jpg",
          width: width,
          scale: 2.0,
        ),
      ),
      Container(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                organizationText,
                style: Theme.of(context)
                    .textTheme
                    .headline6
                    .copyWith(color: Colors.black),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 40.0),
                primary: Theme.of(context).primaryColor,
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (BuildContext context) => ContactUs(),
                    ));
              },
              child: Text(
                "Contact Us",
                style: Theme.of(context)
                    .textTheme
                    .button
                    .copyWith(color: Colors.white),
              ),
            )
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constrains) {
      if (constrains.maxWidth > 800) {
        return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: pageContainerRow(constrains.biggest.width / 2, context));
      } else {
        return Column(
            children: pageContainerColumn(constrains.biggest.width, context));
      }
    });
  }
}
