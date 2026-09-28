import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Model/UserData.dart';
import '../Model/ProjectModel.dart';
import '../Model/TaskModel.dart';
import '../Model/FirebaseUser.dart';
import '../Services/Database.dart';
import '../Widgets/Home/Home_Right.dart';
import '../Services/Auth.dart';
import '../Widgets/Home/Home_Left.dart';

class Home extends StatelessWidget {
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();
    double width = MediaQuery.of(context).size.width;
    final user = Provider.of<FirebaseUser>(context);

    return MultiProvider(
      providers: [
        StreamProvider<List<TaskData>>.value(
          initialData: null,
          value: DatabaseService(uid: user.uid).streamTaskData(),
        ),
        StreamProvider<List<ProjectData>>.value(
          initialData: null,
          value: DatabaseService(uid: user.uid).streamProjectData(),
        ),
        StreamProvider<UserData>.value(
          initialData: null,
          value: DatabaseService(uid: user.uid).streamUserData(),
        )
      ],
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text("Taskly"),
          elevation: 0.0,
          actions: [
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.all(20.0)),
              onPressed: () async {
                await _authService.signOut();
              },
              icon: Icon(
                Icons.logout,
                color: Colors.white,
              ),
              label: Text(
                "Logout",
                style: TextStyle(color: Colors.white),
              ),
            )
          ],
        ),
        body: Row(
          children: [
            // Left Side
            HomeLeftDashboard(
              width: width,
            ),
            // Right Side
            HomeRightDashboard(
              width: width,
            ),
          ],
        ),
      ),
    );
  }
}
