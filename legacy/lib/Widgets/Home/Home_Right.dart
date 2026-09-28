import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Model/UserData.dart';
import '../../Screens/Profile.dart';
import '../../Model/ProjectModel.dart';
import '../../Model/TaskModel.dart';

class HomeRightDashboard extends StatelessWidget {
  final double width;

  HomeRightDashboard({this.width});

  @override
  Widget build(BuildContext context) {
    int totalTasks;
    int totalProject;
    final task = Provider.of<List<TaskData>>(context);
    final project = Provider.of<List<ProjectData>>(context);
    final user = Provider.of<UserData>(context);

    if (task != null && project != null) {
      totalTasks = task.length;
      totalProject = project.length;
    } else {
      totalTasks = 0;
      totalProject = 0;
    }

    return Container(
      width: width / 5,
      child: Column(
        children: [
          //TODO:  Profile(Pic and button)
          Container(
            padding: EdgeInsets.only(top: 20.0, right: 20.0),
            child: InkWell(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (BuildContext context) => Profile(
                        user: user,
                      ),
                    ));
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    child: Text("J"),
                    radius: 25.0,
                  ),
                  IconButton(
                      icon: RotatedBox(
                        quarterTurns: 1,
                        child: icon,
                      ),
                      onPressed: null)
                ],
              ),
            ),
          ),
          // Information about projects and tasks
          Padding(
            padding: EdgeInsets.only(
                top: 150.0, left: 50.0, right: 15.0, bottom: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total Projects",
                  style: Theme.of(context).textTheme.bodyText2.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 20.0),
                ),
                Row(
                  children: [
                    icon,
                    Text(
                      totalProject.toString(),
                      style: Theme.of(context).textTheme.bodyText2.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 20.0),
                    ),
                  ],
                )
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 50.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total tasks",
                  style: Theme.of(context).textTheme.bodyText2.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 20.0),
                ),
                Row(
                  children: [
                    icon,
                    Text(
                      totalTasks.toString(),
                      style: Theme.of(context).textTheme.bodyText2.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 20.0),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
      color: Color.fromRGBO(145, 245, 173, 1),
    );
  }
}

final icon = Icon(
  Icons.play_arrow_rounded,
  size: 30.0,
);
