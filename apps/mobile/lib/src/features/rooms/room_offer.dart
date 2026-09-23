import 'package:aura_domain/aura_domain.dart';
import 'package:flutter/widgets.dart';

/// "Join a room of people feeling this" in the check-in saved moment
/// (F5 REQ-ROOM-01). Renders nothing until the rooms feature lands.
class RoomOfferButton extends StatelessWidget {
  const RoomOfferButton({super.key, required this.quadrant});

  final Quadrant quadrant;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
