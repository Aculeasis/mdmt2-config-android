import 'package:mdmt2_config/src/native_states.dart' show RootPage;
import 'package:test/test.dart';

void main() {
  test('RootPage', () {
    final test = ['', ':', '::', ':::', 'aa:', ':bb', 'a:b', 'ab', 'a:b:c:d:', ':a:b:c:d', 'a:::b', 'a::::', '::::b'];
    final empty = [true, true, true, true, true, true, false, true, false, true, false, false, true];
    expect(test.length, empty.length);

    for (int i = 0; i < test.length; i++) {
      final root = RootPage.fromString(test[i]);
      expect(root.isEmpty, empty[i], reason: 'RootPage.str error i=$i');
      expect(root.toString(), root.isEmpty ? 'null:null' : test[i], reason: 'RootPage.toString error i=$i');
    }
  });
}
