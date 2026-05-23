import 'package:flutter/material.dart';

/// Modal bottom sheet showing the full game move list. Moves are rendered
/// in pairs (white | black) per row with the move number on the left,
/// matching the standard scoresheet layout players are used to.
void showMoveHistorySheet(BuildContext context, List<String> notations) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _Sheet(notations: notations),
  );
}

class _Sheet extends StatelessWidget {
  final List<String> notations;
  const _Sheet({required this.notations});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Move history',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (notations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No moves yet.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: (notations.length + 1) ~/ 2,
                  itemBuilder: (ctx, i) {
                    final whiteIdx = i * 2;
                    final blackIdx = whiteIdx + 1;
                    final whiteMove = notations[whiteIdx];
                    final blackMove = blackIdx < notations.length
                        ? notations[blackIdx]
                        : null;
                    return _MoveRow(
                      number: i + 1,
                      whiteMove: whiteMove,
                      blackMove: blackMove,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MoveRow extends StatelessWidget {
  final int number;
  final String whiteMove;
  final String? blackMove;
  const _MoveRow({
    required this.number,
    required this.whiteMove,
    required this.blackMove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$number.',
              style: const TextStyle(
                color: Colors.black54,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              whiteMove,
              style: const TextStyle(
                color: Colors.black,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              blackMove ?? '',
              style: const TextStyle(
                color: Colors.black,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
