import 'package:flutter/material.dart';

import '../../Services/Auth.dart';
import '../../Shared/Loading.dart';

class RightSideSignUp extends StatefulWidget {
  @override
  _RightSideSignUpState createState() => _RightSideSignUpState();
}

class _RightSideSignUpState extends State<RightSideSignUp> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool loading = false;

  String email = '';
  String password = '';
  String firstName = '';
  String lastName = '';
  String userName = '';
  String error = '';

  @override
  Widget build(BuildContext context) {
    return loading
        ? Loading()
        : Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              // crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //TODO: Sign In with Google
                //TODO: ----OR----
                // Name
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // First Name
                    Container(
                      margin: EdgeInsets.symmetric(
                          vertical: 15.0, horizontal: 15.0),
                      width: 250,
                      // color: Colors.yellow,
                      child: TextFormField(
                        style: Theme.of(context).textTheme.bodyText1,
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          hintText: "John",
                          hintStyle: Theme.of(context)
                              .textTheme
                              .subtitle2
                              .copyWith(fontSize: 12.0),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          filled: true,
                          fillColor: Color.fromRGBO(196, 196, 196, 0.42),
                          labelText: "First Name",
                          labelStyle: Theme.of(context)
                              .textTheme
                              .bodyText2
                              .copyWith(letterSpacing: 1.1),
                        ),
                        validator: (val) =>
                            val.isEmpty ? 'Enter a First Name' : null,
                        onChanged: (val) {
                          setState(() {
                            firstName = val;
                          });
                        },
                      ),
                    ),
                    // Last Name
                    Container(
                      margin: EdgeInsets.symmetric(
                          vertical: 15.0, horizontal: 15.0),
                      width: 250,
                      // color: Colors.yellow,
                      child: TextFormField(
                        style: Theme.of(context).textTheme.bodyText1,
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          hintText: "Doe",
                          hintStyle: Theme.of(context)
                              .textTheme
                              .subtitle2
                              .copyWith(fontSize: 12.0),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          filled: true,
                          fillColor: Color.fromRGBO(196, 196, 196, 0.42),
                          labelText: "Last Name",
                          labelStyle: Theme.of(context)
                              .textTheme
                              .bodyText2
                              .copyWith(letterSpacing: 1.1),
                        ),
                        validator: (val) =>
                            val.isEmpty ? 'Enter an Last Name' : null,
                        onChanged: (val) {
                          setState(() {
                            lastName = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // Email
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Username
                    Container(
                      margin: EdgeInsets.symmetric(
                          vertical: 15.0, horizontal: 15.0),
                      width: 250,
                      child: TextFormField(
                        style: Theme.of(context).textTheme.bodyText1,
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          hintText: "Johndoe",
                          hintStyle: Theme.of(context)
                              .textTheme
                              .subtitle2
                              .copyWith(fontSize: 12.0),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          filled: true,
                          fillColor: Color.fromRGBO(196, 196, 196, 0.42),
                          labelText: "Username",
                          labelStyle: Theme.of(context)
                              .textTheme
                              .bodyText2
                              .copyWith(letterSpacing: 1.1),
                        ),
                        validator: (val) =>
                            val.isEmpty ? 'Enter a Username' : null,
                        onChanged: (val) {
                          setState(() {
                            userName = val;
                          });
                        },
                      ),
                    ),
                    // Email
                    Container(
                      margin: EdgeInsets.symmetric(
                          vertical: 15.0, horizontal: 15.0),
                      width: 250,
                      child: TextFormField(
                        style: Theme.of(context).textTheme.bodyText1,
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          hintText: "johndoe@email.com",
                          hintStyle: Theme.of(context)
                              .textTheme
                              .subtitle2
                              .copyWith(fontSize: 12.0),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          filled: true,
                          fillColor: Color.fromRGBO(196, 196, 196, 0.42),
                          labelText: "Email",
                          labelStyle: Theme.of(context)
                              .textTheme
                              .bodyText2
                              .copyWith(letterSpacing: 1.1),
                        ),
                        validator: (val) =>
                            val.isEmpty ? 'Enter an Email' : null,
                        onChanged: (val) {
                          setState(() {
                            email = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // Container(
                //   margin: EdgeInsets.symmetric(vertical: 15.0),
                //   width: 250,
                //   // color: Colors.yellow,
                //   child: TextFormField(
                //     style: Theme.of(context).textTheme.bodyText1,
                //     cursorColor: Colors.white,
                //     decoration: InputDecoration(
                //       hintText: "johndoe@email.com",
                //       hintStyle: Theme.of(context).textTheme.subtitle2,
                //       border: InputBorder.none,
                //       enabledBorder: InputBorder.none,
                //       filled: true,
                //       fillColor: Color.fromRGBO(196, 196, 196, 0.42),
                //       labelText: "Email",
                //       labelStyle: Theme.of(context).textTheme.bodyText2,
                //     ),
                //     validator: (val) => val.isEmpty ? 'Enter an Email' : null,
                //     onChanged: (val) {
                //       setState(() {
                //         email = val;
                //       });
                //     },
                //   ),
                // ),
                // Password
                Container(
                  margin:
                      EdgeInsets.symmetric(vertical: 15.0, horizontal: 15.0),
                  width: 250,
                  // color: Colors.yellow,
                  child: TextFormField(
                    style: Theme.of(context).textTheme.bodyText1,
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: "********",
                      hintStyle: Theme.of(context)
                          .textTheme
                          .subtitle2
                          .copyWith(fontSize: 12.0),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      filled: true,
                      fillColor: Color.fromRGBO(196, 196, 196, 0.42),
                      labelText: "Password",
                      labelStyle: Theme.of(context)
                          .textTheme
                          .bodyText2
                          .copyWith(letterSpacing: 1.1),
                    ),
                    validator: (val) => val.length < 6
                        ? 'Enter an Password 6+ character long'
                        : null,
                    obscureText: true,
                    onChanged: (val) {
                      setState(() {
                        password = val;
                      });
                    },
                  ),
                ),
                // Sign Up Button
                Container(
                  margin: EdgeInsets.symmetric(vertical: 15.0),
                  height: 50,
                  width: 150,
                  // color: Colors.yellow,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        primary: Color.fromRGBO(253, 204, 77, 1.0)),
                    child: Text(
                      "Sign Up",
                      style: Theme.of(context).textTheme.button,
                    ),
                    onPressed: () async {
                      if (_formKey.currentState.validate()) {
                        setState(() {
                          loading = true;
                        });
                        dynamic result =
                            await _authService.registerWithEmailAndPassword(
                                email: email,
                                password: password,
                                firstName: firstName,
                                lastName: lastName,
                                userName: userName);
                        if (result == null) {
                          setState(() {
                            error =
                                'Something went wrong. Please try again after some time';
                            loading = false;
                          });
                          return showDialog<void>(
                            context: context,
                            barrierDismissible: false, // user must tap button!
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(error,
                                    style: TextStyle(color: Colors.black)),
                                actions: <Widget>[
                                  TextButton(
                                    child: Text('Okay'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      } else {
                        return showDialog<void>(
                          context: context,
                          barrierDismissible: false, // user must tap button!
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text(
                                  'It looks like you missed a field or few.',
                                  style: TextStyle(color: Colors.black)),
                              actions: <Widget>[
                                TextButton(
                                  child: Text('Okay'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          );
  }
}
