// Simple bank account model.
// Fixed: withdraw guards on sufficient balance.
module bank {
  var balance: int

  action init = balance' = 100

  action deposit(amount: int): bool = all {
    amount > 0,
    balance' = balance + amount,
  }

  action withdraw(amount: int): bool = all {
    amount > 0,
    balance >= amount,
    balance' = balance - amount,
  }

  action step = any {
    nondet a = oneOf(1.to(50))
    deposit(a),
    nondet a = oneOf(1.to(50))
    withdraw(a),
  }

  val safe = balance >= 0
}
