import 'package:flutter/material.dart';

class CustomProjectTile extends StatelessWidget {
  final String name;
  final String description;
  final String priority;
  final String status;
  final Color color;
  final Function onTapped;
  final Function iconTapped;
  final bool showEdit;

  CustomProjectTile(
      {this.name,
      this.description,
      this.priority,
      this.status,
      this.onTapped,
      this.color,
      this.showEdit = false,
      this.iconTapped});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      elevation: 3.0,
      child: InkWell(
        onTap: onTapped,
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: 20.0,
            horizontal: 20.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 5.0),
                child: name == null
                    ? Text("No Data")
                    : Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 5.0),
                child: description == null
                    ? Text("No Data")
                    : Text(
                        description,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w300,
                          color: Colors.black,
                        ),
                      ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 5.0),
                child: priority == null
                    ? Text("No Data")
                    : Text(
                        priority,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w100,
                          color: Colors.black,
                        ),
                      ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 5.0),
                child: status == null
                    ? Text("No Data")
                    : Text(
                        status,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w100,
                          color: Colors.black,
                        ),
                      ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(),
                  showEdit == true
                      ? IconButton(
                          tooltip: "Edit Project",
                          hoverColor: null,
                          focusColor: null,
                          iconSize: 20.0,
                          onPressed: showEdit == true ? iconTapped : null,
                          icon: Icon(Icons.create_rounded))
                      : null,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
