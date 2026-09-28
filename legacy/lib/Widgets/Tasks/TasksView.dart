import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Model/TaskModel.dart';
import '../../Shared/CustomNoTask.dart';
import '../../Shared/CustomTile.dart';
import '../../Shared/Loading.dart';
import 'CreateTasks.dart';

class TaskView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final task = Provider.of<List<TaskData>>(context);
    return task == null
        ? Expanded(
            child: Loading(),
          )
        : Expanded(
            child: SingleChildScrollView(
              child: Container(
                color: Color.fromRGBO(252, 239, 249, 1),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(vertical: 30.0, horizontal: 70.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Task's",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 35.0,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              primary: Colors.blueGrey,
                              backgroundColor:
                                  Color.fromRGBO(188, 231, 253, 1.0),
                            ),
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (BuildContext context) =>
                                        CreateTask(),
                                  ));
                            },
                            label: Padding(
                              padding: EdgeInsets.only(
                                  right: 5.0, top: 10.0, bottom: 10.0),
                              child: Text("New Tasks",
                                  style: Theme.of(context).textTheme.button),
                            ),
                            icon: Padding(
                              padding: EdgeInsets.only(left: 5.0),
                              child: Icon(
                                Icons.add,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Tasks List
                      // Not Started
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Not Started",
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.black,
                                fontSize: 20.0,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            // ListView Tasks List
                            Container(
                              // margin: EdgeInsets.only(left: 10.0),
                              height: 200,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: task.map<Widget>((data) {
                                  Color color;
                                  String priority = data.priority;
                                  String status = data.status;

                                  if (priority == "Immediate") {
                                    color = Color.fromRGBO(240, 93, 94, 1.0);
                                  } else if (priority == "High") {
                                    color = Color.fromRGBO(255, 186, 73, 1.0);
                                  } else if (priority == "Medium") {
                                    color = Color.fromRGBO(255, 227, 129, 1.0);
                                  } else if (priority == "Low") {
                                    color = Color.fromRGBO(97, 226, 148, 1.0);
                                  }

                                  return status == "Not Started"
                                      ? Container(
                                          // margin: EdgeInsets.only(right: 10.0),
                                          width: 200,
                                          child: CustomTile(
                                            name: data.taskName,
                                            description: data.taskDesc,
                                            status: data.status,
                                            priority: data.priority,
                                            color: color,
                                            onTapped: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (BuildContext context) =>
                                                          CreateTask(
                                                    docId: data.taskId,
                                                    name: data.taskName,
                                                    description: data.taskDesc,
                                                    status: data.status,
                                                    priority: data.priority,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      : NoTaskContainer();
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // In Progress
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "In Progress",
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.black,
                                fontSize: 20.0,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            //  Stream Builder Tasks List
                            Container(
                              // margin: EdgeInsets.only(left: 10.0),
                              height: 200,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: task.map<Widget>((data) {
                                  Color color;
                                  String priority = data.priority;
                                  String status = data.status;

                                  if (priority == "Immediate") {
                                    color = Color.fromRGBO(240, 93, 94, 1.0);
                                  } else if (priority == "High") {
                                    color = Color.fromRGBO(255, 186, 73, 1.0);
                                  } else if (priority == "Medium") {
                                    color = Color.fromRGBO(255, 227, 129, 1.0);
                                  } else if (priority == "Low") {
                                    color = Color.fromRGBO(97, 226, 148, 1.0);
                                  }
                                  return status == "In Progress"
                                      ? Container(
                                          width: 200,
                                          child: CustomTile(
                                            name: data.taskName,
                                            description: data.taskDesc,
                                            status: data.status,
                                            priority: data.priority,
                                            color: color,
                                            onTapped: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (BuildContext context) =>
                                                          CreateTask(
                                                    docId: data.taskId,
                                                    name: data.taskName,
                                                    description: data.taskDesc,
                                                    status: data.status,
                                                    priority: data.priority,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      : NoTaskContainer();
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Completed
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Completed",
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.black,
                                fontSize: 20.0,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            // Stream Builder Tasks List
                            Container(
                              // margin: EdgeInsets.only(left: 10.0),
                              height: 200,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: task.map<Widget>((data) {
                                  Color color;
                                  String priority = data.priority;
                                  String status = data.status;

                                  if (priority == "Immediate") {
                                    color = Color.fromRGBO(240, 93, 94, 1.0);
                                  } else if (priority == "High") {
                                    color = Color.fromRGBO(255, 186, 73, 1.0);
                                  } else if (priority == "Medium") {
                                    color = Color.fromRGBO(255, 227, 129, 1.0);
                                  } else if (priority == "Low") {
                                    color = Color.fromRGBO(97, 226, 148, 1.0);
                                  }
                                  return status == "Complete"
                                      ? Container(
                                          width: 200,
                                          child: CustomTile(
                                            name: data.taskName,
                                            description: data.taskDesc,
                                            status: data.status,
                                            priority: data.priority,
                                            color: color,
                                            onTapped: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (BuildContext context) =>
                                                          CreateTask(
                                                    docId: data.taskId,
                                                    name: data.taskName,
                                                    description: data.taskDesc,
                                                    status: data.status,
                                                    priority: data.priority,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      : NoTaskContainer();
                                }).toList(),
                              ),
                            ),
                          ],
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
