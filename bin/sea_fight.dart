import 'dart:io';
import 'dart:math';

class Ship {
  String name;
  int size;
  List<(int row, int col)> positions;
  int hits = 0;
  bool get isSunk => hits == size;
  Ship(this.name, this.size, this.positions);
}

class Player {
  String name;
  int size;
  Set<(int row, int col)> occupied = {};
  Map<(int row, int col), bool> hits = {};
  Map<(int row, int col), String> marks = {};
  List<Ship> ships = [];
  bool isBot;
  Player(this.name, this.size, {this.isBot = false});

  bool HitVerif((int row, int col) pos) {
    if (hits.containsKey(pos)) return false;
    hits[pos] = true;
    bool wasShip = occupied.contains(pos);
    if (wasShip) {
      for (var ship in ships) {
        if (ship.positions.contains(pos)) {
          ship.hits++;
          break;
        }
      }
    }
    return wasShip;
  }

  bool get allSunk => ships.every((s) => s.isSunk);

  bool canPlace((int row, int col) start, bool horizontal, int shipSize) {
    var r = start.$1;
    var c = start.$2;
    for (var i = 0; i < shipSize; i++) {
      if (r < 0 || r >= size || c < 0 || c >= size || occupied.contains((r, c))) return false;
      horizontal ? c++ : r++;
    }
    return true;
  }

  void placeShip(String name, int shipSize, (int row, int col) start, bool horizontal) {
    var positions = <(int row, int col)>[];
    var r = start.$1;
    var c = start.$2;
    for (var i = 0; i < shipSize; i++) {
      positions.add((r, c));
      horizontal ? c++ : r++;
    }
    var ship = Ship(name, shipSize, positions);
    ships.add(ship);
    occupied.addAll(positions);
  }

  void setMark((int row, int col) pos, String mark) => marks[pos] = mark;

  bool isAttacked((int row, int col) pos) => marks.containsKey(pos);

  String DisplayyourShip() {
    var sb = StringBuffer();
    var cols = List.generate(size, (i) => String.fromCharCode('A'.codeUnitAt(0) + i));
    sb.write('   ');
    for (var col in cols) {
      sb.write('$col ');
    }
    sb.writeln();
    for (var r = 0; r < size; r++) {
      sb.write(r + 1 < 10 ? ' ${r + 1} ' : '${r + 1} ');
      for (var c = 0; c < size; c++) {
        var p = (r, c);
        var h = hits[p] ?? false;
        if (h) {
          var isSunk = ships.any((ship) => ship.positions.contains(p) && ship.isSunk);
          sb.write(isSunk ? 'X ' : 'П ');
        } else if (occupied.contains(p)) {
          sb.write('К ');
        } else {
          sb.write('. ');
        }
      }
      sb.writeln();
    }
    return sb.toString();
  }

  String DisplayOpponentShip() {
    var sb = StringBuffer();
    var cols = List.generate(size, (i) => String.fromCharCode('A'.codeUnitAt(0) + i));
    sb.write('   ');
    for (var col in cols) {
      sb.write('$col ');
    }
    sb.writeln();
    for (var r = 0; r < size; r++) {
      sb.write(r + 1 < 10 ? ' ${r + 1} ' : '${r + 1} ');
      for (var c = 0; c < size; c++) {
        var p = (r, c);
        sb.write('${marks[p] ?? '.'} ');
      }
      sb.writeln();
    }
    return sb.toString();
  }
}

(int row, int col)? parsePosition(String? s, int sz) {
  if (s == null || s.length < 2) return null;
  s = s.toUpperCase();
  var col = s[0].codeUnitAt(0) - 'A'.codeUnitAt(0);
  if (col < 0 || col >= sz) return null;
  var row = int.tryParse(s.substring(1)) ?? 0;
  row -= 1;
  if (row < 0 || row >= sz) return null;
  return (row, col);
}

String posToString((int row, int col) p) => '${String.fromCharCode('A'.codeUnitAt(0) + p.$2)}${p.$1 + 1}';

