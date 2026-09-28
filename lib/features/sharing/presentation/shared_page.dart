import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';

class SharedPage extends StatelessWidget {
  const SharedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.group_outlined,
      title: 'Nothing shared with you',
      message: 'Projects other people share with you will appear here.',
    );
  }
}
