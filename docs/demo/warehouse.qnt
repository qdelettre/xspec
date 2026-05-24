module warehouse {
  type ItemId = str

  type Item = {
    parts: int,
    originalParts: int,
    shipped: bool,
  }

  var inventory: ItemId -> Item

  action init = all {
    inventory' = Map(),
  }

  action receive(id: ItemId, n: int): bool = all {
    n > 0,
    not(inventory.keys().contains(id)),
    inventory' = inventory.put(id, { parts: n, originalParts: n, shipped: false }),
  }

  action lose_part(id: ItemId): bool = all {
    inventory.keys().contains(id),
    inventory.get(id).parts > 0,
    inventory' = inventory.put(id, { ...inventory.get(id), parts: inventory.get(id).parts - 1 }),
  }

  // BUG: ship() doesn't require parts == originalParts.
  action ship(id: ItemId): bool = all {
    inventory.keys().contains(id),
    not(inventory.get(id).shipped),
    inventory' = inventory.put(id, { ...inventory.get(id), shipped: true }),
  }

  action step = any {
    nondet id = oneOf(Set("a", "b", "c"))
    nondet n = oneOf(1.to(3))
    receive(id, n),
    nondet id = oneOf(Set("a", "b", "c"))
    lose_part(id),
    nondet id = oneOf(Set("a", "b", "c"))
    ship(id),
  }

  val shippedIntact = inventory.keys().forall(id =>
    not(inventory.get(id).shipped) or (inventory.get(id).parts == inventory.get(id).originalParts)
  )
}
