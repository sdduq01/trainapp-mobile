import 'package:flutter_test/flutter_test.dart';
import 'package:trainapp_mobile/gym/models/gym.dart';

void main() {
  test('normalizeWebsite', () {
    expect(Gym.normalizeWebsite(''), '');
    expect(Gym.normalizeWebsite('  '), '');
    expect(Gym.normalizeWebsite('migym.com'), 'https://migym.com');
    expect(Gym.normalizeWebsite(' https://migym.com/x '), 'https://migym.com/x');
    expect(Gym.normalizeWebsite('http://a.co'), 'http://a.co');
    expect(Gym.normalizeWebsite('javascript:alert(1)'), isNull);
    expect(Gym.normalizeWebsite('ftp://a.co'), isNull);
    expect(Gym.normalizeWebsite('hola'), isNull);
    expect(Gym.normalizeWebsite('https://${'a' * 300}.com'), isNull);
  });
}
