import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Model/FirebaseUser.dart';
import '../../Services/Database.dart';
import '../../Shared/DropDownData.dart';

class CreateTask extends StatefulWidget {
  final String docId;
  final String name;
  final String description;

  final String priority;
  final String status;
  final String member;
  final String projectId;

  CreateTask(
      {this.docId,
      this.name,
      this.description,
      this.priority,
      this.status,
      this.projectId,
      this.member});

  @override
  _CreateTaskState createState() => _CreateTaskState();
}

class _CreateTaskState extends State<CreateTask> {
  final TextEditingController controllerName = TextEditingController();

  final TextEditingController controllerDesc = TextEditingController();

  final TextEditingController controllerMember = TextEditingController();

  String _selectedItemPriority;
  String _selectedItemStatus;

  @override
  void initState() {
    _selectedItemPriority = widget.priority;
    _selectedItemStatus = widget.status;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<FirebaseUser>(context);

    controllerName.text = widget.name;
    controllerDesc.text = widget.description;
    controllerMember.text = widget.member;
    // _selectedItemPriority = widget.priority;
    // _selectedItemStatus = widget.status;

    return Scaffold(
      appBar: AppBar(
        title: Text("Taskly"),
        elevation: 0.0,
      ),
      body: Container(
        padding: EdgeInsets.symmetric(vertical: 70.0, horizontal: 100.0),
        width: double.infinity,
        height: double.infinity,
        color: Color.fromRGBO(252, 239, 249, 1),
        child: SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    child: widget.docId == null
                        ? Text(
                            "Create Task",
                            style: TextStyle(color: Colors.black, fontSize: 50),
                          )
                        : Text(
                            "Update Task",
                            style: TextStyle(color: Colors.black, fontSize: 50),
                          ),
                  ),
                  // Task Name
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 12.0),
                    width: 250,
                    // color: Colors.yellow,
                    child: TextField(
                      controller: controllerName,
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
                    width: 250,
                    // color: Colors.yellow,
                    child: TextField(
                      controller: controllerDesc,
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
                    width: 250,
                    // color: Colors.yellow,
                    child: DropdownButton<String>(
                      underline: SizedBox(),
                      hint: Text("Select a Priority"),
                      value: _selectedItemPriority,
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
                          _selectedItemPriority = value;
                          print(_selectedItemPriority.toString());
                        });
                      },
                    ),
                  ),
                  // Status
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 12.0),
                    width: 250,
                    // color: Colors.yellow,
                    child: DropdownButton<String>(
                      underline: SizedBox(),
                      hint: Text("Select a status"),
                      value: _selectedItemStatus,
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
                          _selectedItemStatus = value;
                          print(_selectedItemStatus.toString());
                        });
                      },
                    ),
                  ),
                  // Member
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
                  Text("Note:Don't Update the member for now",
                      style: Theme.of(context)
                          .textTheme
                          .subtitle1
                          .copyWith(color: Colors.black))
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
                          primary: Color.fromRGBO(255, 203, 119, 1.0)),
                      onPressed: widget.docId == null
                          ? () async {
                              await DatabaseService(uid: user.uid)
                                  .createTaskData(
                                      taskName: controllerName.text.toString(),
                                      taskDesc: controllerDesc.text.toString(),
                                      priority:
                                          _selectedItemPriority.toString(),
                                      status: _selectedItemStatus.toString(),
                                      member: controllerMember.text.toString());
                              await DatabaseService().shareTasks(
                                creator: user.uid,
                                projectId: widget.projectId,
                                member: controllerMember.text.toString(),
                              );
                              final snackBar = SnackBar(
                                content: Text('Task Created'),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                              Navigator.pop(context);
                            }
                          : null,
                      child: Text(
                        "Create Task",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 20.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              vertical: 20.0, horizontal: 80.0),
                          primary: Color.fromRGBO(255, 203, 119, 1.0)),
                      onPressed: widget.docId != null
                          ? () async {
                              await DatabaseService(uid: user.uid)
                                  .updateTasksData(
                                docId: widget.docId,
                                taskName: controllerName.text.toString(),
                                taskDesc: controllerDesc.text.toString(),
                                priority: _selectedItemPriority.toString(),
                                status: _selectedItemStatus.toString(),
                              );
                              final snackBar = SnackBar(
                                content: Text('Task Updated'),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                              Navigator.pop(context);
                            }
                          : null,
                      child: Text(
                        "Update Task",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 20.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            vertical: 20.0, horizontal: 80.0),
                        primary: Color.fromRGBO(255, 203, 119, 1.0),
                      ),
                      onPressed: widget.docId != null
                          ? () async {
                              await DatabaseService(uid: user.uid)
                                  .deleteTasksData(docId: widget.docId);
                              final snackBar = SnackBar(
                                content: Text('Task Deleted'),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                              Navigator.pop(context);
                            }
                          : null,
                      child: Text(
                        "Delete Task",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
