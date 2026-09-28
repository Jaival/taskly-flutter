import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Model/UserData.dart';
import '../../Screens/SharedTask.dart';
import '../../Screens/Projects.dart';
import '../../Screens/Tasks.dart';
import 'Home_Middle.dart';

class HomeLeftDashboard extends StatefulWidget {
  final double width;

  HomeLeftDashboard({this.width});

  @override
  _HomeLeftDashboardState createState() => _HomeLeftDashboardState();
}

class _HomeLeftDashboardState extends State<HomeLeftDashboard> {
  int _selectedIndex = 0;
  List<String> list = ["Home", "Tasks", "Project", "SharedTask"];

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserData>(context);
    return Expanded(
      child: Row(
        children: [
          Container(
            width: (widget.width / 5),
            color: Color.fromRGBO(54, 65, 86, 1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                //TODO:  Logo
                Container(
                  padding: EdgeInsets.symmetric(vertical: 70.0),
                  child: Text(
                    "Taskly",
                    style: Theme.of(context)
                        .textTheme
                        .headline4
                        .copyWith(fontSize: 50),
                  ),
                ),
                Container(
                  height: 300.0,
                  padding:
                      EdgeInsets.symmetric(vertical: 50.0, horizontal: 50.0),
                  child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (BuildContext context, int index) {
                        return ListTile(
                          title: Text(
                            list[index],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.0,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedIndex = index;
                              // print(list[index]);
                            });
                          }, // Handle your onTap here.
                        );
                      }),
                ),
              ],
            ),
          ),
          // Middle
          _selectedIndex == 0
              ? HomeMiddleDashboard()
              : _selectedIndex == 1
                  ? Tasks()
                  : _selectedIndex == 2
                      ? Projects()
                      : _selectedIndex == 3
                          ? SharedTask(user: user)
                          : Container(
                              color: Colors.black,
                            ),
        ],
      ),
    );
  }
}
