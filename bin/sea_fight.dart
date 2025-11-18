import 'dart:io';
import 'dart:convert'; 
import 'dart:async';
import 'dart:isolate';
import 'dart:math';

class PlayerStats {
  String name;
  int gamesPlayed = 0;
  int wins = 0;
  int losses = 0;
  
  PlayerStats(this.name);
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'gamesPlayed': gamesPlayed,
    'wins': wins,
    'losses': losses,
  };
  
  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    var stats = PlayerStats(json['name']);
    stats.gamesPlayed = json['gamesPlayed'] ?? 0;
    stats.wins = json['wins'] ?? 0;
    stats.losses = json['losses'] ?? 0;
    return stats;
  }
}

class GameData {
  String playerName;
  int hits = 0;
  int misses = 0;
  Map<String, String> shipStatus = {}; 
  
  GameData(this.playerName);
  
  Map<String, dynamic> toJson() => {
    'playerName': playerName,
    'hits': hits,
    'misses': misses,
    'shipStatus': shipStatus,
  };
  
  void updateShipStatus(List<Ship> ships) {
    shipStatus.clear();
    
    var shipCounts = <String, int>{};
    
    for (var ship in ships) {
      var count = shipCounts[ship.name] ?? 0;
      shipCounts[ship.name] = count + 1;
      
      var shipKey = count == 0 ? ship.name : '${ship.name}_${count + 1}';
      
      if (ship.isSunk) {
        shipStatus[shipKey] = 'потоплен';
      } else if (ship.hits > 0) {
        shipStatus[shipKey] = 'подбит';
      } else {
        shipStatus[shipKey] = 'цел';
      }
    }
  }
  
  String getStatsSummary() {
    var intactCount = shipStatus.values.where((status) => status == 'цел').length;
    var damagedCount = shipStatus.values.where((status) => status == 'подбит').length;
    var sunkCount = shipStatus.values.where((status) => status == 'потоплен').length;
    
    return '$playerName: $hits попаданий, $misses промахов, $intactCount кораблей целы, $damagedCount подбито, $sunkCount потоплено';
  }
}

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

Future<void> logToFile(String message) async {
  try {
    final file = File('game_log.txt');
    final timestamp = DateTime.now().toString();
    final logMessage = '$timestamp: $message\n';
    await file.writeAsString(logMessage, mode: FileMode.append);
  } catch (e) {
    print('Ошибка записи в лог: $e');
  }
}

Future<PlayerStats?> loadPlayerStats(String name) async {
  try {
    final file = File('${name}_stats.json');
    if (await file.exists()) {
      final contents = await file.readAsString();
      final json = jsonDecode(contents);
      return PlayerStats.fromJson(json);
    }
  } catch (e) {
    await logToFile('ОШИБКА СИСТЕМЫ: Ошибка загрузки статистики для $name: $e');
  }
  return null;
}

Future<void> savePlayerStats(PlayerStats stats) async {
  try {
    final file = File('${stats.name}_stats.json');
    final jsonString = jsonEncode(stats.toJson());
    await file.writeAsString(jsonString);
    await logToFile('Сохранена статистика игрока: ${stats.name}');
  } catch (e) {
    await logToFile('ОШИБКА СИСТЕМЫ: Ошибка сохранения статистики для ${stats.name}: $e');
  }
}

Future<void> saveGameData(GameData gameData) async {
  try {
    final file = File('current_game.json');
    final jsonString = jsonEncode(gameData.toJson());
    await file.writeAsString(jsonString);
  } catch (e) {
    await logToFile('ОШИБКА СИСТЕМЫ: Ошибка сохранения данных игры: $e');
  }
}



Future<void> clearGameData() async {
  try {
    final file1 = File('current_game.json');
    final file2 = File('current_game_stats.txt');
    
    if (await file1.exists()) {
      await file1.writeAsString(''); 
    }
    if (await file2.exists()) {
      await file2.writeAsString(''); 
    }
  } catch (e) {
    await logToFile('ОШИБКА СИСТЕМЫ: Ошибка очистки данных игры: $e');
  }
}

Future<List<(int, int)>> calculateBotMovesIsolate(List<(int, int)> availableMoves, int count) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(_calculateBotMoves, receivePort.sendPort);
  
  final sendPort = await receivePort.first as SendPort;
  final answerPort = ReceivePort();
  sendPort.send([availableMoves, count, answerPort.sendPort]);
  
  return await answerPort.first;
}

void _calculateBotMoves(SendPort sendPort) {
  final port = ReceivePort();
  sendPort.send(port.sendPort);
  
  port.listen((message) {
    final availableMoves = message[0] as List<(int, int)>;
    final count = message[1] as int;
    final replyTo = message[2] as SendPort;
    
    final random = Random();
    final selectedMoves = <(int, int)>[];
    
    for (int i = 0; i < count && availableMoves.isNotEmpty; i++) {
      final index = random.nextInt(availableMoves.length);
      selectedMoves.add(availableMoves[index]);
    }
    
    replyTo.send(selectedMoves);
  });
}

