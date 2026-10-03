import 'payment_method.dart';

class Profile {
  const Profile({
    required this.id,
    this.displayName,
    this.isNameConfirmed = true,
    this.defaultPaymentMethod = PaymentMethod.debitCard,
  });

  final String id;
  final String? displayName;
  final bool isNameConfirmed;
  final PaymentMethod defaultPaymentMethod;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      isNameConfirmed: json['name_confirmed_at'] != null,
      defaultPaymentMethod:
          PaymentMethod.fromDb(json['default_payment_method'] as String?) ??
          PaymentMethod.debitCard,
    );
  }
}
