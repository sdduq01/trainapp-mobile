import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainapp_mobile/premium/premium_service.dart';
import 'package:trainapp_mobile/premium/trial_service.dart';

void main() {
  final future = Timestamp.fromDate(DateTime.now().add(const Duration(days: 3, hours: 2)));
  final past = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 1)));

  test('estado de la prueba', () {
    expect(Trial.fromMap(null).status, TrialStatus.available);
    expect(Trial.fromMap({'requestedAt': past}).status, TrialStatus.pending);
    final active = Trial.fromMap({'status': 'active', 'endsAt': future});
    expect(active.status, TrialStatus.active);
    expect(active.daysLeft, 4);
    expect(Trial.fromMap({'status': 'active', 'endsAt': past}).status, TrialStatus.expired);
    expect(Trial.fromMap({'status': 'rejected', 'reason': 'used'}).status, TrialStatus.rejected);
  });

  test('premium con vencimiento', () {
    expect(PremiumService.premiumFrom(null), isFalse);
    expect(PremiumService.premiumFrom({'premium': true}), isTrue);
    expect(PremiumService.premiumFrom({'premium': true, 'expiresAt': null}), isTrue);
    expect(PremiumService.premiumFrom({'premium': true, 'expiresAt': future}), isTrue);
    expect(PremiumService.premiumFrom({'premium': true, 'expiresAt': past}), isFalse);
    expect(PremiumService.premiumFrom({'premium': false}), isFalse);
  });
}
