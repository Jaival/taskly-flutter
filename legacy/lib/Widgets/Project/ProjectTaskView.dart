import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Model/FirebaseUser.dart';
import '../../Model/TaskModel.dart';
import '../../Services/Database.dart';
import '../../Shared/CustomTile.dart';
import '../../Shared/DropDownData.dart';
import '../../Shared/Loading.dart';
import '../Tasks/CreateTasks.dart';

class ProjectTaskView extends StatefulWidget {
  final String projectId;
  final String projectName;

  ProjectTaskView({this.projectId, this.projectName});

  @override
  _ProjectTaskViewState createState() => _ProjectTaskViewState();
}

class _ProjectTaskViewState extends State<ProjectTaskView> {
  final TextEditingController controllerTaskName = TextEditingController();
  final TextEditingController controllerTaskDesc = TextEditingController();
  final TextEditingController controllerMember = TextEditingController();

  String _selectedTaskItemPriority;
  String _selectedTaskItemStatus;

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<FirebaseUser>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("Taskly"),
        elevation: 0.0,
      ),
      body: Container(
        padding: EdgeInsets.only(top: 50.0),
        color: Color.fromRGBO(252, 239, 249, 1),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      child: Text(
                        "Create Project Task",
                        style: TextStyle(color: Colors.black, fontSize: 50),
                      ),
                    ),
                    // Task Name
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 12.0),
                      width: 200,
                      // color: Colors.yellow,
                      child: TextField(
                        controller: controllerTaskName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyText1
                            .copyWith(color: Colors.black),
                        cursorColor: Colors.black,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          filled: true,
                          fillColor: Color.fromRGBO(196, 196, 196, 0.42),
                          labelText: "Task Name",
                          labelStyle: Theme.of(context)
                              .textTheme
                              .bodyText1
                              .copyWith(color: Colors.black),
                        ),
                      ),
                    ),
                    // Task Description
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 12.0),
                      width: 200,
                      // color: Colors.yellow,
                      child: TextField(
                        controller: controllerTaskDesc,
                        style: Theme.of(context)
                            .textTheme
                            .bodyText1
                            .copyWith(color: Colors.black),
                        cursorColor: Colors.black,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          filled: true,
                          fillColor: Color.fromRGBO(196, 196, 196, 0.42),
                          labelText: "Task Description",
                          labelStyle: Theme.of(context)
                              .textTheme
                              .bodyText1
                              .copyWith(color: Colors.black),
                        ),
                      ),
                    ),
                    // Priority
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 12.0),
                      width: 200,
                      // color: Colors.yellow,
                      child: DropdownButton<String>(
                        underline: SizedBox(),
                        hint: Text("Select a Priority"),
                        value: _selectedTaskItemPriority,
                        icon: RotatedBox(
                          quarterTurns: 1,
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 20.0,
                          ),
                        ),
                        items: DropDown().dropdownPriorityItems.map((priority) {
                          return DropdownMenuItem(
                            child: Text(priority),
                            value: priority,
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            print(value);
                            _selectedTaskItemPriority = value;
                          });
                        },
                      ),
                    ),
                    // Status
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 12.0),
                      width: 200,
                      // color: Colors.yellow,
                      child: DropdownButton<String>(
                        underline: SizedBox(),
                        hint: Text("Select a status"),
                        value: _selectedTaskItemStatus,
                        items: DropDown().dropdownStatusItems.map((status) {
                          return DropdownMenuItem(
                            child: Text(status),
                            value: status,
                          );
                        }).toList(),
                        icon: RotatedBox(
                          quarterTurns: 1,
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 20.0,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _selectedTaskItemStatus = value;
                            print(_selectedTaskItemStatus);
                          });
                        },
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 12.0),
                      width: 250,
                      // color: Colors.yellow,
                      child: TextField(
                        controller: controllerMember,
                        style: Theme.of(context)
                            .textTheme
                            .bodyText1
                            .copyWith(color: Colors.black),
                        cursorColor: Colors.black,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          filled: true,
                          fillColor: Color.fromRGBO(196, 196, 196, 0.42),
                          labelText: "Member",
                          labelStyle: Theme.of(context)
                              .textTheme
                              .bodyText1
                              .copyWith(color: Colors.black),
                        ),
                      ),
                    ),
                    Text(
                      "Note:Don't Update the member for now",
                      style: TextStyle(color: Colors.black),
                    )
                  ],
                ),
                Column(
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 20.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              vertical: 20.0, horizontal: 80.0),
                          primary: Color.fromRGBO(255, 203, 119, 1.0),
                        ),
                        onPressed: widget.projectId != null
                            ? () async {
                                await DatabaseService(uid: user.uid)
                                    .createProjectTaskData(
                                  projectId: widget.projectId,
                                  projectName: widget.projectName,
                                  taskName: controllerTaskName.text.toString(),
                                  taskDesc: controllerTaskDesc.text.toString(),
                                  priority:
                                      _selectedTaskItemPriority.toString(),
                                  status: _selectedTaskItemStatus.toString(),
                                  member: controllerMember.text.toString(),
                                );
                                await DatabaseService().shareTasks(
                                  creator: user.uid,
                                  projectId: widget.projectId,
                                  member: controllerMember.toString(),
                                );
                                final snackBar = SnackBar(
                                  content: Text('Project Task Created'),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snackBar);
                                Navigator.pop(context);
                              }
                            : null,
                        child: Text(
                          "Create Project Task",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
            widget.projectId == null
                ? Text("")
                : StreamBuilder<List<TaskData>>(
                    stream: DatabaseService(uid: user.uid)
                        .streamProjectTaskData(docId: widget.projectId),
                    builder: (context, AsyncSnapshot<List<TaskData>> snapshot) {
                      if (!snapshot.hasData) {
                        return Text(
                          "No Data",
                          style: TextStyle(color: Colors.black),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.active) {
                        if (snapshot.hasData) {
                          return Container(
                            margin: EdgeInsets.only(left: 10.0),
                            // width: 200,
                            height: 200,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: snapshot.data.map<Widget>((data) {
                                Color color;
                                String priority = data.priority;

                                if (priority == "Immediate") {
                                  color = Colors.red;
                                } else if (priority == "High") {
                                  color = Colors.redAccent;
                                } else if (priority == "Medium") {
                                  color = Colors.yellowAccent;
                                } else if (priority == "Low") {
                                  color = Colors.greenAccent;
                                }

                                return Container(
                                  width: 200,
                                  height: 300,
                                  child: CustomTile(
                                    name: data.taskName,
                                    description: data.taskDesc,
                                    priority: data.priority,
                                    status: data.status,
                                    color: color,
                                    onTapped: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (BuildContext context) =>
                                              CreateTask(
                                            docId: data.taskId,
                                            name: data.taskName,
                                            description: data.taskDesc,
                                            priority: data.priority,
                                            status: data.status,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }
                      } else {
                        return Text("Connection Closed");
                      }
                      return Loading();
                    }),
          ],
        ),
      ),
    );
  }
}
