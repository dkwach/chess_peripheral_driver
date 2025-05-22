import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';

@immutable
class PeripheralPiece {
  const PeripheralPiece({
    this.color,
    this.role,
    this.promoted = false,
  });

  final Side? color;
  final Role? role;
  final bool promoted;

  PeripheralPiece copyWith({
    Side? color,
    Role? role,
    bool? promoted,
  }) {
    return PeripheralPiece(
      color: color ?? this.color,
      role: role ?? this.role,
      promoted: promoted ?? this.promoted,
    );
  }
}

typedef PeripheralPieces = Map<Square, PeripheralPiece>;

PeripheralPieces readPeripheralFen(String fen) {
  final PeripheralPieces pieces = {};
  int rank = 7;
  int file = 0;
  for (final c in fen.characters) {
    switch (c) {
      case ' ':
      case '[':
        return pieces;
      case '/':
        --rank;
        if (rank < 0) return pieces;
        file = 0;
      case '~':
        final square = Square.fromCoords(File(file - 1), Rank(rank));
        final piece = pieces[square];
        if (piece != null) {
          pieces[square] = piece.copyWith(promoted: true);
        }
      default:
        final code = c.codeUnitAt(0);
        if (code < 57) {
          file += code - 48;
        } else {
          final roleLetter = c.toLowerCase();
          final square = Square.fromCoords(File(file), Rank(rank));
          pieces[square] = PeripheralPiece(
            role: 'wb?'.contains(roleLetter) ? null : _roles[roleLetter]!,
            color: roleLetter == '?'
                ? null
                : roleLetter == 'w'
                    ? Side.white
                    : c == roleLetter
                        ? Side.black
                        : Side.white,
          );
          ++file;
        }
    }
  }
  return pieces;
}

const _roles = {
  'p': Role.pawn,
  'r': Role.rook,
  'n': Role.knight,
  'b': Role.bishop,
  'q': Role.queen,
  'k': Role.king,
};
