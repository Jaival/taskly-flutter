/// What a member may do in a project.
///
/// Here rather than in the projects feature because invites carry a role
/// too, and the projects feature depends on the sharing feature.
enum ProjectRole {
  /// Created the project. Can edit it, manage members and delete it.
  owner('Owner'),

  /// Can edit the project and its tasks.
  editor('Editor'),

  /// Can see the project and update tasks assigned to them.
  viewer('Viewer');

  const ProjectRole(this.label);

  /// Text shown in the UI.
  final String label;

  bool get canEdit => this != viewer;

  /// Parses a stored value. Anything unknown becomes [viewer], the role with
  /// the fewest permissions.
  static ProjectRole fromName(Object? name) =>
      values.asNameMap()[name] ?? viewer;
}
