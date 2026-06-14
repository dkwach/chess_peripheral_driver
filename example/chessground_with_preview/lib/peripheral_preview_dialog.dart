import 'dart:async';
import 'dart:math';

import 'package:ble_chess_peripheral_driver/chess_peripheral_driver.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'peripheral_fen.dart';

class PeripheralPreviewDialog extends StatefulWidget {
  const PeripheralPreviewDialog({
    required this.peripheral,
    super.key,
  });

  final Peripheral peripheral;

  @override
  State<PeripheralPreviewDialog> createState() =>
      PeripheralPreviewDialogState();
}

class PeripheralPreviewDialogState extends State<PeripheralPreviewDialog> {
  PeripheralPreviewState _previewState = const PeripheralPreviewState.empty();
  StreamSubscription? _subscription;

  String? get _peripheralFen => widget.peripheral.round.fen;

  @override
  void initState() {
    super.initState();
    _previewState = _createPeripheralPreviewState(_peripheralFen);
    _subscription = widget.peripheral.roundUpdateStream.listen((_) {
      if (!mounted) return;
      setState(() {
        _previewState = _createPeripheralPreviewState(_peripheralFen);
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  PeripheralPreviewState _createPeripheralPreviewState(String? fen) {
    if (fen == null) {
      return const PeripheralPreviewState.empty();
    }

    if (isPeripheralFenGettable(fen) && _isValidFen(fen)) {
      return PeripheralPreviewState.known(fen: fen);
    }

    IMap<Square, Annotation> annotations = IMap();

    readPeripheralFen(fen).forEach((square, piece) {
      annotations = annotations.add(
        square,
        Annotation(
          symbol: _createUnknownPieceSymbol(piece),
          color: _createUnknownPieceColor(piece),
        ),
      );
    });

    return PeripheralPreviewState.unknown(annotations: annotations);
  }

  bool _isValidFen(String fen) {
    try {
      Chess.fromSetup(Setup.parseFen(fen));
      return true;
    } catch (_) {
      return false;
    }
  }

  String _createUnknownPieceSymbol(PeripheralPiece piece) {
    return switch (piece.color) {
      Side.white => 'W?',
      Side.black => 'B?',
      null => '?',
    };
  }

  Color _createUnknownPieceColor(PeripheralPiece piece) {
    return switch (piece.color) {
      Side.white => const Color(0xFF607D8B),
      Side.black => const Color(0xFF242424),
      null => const Color(0xFF5E6675),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Preview'),
      content: SizedBox.square(
        dimension: 280,
        child: _previewState.fen == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  return Chessboard.fixed(
                    size: min(constraints.maxWidth, constraints.maxHeight),
                    orientation: Side.white,
                    fen: _previewState.fen!,
                    annotations: _previewState.annotations,
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Begin Round'),
          onPressed: _previewState.canBeginRound
              ? () => Navigator.of(context).pop(_previewState.fen)
              : null,
        ),
      ],
    );
  }
}

class PeripheralPreviewState {
  const PeripheralPreviewState({
    required this.fen,
    required this.annotations,
    required this.canBeginRound,
  });

  const PeripheralPreviewState.empty()
      : fen = null,
        annotations = const IMapConst({}),
        canBeginRound = false;

  const PeripheralPreviewState.known({
    required String fen,
  })  : fen = fen,
        annotations = const IMapConst({}),
        canBeginRound = true;

  PeripheralPreviewState.unknown({
    required IMap<Square, Annotation> annotations,
  })  : fen = writeFen(Pieces()),
        annotations = annotations,
        canBeginRound = false;

  final String? fen;
  final IMap<Square, Annotation> annotations;
  final bool canBeginRound;
}
