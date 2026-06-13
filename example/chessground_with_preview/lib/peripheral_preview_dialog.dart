import 'dart:async';
import 'dart:math';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';

import 'peripheral_fen.dart';

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

  final String? fen;
  final IMap<Square, Annotation> annotations;
  final bool canBeginRound;
}

PeripheralPreviewState createPeripheralPreviewState(String fen) {
  final result = _createPreviewBoard(readPeripheralFen(fen));

  return PeripheralPreviewState(
    fen: result.boardFen,
    annotations: result.annotations,
    canBeginRound:
        isPeripheralFenGettable(fen) && _isValidPositionFen(result.boardFen),
  );
}

bool _isValidPositionFen(String fen) {
  try {
    Chess.fromSetup(Setup.parseFen(fen));
    return true;
  } catch (_) {
    return false;
  }
}

_PreviewBoardFenResult _createPreviewBoard(PeripheralPieces peripheralPieces) {
  final Pieces pieces = {};
  IMap<Square, Annotation> annotations = IMap();

  for (final entry in peripheralPieces.entries) {
    final square = entry.key;
    final peripheralPiece = entry.value;
    final role = peripheralPiece.role;
    final color = peripheralPiece.color;

    if (role != null && color != null) {
      pieces[square] = Piece(
        role: role,
        color: color,
        promoted: peripheralPiece.promoted,
      );
    } else {
      annotations = annotations.add(
        square,
        Annotation(
          symbol: _unknownPieceSymbol(peripheralPiece),
          color: _unknownPieceMarkerColor(peripheralPiece),
        ),
      );
    }
  }

  return _PreviewBoardFenResult(
    boardFen: writeFen(pieces),
    annotations: annotations,
  );
}

class PeripheralPreviewChessBoard extends StatelessWidget {
  const PeripheralPreviewChessBoard({
    required this.previewState,
    required this.orientation,
    super.key,
  });

  final PeripheralPreviewState previewState;
  final Side orientation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = min(constraints.maxWidth, constraints.maxHeight);
        return Chessboard.fixed(
          size: boardSize,
          orientation: orientation,
          fen: previewState.fen!,
          annotations: previewState.annotations,
        );
      },
    );
  }
}

class PeripheralPreviewDialog extends StatefulWidget {
  const PeripheralPreviewDialog({
    required this.fenStream,
    required this.orientation,
    super.key,
  });

  final Stream<String> fenStream;
  final Side orientation;

  @override
  State<PeripheralPreviewDialog> createState() =>
      _PeripheralPreviewDialogState();
}

class _PeripheralPreviewDialogState extends State<PeripheralPreviewDialog> {
  PeripheralPreviewState _previewState = const PeripheralPreviewState.empty();
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.fenStream.listen((fen) {
      if (!mounted) return;
      setState(() {
        _previewState = createPeripheralPreviewState(fen);
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Preview'),
      content: SizedBox.square(
        dimension: 280,
        child: _previewState.fen == null
            ? const Center(child: CircularProgressIndicator())
            : PeripheralPreviewChessBoard(
                previewState: _previewState,
                orientation: widget.orientation,
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

class _PreviewBoardFenResult {
  const _PreviewBoardFenResult({
    required this.boardFen,
    required this.annotations,
  });

  final String boardFen;
  final IMap<Square, Annotation> annotations;
}

String _unknownPieceSymbol(PeripheralPiece piece) {
  return switch (piece.color) {
    Side.white => 'W?',
    Side.black => 'B?',
    null => '?',
  };
}

Color _unknownPieceMarkerColor(PeripheralPiece piece) {
  return switch (piece.color) {
    Side.white => const Color(0xFF607D8B),
    Side.black => const Color(0xFF242424),
    null => const Color(0xFF5E6675),
  };
}
