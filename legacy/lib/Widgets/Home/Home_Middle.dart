import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Shared/Loading.dart';
import '../../Model/ProjectModel.dart';
import '../../Model/TaskModel.dart';
import '../../Shared/CustomTile.dart';

class HomeMiddleDashboard extends StatelessWidget {
  final double width;

  HomeMiddleDashboard({this.width});

  @override
  Widget build(BuildContext context) {
    final task = Provider.of<List<TaskData>>(context);
    final project = Provider.of<List<ProjectData>>(context);
    return Expanded(
      child: Container(
        height: double.infinity,
        color: Color.fromRGBO(252, 239, 249, 1),
        child: Padding(
          padding: EdgeInsets.all(70.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                //Today's Tasks,
                Container(
                  margin: EdgeInsets.symmetric(vertical: 10.0),
                  child: Text(
                    "Projects",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 30.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Stream Builder Tasks List
                project == null
                    ? Loading()
                    : Container(
                        height: 200.0,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: project.map<Widget>((data) {
                            Color color;
                            String priority = data.priority;

                            if (priority == "Immediate") {
                              color = Color.fromRGBO(240, 93, 94, 1.0);
                            } else if (priority == "High") {
                              color = Color.fromRGBO(255, 186, 73, 1.0);
                            } else if (priority == "Medium") {
                              color = Color.fromRGBO(255, 227, 129, 1.0);
                            } else if (priority == "Low") {
                              color = Color.fromRGBO(97, 226, 148, 1.0);
                            }

                            return Container(
                              // margin: EdgeInsets.only(right: 10.0),
                              width: 200,
                              child: CustomTile(
                                name: data.projectName,
                                description: data.projectDesc,
                                status: data.status,
                                priority: data.priority,
                                color: color,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                // Upcoming Tasks
                Container(
                  margin: EdgeInsets.symmetric(vertical: 10.0),
                  child: Text(
                    "Tasks",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 30.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                //Stream Builder Tasks List
                task == null
                    ? Loading()
                    : Container(
                        height: 200.0,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: task.map<Widget>((data) {
                            Color color;
                            String priority = data.priority;

                            if (priority == "Immediate") {
                              color = Color.fromRGBO(240, 93, 94, 1.0);
                            } else if (priority == "High") {
                              color = Color.fromRGBO(255, 186, 73, 1.0);
                            } else if (priority == "Medium") {
                              color = Color.fromRGBO(255, 227, 129, 1.0);
                            } else if (priority == "Low") {
                              color = Color.fromRGBO(97, 226, 148, 1.0);
                            }

                            return Container(
                              // margin: EdgeInsets.only(right: 10.0),
                              width: 200,
                              child: CustomTile(
                                name: data.taskName,
                                description: data.taskDesc,
                                status: data.status,
                                priority: data.priority,
                                color: color,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
