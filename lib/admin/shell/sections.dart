import 'package:flutter/material.dart';

/// The panel's sections, in navigation order. Screens link to each other by
/// these rather than by index, so reordering the rail cannot break a link.
enum AdminSection {
  overview('Overview', Icons.space_dashboard_outlined),
  reports('Reports', Icons.flag_outlined),
  courses('Courses', Icons.video_library_outlined),
  users('Users', Icons.people_outline),
  refunds('Refunds', Icons.undo),
  payouts('Payouts', Icons.payments_outlined),
  categories('Categories', Icons.category_outlined),
  auditLog('Audit log', Icons.history);

  const AdminSection(this.label, this.icon);

  final String label;
  final IconData icon;
}
