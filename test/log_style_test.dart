import 'package:mdmt2_config/src/settings/log_style.dart' show LogStyle;
import 'package:mdmt2_config/src/terminal/log.dart' show LogLevel;
import 'package:test/test.dart';

void main() {
  test('LogStyle levels', () {
    final style = LogStyle();
    final allSet = style.logLevels;
    final allUnset = 0;
    List<LogLevel> shuffled() => LogLevel.values.toList(growable: false)..shuffle();

    for (var lvl in shuffled()) expect(style.containsLvl(lvl), true);

    for (var lvl in shuffled()) expect(style.addLvl(lvl), false);

    for (var lvl in shuffled()) expect(style.delLvl(lvl), true);

    expect(style.logLevels, allUnset);

    for (var lvl in shuffled()) expect(style.containsLvl(lvl), false);

    for (var lvl in shuffled()) expect(style.addLvl(lvl), true);

    expect(style.logLevels, allSet);
  });
}
