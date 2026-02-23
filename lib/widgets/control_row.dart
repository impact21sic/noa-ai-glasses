import 'package:flutter/material.dart';

class ControlRow extends StatelessWidget {
  final String emoji;
  final String tapDescription;
  final String actionDescription;

  const ControlRow({
    super.key,
    required this.emoji,
    required this.tapDescription,
    required this.actionDescription,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tapDescription,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                actionDescription,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
