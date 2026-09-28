import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Shared/Loading.dart';
import '../../Model/FirebaseUser.dart';
import '../../Services/Database.dart';

class ProfileView extends StatefulWidget {
  final user;

  ProfileView({this.user});

  @override
  _ProfileViewState createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  TextEditingController controllerFirstName = TextEditingController();

  TextEditingController controllerLastName = TextEditingController();

  TextEditingController controllerEmail = TextEditingController();

  TextEditingController controllerUserName = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<FirebaseUser>(context);
    final currentUser = widget.user;
    if (currentUser != null) {
      controllerFirstName.text = currentUser.firstName;
      controllerLastName.text = currentUser.lastName;
      controllerEmail.text = currentUser.email;
      controllerUserName.text = currentUser.userName;
    }
    return currentUser == null
        ? Loading()
        : Scaffold(
            appBar: AppBar(
              title: Text("Taskly"),
              elevation: 0.0,
            ),
            body: Container(
              padding: EdgeInsets.symmetric(vertical: 70.0, horizontal: 100.0),
              width: double.infinity,
              height: double.infinity,
              color: Color.fromRGBO(252, 239, 249, 1),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Text(
                      "Profile",
                      style: TextStyle(color: Colors.black, fontSize: 50),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 12.0),
                    width: 250,
                    child: TextField(
                      controller: controllerFirstName,
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
                        labelText: "First Name",
                        labelStyle: Theme.of(context)
                            .textTheme
                            .bodyText1
                            .copyWith(color: Colors.black),
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 12.0),
                    width: 250,
                    child: TextField(
                      controller: controllerLastName,
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
                        labelText: "Last Name",
                        labelStyle: Theme.of(context)
                            .textTheme
                            .bodyText1
                            .copyWith(color: Colors.black),
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 12.0),
                    width: 250,
                    child: TextField(
                      enabled: false,
                      controller: controllerEmail,
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
                        labelText: "Email",
                        labelStyle: Theme.of(context)
                            .textTheme
                            .bodyText1
                            .copyWith(color: Colors.black),
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 12.0),
                    width: 250,
                    child: TextField(
                      enabled: false,
                      controller: controllerUserName,
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
                        labelText: "Username",
                        labelStyle: Theme.of(context)
                            .textTheme
                            .bodyText1
                            .copyWith(color: Colors.black),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10.0,
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                          vertical: 20.0, horizontal: 80.0),
                      primary: Color.fromRGBO(255, 203, 119, 1.0),
                    ),
                    onPressed: () async {
                      await DatabaseService(uid: user.uid).updateUserData(
                        firstName: controllerFirstName.text.toString(),
                        lastName: controllerLastName.text.toString(),
                      );
                      final snackBar = SnackBar(
                        content: Text('User Updated'),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                      Navigator.pop(context);
                    },
                    child:
                        Text("Update", style: TextStyle(color: Colors.black)),
                  )
                ],
              ),
            ),
          );
  }
}