Future<void> humanPlace(Player player, Map<String, int> config, Map<String, int> sizeOf) async {
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
          final errorMsg = 'Неверный формат. Используйте A1 H';
          print(errorMsg);
          await logToFile('${player.name} ввел неверный формат при размещении корабля: $line');
          continue;
        }
        var start = parsePosition(parts[0], player.size);
        if (start == null) {
          final errorMsg = 'Недопустимая позиция.';
          print(errorMsg);
          await logToFile('${player.name} ввел недопустимую позицию при размещении корабля: $line');
          continue;
        }
        var horizontal = parts[1].toUpperCase() == 'H';
        if (parts[1].toUpperCase() != 'H' && parts[1].toUpperCase() != 'V') {
          final errorMsg = 'Направление должно быть H или V';
          print(errorMsg);
          await logToFile('${player.name} ввел неверное направление при размещении корабля: $line');
          continue;
        }
        if (player.canPlace(start, horizontal, sSize)) {
          player.placeShip(type, sSize, start, horizontal);
          placed = true;
          print('Корабль размещён!');
          await logToFile('${player.name} разместил $type на ${parts[0]} ${horizontal ? "горизонтально" : "вертикально"}');
        } else {
          final errorMsg = 'Нельзя разместить: за пределами поля или пересечение.';
          print(errorMsg);
          await logToFile('${player.name} попытался разместить корабль на занятое поле: ${parts[0]} - Ошибка: поле уже занято кораблем');
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

Future<(int row, int col)> getHumanAttack(Player player) async {
  while (true) {
    stdout.write('Атака (например, A1): ');
    var input = stdin.readLineSync();
    var pos = parsePosition(input, player.size);
    
    if (pos != null && !player.isAttacked(pos)) {
      return pos;
    }
    
    var errorMsg = 'Недопустимая или уже атакованная клетка.';
    print(errorMsg);
    
    if (pos == null) {
      await logToFile('${player.name} ввел недопустимую позицию для атаки: $input');
    } else {
      await logToFile('${player.name} пытался сделать ход на поле ${posToString(pos)}, он уже ходил на него ранее, вызвана ошибка: "Ошибка, вы уже ходили на данное поле"');
    }
  }
}

Stream<String> gameMoveStream(Player current, Player opponent, (int, int) position, bool isHit, String? sunkShip) async* {
  yield 'Ход игрока: ${current.name}';
  yield 'Атакована позиция: ${posToString(position)}';
  yield 'Результат: ${isHit ? 'Попадание!' : 'Промах!'}';
  if (sunkShip != null) {
    yield 'Потоплен корабль: $sunkShip';
  }
  yield '---';
}

Future<void> playGame() async {
  try {
    print('Добро пожаловать в Морской бой!');
    stdout.write('Режим: 1 - Игрок против игрока, 2 - Игрок против бота: ');
    var mode = int.tryParse(stdin.readLineSync() ?? '1') ?? 1;
    stdout.write('Размер поля: 1 - 6x6, 2 - 10x10, 3 - 14x14: ');
    var choice = int.tryParse(stdin.readLineSync() ?? '2') ?? 2;
    var size = [6, 10, 14][choice - 1];
    var config = getShipConfig(size);
    var sizeOf = getSizeOf();

    var p1Name = askName(mode == 1 ? 'Имя первого игрока: ' : 'Ваше имя: ');
    var p2Name = mode == 1 ? askName('Имя второго игрока: ') : 'Компьютер';

    var p1Stats = await loadPlayerStats(p1Name) ?? PlayerStats(p1Name);
    var p2Stats = mode == 1 ? (await loadPlayerStats(p2Name) ?? PlayerStats(p2Name)) : null;

    var p1 = Player(p1Name, size);
    var p2 = mode == 1 ? Player(p2Name, size) : Player('Компьютер', size, isBot: true);

    var gameDataP1 = GameData(p1Name);
    var gameDataP2 = GameData(p2Name);

    await logToFile('Начало новой игры: $p1Name vs $p2Name на поле $size x $size');

    print('Игра начинается!');
    if (mode == 1) {
      stdout.write('Нажмите Enter для размещения кораблей...');
      stdin.readLineSync();
    }
    clearScreen();

    print('${p1.name}, разместите свои корабли:');
    await humanPlace(p1, config, sizeOf);
    
    if (mode == 1) {
      print('Теперь ${p2.name} будет размещать свои корабли.');
      stdout.write('Нажмите Enter для продолжения...');
      stdin.readLineSync();
      clearScreen();
      print('${p2.name}, разместите свои корабли:');
      await humanPlace(p2, config, sizeOf);
      print('Оба игрока разместили свои корабли. Начинаем игру!');
      stdout.write('Нажмите Enter для продолжения...');
      stdin.readLineSync();
    } else {
      print('Теперь компьютер размещает свои корабли.');
      clearScreen();
      print('Компьютер размещает корабли...');
      botPlace(p2, config, sizeOf);
      await logToFile('Компьютер разместил все корабли');
    }
    clearScreen();

    var p1Turn = true;
    Player? winner;
    
    while (winner == null) {
      var current = p1Turn ? p1 : p2;
      var opponent = p1Turn ? p2 : p1;
      
      print('\nХодит ${current.name}');
      
      (int row, int col) pos;
      bool isHit;
      String? sunkShip;
      
      if (current.isBot) {
        var availableMoves = <(int, int)>[];
        for (var r = 0; r < current.size; r++) {
          for (var c = 0; c < current.size; c++) {
            var p = (r, c);
            if (!current.isAttacked(p)) availableMoves.add(p);
          }
        }
        
        var botMoves = await calculateBotMovesIsolate(availableMoves, 1);
        pos = botMoves.first;
        
        isHit = opponent.HitVerif(pos);
        await logToFile('Компьютер атаковал позицию ${posToString(pos)} - ${isHit ? "Попал" : "Промах"}');
        
        var mark = isHit ? 'П' : 'М';
        if (isHit) {
          for (var ship in opponent.ships) {
            if (ship.positions.contains(pos) && ship.isSunk) {
              mark = 'X';
              sunkShip = ship.name;
              for (var p in ship.positions) {
                current.setMark(p, 'X');
              }
              break;
            }
          }
          if (sunkShip == null) {
            current.setMark(pos, mark);
          }
        } else {
          current.setMark(pos, mark);
        }
        
        var msg = 'Компьютер атакует ${posToString(pos)} - ${isHit ? 'Попал!' : 'Промах!'}';
        if (sunkShip != null) msg += ' Потоплен $sunkShip!';
        print(msg);
        
      } else {
        print('Ваш флот:');
        print(current.DisplayyourShip());
        print('\nПоле противника:');
        print(current.DisplayOpponentShip());
        
        pos = await getHumanAttack(current);
        isHit = opponent.HitVerif(pos);
        
        await logToFile('${current.name} сделал ход на ${posToString(pos)}, результат: ${isHit ? "подбит" : "не подбит"}');
        
        var mark = isHit ? 'П' : 'М';
        if (isHit) {
          if (current == p1) {
            gameDataP1.hits++;
          } else {
            gameDataP2.hits++;
          }
          
          for (var ship in opponent.ships) {
            if (ship.positions.contains(pos) && ship.isSunk) {
              mark = 'X';
              sunkShip = ship.name;
              for (var p in ship.positions) {
                current.setMark(p, 'X');
              }
              break;
            }
          }
          if (sunkShip == null) {
            current.setMark(pos, mark);
          }
        } else {
          if (current == p1) {
            gameDataP1.misses++;
          } else {
            gameDataP2.misses++;
          }
          current.setMark(pos, mark);
        }
        
        var msg = isHit ? 'Попал!' : 'Промах!';
        if (sunkShip != null) msg += ' Потоплен $sunkShip!';
        print(msg);
        
        await for (var message in gameMoveStream(current, opponent, pos, isHit, sunkShip)) {
          print(message);
        }
      }
      
      gameDataP1.updateShipStatus(p1.ships);
      gameDataP2.updateShipStatus(p2.ships);
      await saveGameData(gameDataP1);
      
      if (opponent.allSunk) winner = current;
      p1Turn = !p1Turn;
      
      if (winner == null) {
        print('Теперь ходит ${p1Turn ? p1.name : p2.name}');
        if (mode == 1) {
          stdout.write('Нажмите Enter для продолжения...');
          stdin.readLineSync();
        }
        clearScreen();
      }
    }
    p1Stats.gamesPlayed++;
    if (p2Stats != null) p2Stats.gamesPlayed++;
    
    if (winner == p1) {
      p1Stats.wins++;
      if (p2Stats != null) p2Stats.losses++;
      print('${p1.name} побеждает в игре!');
    } else {
      if (p2Stats != null) p2Stats.wins++;
      p1Stats.losses++;
      print('${p2.name} побеждает в игре!');
    }
    
    await savePlayerStats(p1Stats);
    if (p2Stats != null) await savePlayerStats(p2Stats);
    
    await clearGameData();
    
    await logToFile('Игра завершена. Победитель: ${winner.name}');
    
  } catch (e) {
    await logToFile('КРИТИЧЕСКАЯ ОШИБКА В ИГРЕ: $e');
    print('Произошла критическая ошибка: $e');
    rethrow;
  }
}

void main() async {
  var playAgain = true;
  while (playAgain) {
    try {
      await playGame();
    } catch (e) {
      await logToFile('КРИТИЧЕСКАЯ ОШИБКА В MAIN: $e');
      print('Произошла ошибка: $e');
    }
    
    stdout.write('Играть снова? (y/n): ');
    var response = stdin.readLineSync()?.toLowerCase() ?? 'n';
    playAgain = response == 'y';
  }
  print('Спасибо за игру!');
  await logToFile('Программа завершена');
}