void clearScreen() => stdout.write('\x1B[2J\x1B[0;0H');

String askName(String prompt) {
  stdout.write(prompt);
  var name = stdin.readLineSync()?.trim() ?? 'Игрок';
  return name.isEmpty ? 'Игрок' : name;
}

Map<String, int> getShipConfig(int sz) {
  if (sz == 6) return {'Подлодка': 1, 'Эсминец': 2, 'Крейсер': 1};
  if (sz == 10) return {'Подлодка': 4, 'Эсминец': 3, 'Крейсер': 2, 'Линкор': 1};
  if (sz == 14) return {'Подлодка': 4, 'Эсминец': 3, 'Крейсер': 3, 'Линкор': 2, 'Авианосец': 1};
  throw Exception('Недопустимый размер');
}

Map<String, int> getSizeOf() => {
      'Подлодка': 1,
      'Эсминец': 2,
      'Крейсер': 3,
      'Линкор': 4,
      'Авианосец': 5,
    };

void humanPlace(Player player, Map<String, int> config, Map<String, int> sizeOf) {
  for (var type in config.keys) {
    var count = config[type]!;
    var sSize = sizeOf[type]!;
    for (var i = 0; i < count; i++) {
      var placed = false;
      while (!placed) {
        print(player.DisplayyourShip());
        stdout.write('Разместите $type (размер $sSize): например, A1 H (или V): ');
        var line = stdin.readLineSync();
        if (line == null) continue;
        var parts = line.split(RegExp(r'\s+'));
        if (parts.length != 2) {
          print('Неверный формат. Используйте A1 H');
          continue;
        }
        var start = parsePosition(parts[0], player.size);
        if (start == null) {
          print('Недопустимая позиция.');
          continue;
        }
        var horizontal = parts[1].toUpperCase() == 'H';
        if (parts[1].toUpperCase() != 'H' && parts[1].toUpperCase() != 'V') {
          print('Направление должно быть H или V');
          continue;
        }
        if (player.canPlace(start, horizontal, sSize)) {
          player.placeShip(type, sSize, start, horizontal);
          placed = true;
          print('Корабль размещён!');
        } else {
          print('Нельзя разместить: за пределами поля или пересечение.');
        }
      }
    }
  }
}

void botPlace(Player player, Map<String, int> config, Map<String, int> sizeOf) {
  var rand = Random();
  for (var type in config.keys) {
    var count = config[type]!;
    var sSize = sizeOf[type]!;
    for (var i = 0; i < count; i++) {
      var placed = false;
      while (!placed) {
        var horizontal = rand.nextBool();
        var startR = horizontal ? rand.nextInt(player.size) : rand.nextInt(player.size - sSize + 1);
        var startC = horizontal ? rand.nextInt(player.size - sSize + 1) : rand.nextInt(player.size);
        var start = (startR, startC);
        if (player.canPlace(start, horizontal, sSize)) {
          player.placeShip(type, sSize, start, horizontal);
          placed = true;
        }
      }
    }
  }
}

(int row, int col) getBotAttack(Player player) {
  var rand = Random();
  var avail = <(int row, int col)>[];
  for (var r = 0; r < player.size; r++) {
    for (var c = 0; c < player.size; c++) {
      var p = (r, c);
      if (!player.isAttacked(p)) avail.add(p);
    }
  }
  return avail[rand.nextInt(avail.length)];
}

(int row, int col) getHumanAttack(Player player) {
  while (true) {
    stdout.write('Атака (например, A1): ');
    var pos = parsePosition(stdin.readLineSync(), player.size);
    if (pos != null && !player.isAttacked(pos)) {
      return pos;
    }
    print('Недопустимая или уже атакованная клетка.');
  }
}

