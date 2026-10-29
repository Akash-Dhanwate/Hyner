class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.notes,
    this.whatsappOptIn = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final String notes;
  final bool whatsappOptIn;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class CustomerDraft {
  const CustomerDraft({
    required this.name,
    this.phone = '',
    this.notes = '',
    this.whatsappOptIn = false,
  });

  final String name;
  final String phone;
  final String notes;
  final bool whatsappOptIn;

  void validate() {
    if (name.trim().isEmpty || name != name.trim() || name.length > 120) {
      throw const FormatException('Enter a customer name of 1–120 characters.');
    }
    if (phone.length > 40 || notes.length > 500) {
      throw const FormatException(
        'Phone must be under 40 characters and notes under 500.',
      );
    }
  }
}
