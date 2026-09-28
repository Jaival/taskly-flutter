import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Model/ProjectModel.dart';
import '../../Shared/CustomNoTask.dart';
import '../../Shared/CustomProjectTile.dart';
import '../../Shared/Loading.dart';
import 'CreateProject.dart';
import 'ProjectTaskView.dart';

class ProjectView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final projects = Provider.of<List<ProjectData>>(context);
    return projects == null
        ? Expanded(
            child: Loading(),
          )
        : Expanded(
            child: SingleChildScrollView(
              child: Container(
                color: Color.fromRGBO(252, 239, 249, 1),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(vertical: 50.0, horizontal: 70.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Project's",
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 35.0,
                                  fontWeight: FontWeight.bold),
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
                                          CreateProject(),
                                    ));
                              },
                              label: Padding(
                                padding: EdgeInsets.only(
                                    right: 5.0, top: 10.0, bottom: 10.0),
                                child: Text("New Project",
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

                        // Project List Name
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
                              // Stream Builder Project List
                              Container(
                                height: 200,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: projects.map<Widget>((data) {
                                    Color color;
                                    String priority = data.priority;
                                    String status = data.status;

                                    if (priority == "Immediate") {
                                      color = Color.fromRGBO(240, 93, 94, 1.0);
                                    } else if (priority == "High") {
                                      color = Color.fromRGBO(255, 186, 73, 1.0);
                                    } else if (priority == "Medium") {
                                      color =
                                          Color.fromRGBO(255, 227, 129, 1.0);
                                    } else if (priority == "Low") {
                                      color = Color.fromRGBO(97, 226, 148, 1.0);
                                    }

                                    return status == "Not Started"
                                        ? Container(
                                            width: 200,
                                            child: CustomProjectTile(
                                              name: data.projectName,
                                              description: data.projectDesc,
                                              status: data.status,
                                              priority: data.priority,
                                              color: color,
                                              showEdit: true,
                                              iconTapped: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (BuildContext
                                                            context) =>
                                                        CreateProject(
                                                      docId: data.projectId,
                                                      name: data.projectName,
                                                      description:
                                                          data.projectDesc,
                                                      status: data.status,
                                                      priority: data.priority,
                                                    ),
                                                  ),
                                                );
                                              },
                                              onTapped: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (BuildContext
                                                            context) =>
                                                        ProjectTaskView(
                                                      projectId: data.projectId,
                                                      projectName: data.projectName,
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
                        //  In Progress
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
                              // Stream Builder Project List
                              Container(
                                // margin: EdgeInsets.only(left: 10.0),
                                height: 200,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: projects.map<Widget>((data) {
                                    Color color;
                                    String priority = data.priority;
                                    String status = data.status;

                                    if (priority == "Immediate") {
                                      color = Color.fromRGBO(240, 93, 94, 1.0);
                                    } else if (priority == "High") {
                                      color = Color.fromRGBO(255, 186, 73, 1.0);
                                    } else if (priority == "Medium") {
                                      color =
                                          Color.fromRGBO(255, 227, 129, 1.0);
                                    } else if (priority == "Low") {
                                      color = Color.fromRGBO(97, 226, 148, 1.0);
                                    }

                                    return status == "In Progress"
                                        ? Container(
                                            width: 200,
                                            child: CustomProjectTile(
                                              name: data.projectName,
                                              description: data.projectDesc,
                                              status: data.status,
                                              priority: data.priority,
                                              color: color,
                                              showEdit: true,
                                              iconTapped: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (BuildContext
                                                            context) =>
                                                        CreateProject(
                                                      docId: data.projectId,
                                                      name: data.projectName,
                                                      description:
                                                          data.projectDesc,
                                                      status: data.status,
                                                      priority: data.priority,
                                                    ),
                                                  ),
                                                );
                                              },
                                              onTapped: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (BuildContext
                                                            context) =>
                                                        ProjectTaskView(
                                                      projectId: data.projectId,
                                                      projectName: data.projectName,
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
                        //    Completed
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
                              // Stream Builder Project List
                              Container(
                                height: 200,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: projects.map<Widget>((data) {
                                    Color color;
                                    String priority = data.priority;
                                    String status = data.status;

                                    if (priority == "Immediate") {
                                      color = Color.fromRGBO(240, 93, 94, 1.0);
                                    } else if (priority == "High") {
                                      color = Color.fromRGBO(255, 186, 73, 1.0);
                                    } else if (priority == "Medium") {
                                      color =
                                          Color.fromRGBO(255, 227, 129, 1.0);
                                    } else if (priority == "Low") {
                                      color = Color.fromRGBO(97, 226, 148, 1.0);
                                    }

                                    return status == "Complete"
                                        ? Container(
                                            width: 200,
                                            child: CustomProjectTile(
                                              name: data.projectName,
                                              description: data.projectDesc,
                                              status: data.status,
                                              priority: data.priority,
                                              color: color,
                                              showEdit: true,
                                              iconTapped: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (BuildContext
                                                            context) =>
                                                        CreateProject(
                                                      docId: data.projectId,
                                                      name: data.projectName,
                                                      description:
                                                          data.projectDesc,
                                                      status: data.status,
                                                      priority: data.priority,
                                                    ),
                                                  ),
                                                );
                                              },
                                              onTapped: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (BuildContext
                                                            context) =>
                                                        ProjectTaskView(
                                                      projectId: data.projectId,
                                                      projectName: data.projectName,
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
                      ]),
                ),
              ),
            ),
          );
  }
}
