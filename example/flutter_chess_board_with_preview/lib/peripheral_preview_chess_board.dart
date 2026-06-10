import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

class UnknownPiece {
  const UnknownPiece({
    required this.file,
    required this.rank,
    required this.symbol,
  });

  final int file;
  final int rank;
  final String symbol;
}

class PeripheralPreviewState {
  const PeripheralPreviewState({
    required this.fen,
    required this.unknownPieces,
    required this.canStartRound,
  });

  const PeripheralPreviewState.empty()
      : fen = null,
        unknownPieces = const [],
        canStartRound = false;

  final String? fen;
  final List<UnknownPiece> unknownPieces;
  final bool canStartRound;
}

bool _isPeripheralPreviewFenGettable(String? fen) {
  return fen != null && !fen.contains(RegExp(r'[?Uu]'));
}

PeripheralPreviewState createPeripheralPreviewState(String fen) {
  final tokens = fen.trim().split(RegExp(r'\s+'));
  final boardFen = tokens.isEmpty ? '8/8/8/8/8/8/8/8' : tokens.first;
  final result = _readPreviewBoardFen(boardFen);
  final completedTokens = [
    result.fen ?? '8/8/8/8/8/8/8/8',
    tokens.length > 1 ? tokens[1] : 'w',
    tokens.length > 2 ? tokens[2] : '-',
    tokens.length > 3 ? tokens[3] : '-',
    tokens.length > 4 ? tokens[4] : '0',
    tokens.length > 5 ? tokens[5] : '1',
  ];
  return PeripheralPreviewState(
    fen: completedTokens.join(' '),
    unknownPieces: result.unknownPieces,
    canStartRound: _isPeripheralPreviewFenGettable(fen),
  );
}

PeripheralPreviewState _readPreviewBoardFen(String boardFen) {
  final rows = boardFen.split('/');
  final normalizedRows = <String>[];
  final unknownPieces = <UnknownPiece>[];

  for (int rowIndex = 0; rowIndex < 8; rowIndex++) {
    final row = rowIndex < rows.length ? rows[rowIndex] : '';
    final buffer = StringBuffer();
    int file = 0;
    int empty = 0;

    void flushEmpty() {
      if (empty > 0) {
        buffer.write(empty);
        empty = 0;
      }
    }

    for (final char in row.characters) {
      if (file >= 8) break;
      final digit = int.tryParse(char);
      if (digit != null) {
        final cappedDigit = min(digit, 8 - file);
        empty += cappedDigit;
        file += cappedDigit;
      } else if (_isKnownFenPiece(char)) {
        flushEmpty();
        buffer.write(char);
        file++;
      } else {
        unknownPieces.add(
          UnknownPiece(
            file: file,
            rank: 8 - rowIndex,
            symbol: _unknownPieceSymbol(char),
          ),
        );
        empty++;
        file++;
      }
    }

    if (file < 8) empty += 8 - file;
    flushEmpty();
    normalizedRows.add(buffer.toString());
  }

  return PeripheralPreviewState(
    fen: normalizedRows.join('/'),
    unknownPieces: unknownPieces,
    canStartRound: false,
  );
}

class PeripheralPreviewChessBoard extends StatelessWidget {
  const PeripheralPreviewChessBoard({
    required this.controller,
    required this.previewState,
    required this.boardColor,
    required this.boardOrientation,
    this.onMove,
    super.key,
  });

  final ChessBoardController controller;
  final PeripheralPreviewState previewState;
  final BoardColor boardColor;
  final PlayerColor boardOrientation;
  final VoidCallback? onMove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = min(constraints.maxWidth, constraints.maxHeight);
        return SizedBox.square(
          dimension: boardSize,
          child: Stack(
            children: [
              ChessBoard(
                controller: controller,
                size: boardSize,
                boardColor: boardColor,
                boardOrientation: boardOrientation,
                onMove: onMove,
              ),
              IgnorePointer(
                child: Stack(
                  children: [
                    for (final piece in previewState.unknownPieces)
                      _UnknownPieceMarker(
                        piece: piece,
                        boardSize: boardSize,
                        boardOrientation: boardOrientation,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PeripheralPreviewDialog extends StatefulWidget {
  const PeripheralPreviewDialog({
    required this.fen,
    required this.roundUpdateStream,
    required this.requestState,
    required this.boardColor,
    required this.boardOrientation,
    super.key,
  });

  final String? Function() fen;
  final Stream<dynamic> roundUpdateStream;
  final Future<void> Function() requestState;
  final BoardColor boardColor;
  final PlayerColor boardOrientation;

  @override
  State<PeripheralPreviewDialog> createState() =>
      _PeripheralPreviewDialogState();
}

class _PeripheralPreviewDialogState extends State<PeripheralPreviewDialog> {
  final ChessBoardController _controller = ChessBoardController();
  PeripheralPreviewState _previewState = const PeripheralPreviewState.empty();
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _applyFen(widget.fen());
    _subscription = widget.roundUpdateStream.listen((_) {
      if (!mounted) return;
      setState(() {
        _applyFen(widget.fen());
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.requestState();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _applyFen(String? fen) {
    if (fen == null) {
      _previewState = const PeripheralPreviewState.empty();
      return;
    }

    final previewState = createPeripheralPreviewState(fen);
    if (previewState.fen != null && Chess().load(previewState.fen!)) {
      _controller.loadFen(previewState.fen!);
      _previewState = previewState;
    } else {
      _previewState = const PeripheralPreviewState.empty();
    }
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
                controller: _controller,
                previewState: _previewState,
                boardColor: widget.boardColor,
                boardOrientation: widget.boardOrientation,
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start'),
          onPressed: _previewState.canStartRound
              ? () => Navigator.of(context).pop(_previewState.fen)
              : null,
        ),
      ],
    );
  }
}

class _UnknownPieceMarker extends StatelessWidget {
  const _UnknownPieceMarker({
    required this.piece,
    required this.boardSize,
    required this.boardOrientation,
  });

  final UnknownPiece piece;
  final double boardSize;
  final PlayerColor boardOrientation;

  @override
  Widget build(BuildContext context) {
    final squareSize = boardSize / 8;
    final column =
        boardOrientation == PlayerColor.white ? piece.file : 7 - piece.file;
    final row =
        boardOrientation == PlayerColor.white ? 8 - piece.rank : piece.rank - 1;
    return Positioned(
      left: column * squareSize,
      top: row * squareSize,
      width: squareSize,
      height: squareSize,
      child: Center(
        child: Container(
          width: squareSize * 0.58,
          height: squareSize * 0.58,
          decoration: BoxDecoration(
            color: _unknownPieceMarkerColor(piece.symbol),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: ui.Color(0x66000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                piece.symbol,
                style: TextStyle(
                  color: piece.symbol == 'B?' ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _isKnownFenPiece(String char) {
  return 'pnbrqkPNBRQK'.contains(char);
}

String _unknownPieceSymbol(String char) {
  return switch (char) {
    'U' => 'W?',
    'u' => 'B?',
    _ => '?',
  };
}

ui.Color _unknownPieceMarkerColor(String symbol) {
  return switch (symbol) {
    'W?' => const ui.Color(0xFFE8E8E8),
    'B?' => const ui.Color(0xFF252525),
    _ => const ui.Color(0xFF5E6675),
  };
}
