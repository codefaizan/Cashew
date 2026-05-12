import 'dart:math';

void main() {
  final random = Random(42);
  final now = DateTime.now();
  final startDate = DateTime(now.year, now.month - 5, 1);

  final List<String> categories = [
    "('1', 'Salary', '#4CAF50', 'work', 0, 1)",
    "('2', 'Food', '#FF9800', 'restaurant', 1, 0)",
    "('3', 'Dining', '#E91E63', 'local_cafe', 2, 0)",
    "('4', 'Transport', '#2196F3', 'directions_car', 3, 0)",
    "('5', 'Utilities', '#9C27B0', 'bolt', 4, 0)",
    "('6', 'Entertainment', '#F44336', 'movie', 5, 0)",
    "('7', 'Shopping', '#00BCD4', 'shopping_bag', 6, 0)",
    "('8', 'Healthcare', '#FF5722', 'local_hospital', 7, 0)",
    "('9', 'Rent', '#795548', 'home', 8, 0)",
    "('10', 'Subscriptions', '#673AB7', 'subscriptions', 9, 0)",
  ];

  print('-- Categories');
  print('INSERT OR REPLACE INTO categories (category_pk, name, colour, icon_name, "order", income) VALUES');
  print(categories.map((c) => '$c').join(',\n') + ';');

  print('\n-- Wallet');
  print("INSERT OR REPLACE INTO wallets (wallet_pk, name, colour, icon_name, on_default, credit, date_created, date_time_modified, \"order\", archived)");
  print("VALUES ('1', 'Main', '#4CAF50', 'account_balance_wallet', 1, 0, datetime('now'), datetime('now'), 0, 0);");

  print('\n-- Transactions');
  final transactions = <String>[];
  int txIndex = 0;

  for (int month = 0; month < 6; month++) {
    final monthDate = DateTime(startDate.year, startDate.month + month, 1);
    final monthName = _monthName(monthDate.month);

    transactions.add(_insertTransaction(txIndex++, 'Salary', 50000, '1', monthDate, true, "Monthly salary for $monthName"));
    transactions.add(_insertTransaction(txIndex++, 'Rent', -15000, '9', monthDate, false, "Monthly rent for $monthName"));
    transactions.add(_insertTransaction(txIndex++, 'Electricity Bill', -(random.nextDouble() * 2000 + 1500).round(), '5', DateTime(monthDate.year, monthDate.month, 5), false, 'Monthly electricity'));
    transactions.add(_insertTransaction(txIndex++, 'Internet', -1500, '5', DateTime(monthDate.year, monthDate.month, 10), false, 'Monthly internet'));
    transactions.add(_insertTransaction(txIndex++, 'Water Bill', -500, '5', DateTime(monthDate.year, monthDate.month, 12), false, 'Monthly water'));
    transactions.add(_insertTransaction(txIndex++, 'Mobile Bill', -1000, '5', DateTime(monthDate.year, monthDate.month, 15), false, 'Monthly mobile'));

    transactions.add(_insertTransaction(txIndex++, 'Grocery Shopping', -(random.nextDouble() * 4000 + 2000).round(), '2', DateTime(monthDate.year, monthDate.month, 3), false, 'Weekly groceries'));
    transactions.add(_insertTransaction(txIndex++, 'Grocery Shopping', -(random.nextDouble() * 4000 + 2000).round(), '2', DateTime(monthDate.year, monthDate.month, 10), false, 'Weekly groceries'));
    transactions.add(_insertTransaction(txIndex++, 'Grocery Shopping', -(random.nextDouble() * 4000 + 2000).round(), '2', DateTime(monthDate.year, monthDate.month, 17), false, 'Weekly groceries'));
    transactions.add(_insertTransaction(txIndex++, 'Grocery Shopping', -(random.nextDouble() * 4000 + 2000).round(), '2', DateTime(monthDate.year, monthDate.month, 24), false, 'Weekly groceries'));

    for (int i = 0; i < 8; i++) {
      final day = random.nextInt(28) + 1;
      final categories = [
        ("Dining", ['Coffee', 'Lunch', 'Dinner', 'Snacks', 'Pizza'], '3', 1500),
        ("Transport", ['Uber', 'Gas', 'Metro', 'Taxi', 'Parking'], '4', 1500),
        ("Entertainment", ['Movie', 'Concert', 'Games', 'Streaming'], '6', 1800),
        ("Shopping", ['Clothes', 'Shoes', 'Accessories', 'Online Shopping'], '7', 4000),
        ("Healthcare", ['Pharmacy', 'Doctor Visit', 'Dental'], '8', 800),
        ("Subscriptions", ['Netflix', 'Spotify', 'YouTube Premium'], '10', 1500),
      ];

      final (categoryName, names, catFk, maxAmount) = categories[random.nextInt(categories.length)];
      final name = names[random.nextInt(names.length)];
      final amount = -(random.nextDouble() * maxAmount + 200).round();

      transactions.add(_insertTransaction(txIndex++, name, amount, catFk, DateTime(monthDate.year, monthDate.month, day), false, ''));
    }

    transactions.add(_insertTransaction(txIndex++, 'Gym Membership', -2000, '8', DateTime(monthDate.year, monthDate.month, 5), false, 'Monthly gym'));
    transactions.add(_insertTransaction(txIndex++, 'Netflix', -1500, '10', DateTime(monthDate.year, monthDate.month, 1), false, 'Monthly subscription'));
    transactions.add(_insertTransaction(txIndex++, 'Spotify', -400, '10', DateTime(monthDate.year, monthDate.month, 2), false, 'Monthly subscription'));
    transactions.add(_insertTransaction(txIndex++, 'Pharmacy', -(random.nextDouble() * 800 + 200).round(), '8', DateTime(monthDate.year, monthDate.month, 8 + random.nextInt(20)), false, 'Medicines'));
  }

  print('INSERT OR REPLACE INTO transactions (transaction_pk, name, amount, category_fk, wallet_fk, date_created, income, paid, skip_paid, note) VALUES');
  print(transactions.join(',\n') + ';');

  print('\n-- Verify data');
  print("SELECT 'Income' as type, SUM(ABS(amount)) as total FROM transactions WHERE income = 1;");
  print("SELECT 'Expenses' as type, SUM(ABS(amount)) as total FROM transactions WHERE income = 0;");
}

String _insertTransaction(int index, String name, int amount, String categoryFk, DateTime date, bool income, String note) {
  final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  return "('$index', '$name', $amount, '$categoryFk', '1', '$dateStr', ${income ? 1 : 0}, 1, 0, '$note')";
}

String _monthName(int month) {
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  return months[month - 1];
}