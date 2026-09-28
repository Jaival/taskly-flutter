import 'package:flutter/material.dart';

import '../../Services/Auth.dart';
import '../../Shared/Loading.dart';

class RightSideLogin extends StatefulWidget {
  @override
  _RightSideLoginState createState() => _RightSideLoginState();
}

class _RightSideLoginState extends State<RightSideLogin> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool loading = false;

  String email = '';
  String password = '';
  String error = '';

  @override
  Widget build(BuildContext context) {
    return loading
        ? Loading()
        : Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                //TODO: Sign In with Google
                //TODO: ----OR----
                // Email
                Container(
                  margin: EdgeInsets.symmetric(vertical: 15.0),
                  width: 300,
                  // color: Colors.yellow,
                  child: TextFormField(
                    style: Theme.of(context).textTheme.bodyText1,
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: "johndoe@email.com",
                      hintStyle: Theme.of(context).textTheme.subtitle2,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      filled: true,
                      fillColor: Color.fromRGBO(196, 196, 196, 0.42),
                      labelText: "Email",
                      labelStyle: Theme.of(context).textTheme.bodyText1,
                    ),
                    validator: (val) => val.isEmpty ? 'Enter an Email' : null,
                    onChanged: (val) {
                      setState(() {
                        email = val;
                      });
                    },
                  ),
                ),
                //Password
                Container(
                  margin: EdgeInsets.symmetric(vertical: 30.0),
                  width: 300,
                  // color: Colors.yellow,
                  child: TextFormField(
                    obscureText: true,
                    style: Theme.of(context).textTheme.bodyText1,
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      filled: true,
                      fillColor: Color.fromRGBO(196, 196, 196, 0.42),
                      labelText: "Password",
                      labelStyle: Theme.of(context).textTheme.bodyText1,
                    ),
                    validator: (val) => val.length < 6
                        ? 'Enter an Password 6+ character long'
                        : null,
                    onChanged: (val) {
                      setState(() {
                        password = val;
                      });
                    },
                  ),
                ),
                // Login Button
                Container(
                  margin: EdgeInsets.symmetric(vertical: 30.0),
                  height: 50,
                  width: 150,
                  // color: Colors.yellow,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        primary: Color.fromRGBO(253, 204, 77, 1.0)),
                    child: Text(
                      "Login",
                      style: Theme.of(context).textTheme.button,
                    ),
                    onPressed: () async {
                      if (_formKey.currentState.validate()) {
                        setState(() {
                          loading = true;
                        });
                        dynamic result = await _authService
                            .signInWithEmailAndPassword(email, password);
                        if (result == null) {
                          setState(() {
                            error =
                                'Entered Username or Password is incorrect.';
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
                                  'It looks like you missed a field or few. ',
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
