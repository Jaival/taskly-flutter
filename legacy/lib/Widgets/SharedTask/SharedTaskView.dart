import 'package:flutter/material.dart';

import '../../Model/SharedTaskModel.dart';
import '../../Model/TaskModel.dart';
import '../../Services/Database.dart';
import '../../Shared/CustomTile.dart';

class SharedTaskView extends StatelessWidget {
  final user;

  SharedTaskView({this.user});

  @override
  Widget build(BuildContext context) {
    final currentUser = user;
    String username = currentUser.userName;
    print(username);

    return Expanded(
      child: SingleChildScrollView(
        child: Container(
          child: Column(
            children: [
              Text(
                "Shared Tasks",
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 35.0,
                    fontWeight: FontWeight.bold),
              ),
              FutureBuilder(
                future:
                    DatabaseService().futureSharedTaskInfo(member: username),
                builder: (BuildContext context, AsyncSnapshot snapshot) {
                  if (!snapshot.hasData) {
                    return Text("Loading");
                  } else {
                    List<SharedTaskModel> data = snapshot.data;
                    print(data);
                    return Container(
                      margin: EdgeInsets.only(left: 10.0),
                      height: 200,
                      child: ListView(
                        // scrollDirection: Axis.horizontal,
                        children: data.map<Widget>(
                          (data) {
                            return Container(
                              height: 200,
                              child: FutureBuilder(
                                  future: DatabaseService()
                                      .futureSharedTaskData(
                                          member: data.member,
                                          creator: data.creatorId),
                                  builder: (context, AsyncSnapshot snapshot) {
                                    if (!snapshot.hasData) {
                                      return Text("Loading");
                                    } else {
                                      print("working");
                                      List<TaskData> taskData = snapshot.data;
                                      print(taskData);
                                      return ListView(
                                        scrollDirection: Axis.horizontal,
                                        children:
                                            taskData.map<Widget>((docData) {
                                          print(docData);
                                          Color color;
                                          String priority = docData.priority;
                                          if (priority == "Immediate") {
                                            color = Color.fromRGBO(
                                                240, 93, 94, 1.0);
                                          } else if (priority == "High") {
                                            color = Color.fromRGBO(
                                                255, 186, 73, 1.0);
                                          } else if (priority == "Medium") {
                                            color = Color.fromRGBO(
                                                255, 227, 129, 1.0);
                                          } else if (priority == "Low") {
                                            color = Color.fromRGBO(
                                                97, 226, 148, 1.0);
                                          }

                                          return Container(
                                            width: 200,
                                            child: CustomTile(
                                              name: docData.taskName,
                                              description: docData.taskDesc,
                                              status: docData.status,
                                              priority: docData.priority,
                                              color: color,
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    }
                                  }),
                            );
                          },
                        ).toList(),
                      ),
                    );
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