void playGame() {
  print('Добро пожаловать в Морской бой!');
  stdout.write('Режим: 1 - Игрок против игрока, 2 - Игрок против бота: ');
  var mode = int.tryParse(stdin.readLineSync() ?? '1') ?? 1;
  stdout.write('Размер поля: 1 - 6x6, 2 - 10x10, 3 - 14x14: ');
  var choice = int.tryParse(stdin.readLineSync() ?? '2') ?? 2;
  var size = [6, 10, 14][choice - 1];
  var config = getShipConfig(size);
  var sizeOf = getSizeOf();

  var p1 = Player(askName(mode == 1 ? 'Имя первого игрока: ' : 'Ваше имя: '), size);
  var p2 = mode == 1
      ? Player(askName('Имя второго игрока: '), size)
      : Player('Компьютер', size, isBot: true);

  print('Игра начинается!');
  if (mode == 1) {
    stdout.write('Нажмите Enter для размещения кораблей...');
    stdin.readLineSync();
  }
  clearScreen();

  print('${p1.name}, разместите свои корабли:');
  humanPlace(p1, config, sizeOf);
  if (mode == 1) {
    print('Теперь ${p2.name} будет размещать свои корабли.');
    stdout.write('Нажмите Enter для продолжения...');
    stdin.readLineSync();
    clearScreen();
    print('${p2.name}, разместите свои корабли:');
    humanPlace(p2, config, sizeOf);
    print('Оба игрока разместили свои корабли. Начинаем игру!');
    stdout.write('Нажмите Enter для продолжения...');
    stdin.readLineSync();
  } else {
    print('Теперь компьютер размещает свои корабли.');
    clearScreen();
    print('Компьютер размещает корабли...');
    botPlace(p2, config, sizeOf);
  }
  clearScreen();

  var p1Turn = true;
  Player? winner;
  while (winner == null) {
    var current = p1Turn ? p1 : p2;
    var opponent = p1Turn ? p2 : p1;
    print('\nХодит ${current.name}');
    (int row, int col) pos;
    if (current.isBot) {
      pos = getBotAttack(current);
      var isHit = opponent.HitVerif(pos);
      var mark = isHit ? 'П' : 'М';
      if (isHit && opponent.ships.any((ship) => ship.positions.contains(pos) && ship.isSunk)) {
        mark = 'X';
        for (var p in opponent.ships.firstWhere((ship) => ship.positions.contains(pos)).positions) {
          current.setMark(p, 'X');
        }
      } else {
        current.setMark(pos, mark);
      }
      var msg = 'Компьютер атакует ${posToString(pos)} - ${isHit ? 'Попал!' : 'Промах!'}${mark == 'X' ? ' Потоплен ${opponent.ships.firstWhere((ship) => ship.positions.contains(pos)).name}!' : ''}';
      print(msg);
    } else {
      print('Ваш флот:');
      print(current.DisplayyourShip());
      print('\nПоле противника:');
      print(current.DisplayOpponentShip());
      pos = getHumanAttack(current);
      var isHit = opponent.HitVerif(pos);
      var mark = isHit ? 'П' : 'М';
      if (isHit && opponent.ships.any((ship) => ship.positions.contains(pos) && ship.isSunk)) {
        mark = 'X';
        for (var p in opponent.ships.firstWhere((ship) => ship.positions.contains(pos)).positions) {
          current.setMark(p, 'X');
        }
      } else {
        current.setMark(pos, mark);
      }
      var msg = isHit ? 'Попал!' : 'Промах!';
      if (mark == 'X') msg += ' Потоплен ${opponent.ships.firstWhere((ship) => ship.positions.contains(pos)).name}!';
      print(msg);
    }
    if (opponent.allSunk) winner = current;
    p1Turn = !p1Turn;
    if (winner == null) {
      print('Теперь ходит ${p1Turn ? p1.name : p2.name}...');
      if (mode == 1) {
        stdout.write('Нажмите Enter для продолжения...');
        stdin.readLineSync();
      }
      clearScreen();
    }
  }
  print('${winner.name} побеждает в игре!');
}

void main() {
  var playAgain = true;
  while (playAgain) {
    playGame();
    stdout.write('Играть снова? (y/n): ');
    var response = stdin.readLineSync()?.toLowerCase() ?? 'n';
    playAgain = response == 'y';
  }
}
