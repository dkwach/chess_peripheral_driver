class Features {
  static const getState = 'get_state';
  static const setState = 'set_state';
  static const stateStream = 'state_stream';
  static const lastMove = 'last_move';
  static const check = 'check';
  static const moved = 'moved';
  static const msg = 'msg';
  static const resign = 'resign';
  static const undo = 'undo';
  static const undoOffer = 'undo_offer';
  static const drawOffer = 'draw_offer';
  static const side = 'side';
  static const time = 'time';
  static const score = 'score';
  static const option = 'option';
  static const drawReason = 'draw_reason';
  static const variantReason = 'variant_reason';
}

class Variants {
  static const standard = 'standard';
  static const chess960 = 'chess_960';
  static const threeCheck = '3_check';
  static const atomic = 'atomic';
  static const kingOfTheHill = 'king_of_the_hill';
  static const antiChess = 'anti_chess';
  static const horde = 'horde';
  static const racingKings = 'racing_kings';
  static const crazyHouse = 'crazy_house';
}

class Commands {
  static const ok = 'ok';
  static const nok = 'nok';
  static const feature = 'feature';
  static const variant = 'variant';
  static const setVariant = 'set_variant';
  static const begin = 'begin';
  static const state = 'state';
  static const sync = 'sync';
  static const unsync = 'unsync';
  static const move = 'move';
  static const end = 'end';
  static const promote = 'promote';
  static const err = 'err';
  static const drop = 'drop';
  static const getState = Features.getState;
  static const setState = Features.setState;
  static const unsyncSettable = 'unsync_settable';
  static const lastMove = Features.lastMove;
  static const check = Features.check;
  static const moved = Features.moved;
  static const msg = Features.msg;
  static const resign = Features.resign;
  static const undo = Features.undo;
  static const undoOffer = Features.undoOffer;
  static const drawOffer = Features.drawOffer;
  static const side = Features.side;
  static const time = Features.time;
  static const score = Features.score;
  static const optionsBegin = 'options_begin';
  static const option = Features.option;
  static const optionsEnd = 'options_end';
  static const optionsReset = 'options_reset';
  static const setOption = 'set_option';
}

class EndReasons {
  static const undefined = 'undefined';
  static const checkmate = 'checkmate';
  static const draw = 'draw';
  static const timeout = 'timeout';
  static const resign = 'resign';
  static const abort = 'abort';
}

class Sides {
  static const white = 'w';
  static const black = 'b';
  static const both = '?';
}

class DrawReasons {
  static const drawOffer = Features.drawOffer;
  static const stalemate = 'stalemate';
  static const threefoldRepetition = 'threefold_repetition';
  static const fiftyMove = 'fifty_move';
  static const insufficientMaterial = 'insufficient_material';
  static const deadPosition = 'dead_position';
}

class VariantReasons {
  static const threeCheck = Variants.threeCheck;
  static const kingOfTheHill = Variants.kingOfTheHill;
}

class OptionTypes {
  static const bool = 'bool';
  static const enu = 'enum';
  static const str = 'str';
  static const int = 'int';
  static const float = 'float';
}
