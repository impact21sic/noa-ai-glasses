import 'package:flutter/material.dart';

class StatusCard extends StatefulWidget {
  final bool isConnected;
  final String status;
  final bool isLoading;
  final String lastResponse;

  const StatusCard({
    super.key,
    required this.isConnected,
    required this.status,
    required this.isLoading,
    required this.lastResponse,
  });

  @override
  State<StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<StatusCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: widget.isConnected ? const Color.fromRGBO(76, 175, 80, 1) : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.status,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                if (widget.isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (widget.lastResponse.isNotEmpty) ...[
              const Divider(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Последен отговор:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ],
                ),
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(widget.lastResponse),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
