import 'customer.dart';

abstract interface class CustomerRepository {
  Future<List<Customer>> list(String uid);
  Future<Customer> save(String uid, CustomerDraft draft, {String? id});
}
