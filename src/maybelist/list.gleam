import gleam/list
import gleam/string

/// A possibility in a Maybe List. This type belongs to the domain and has no
/// knowledge of HTTP, browsers, storage, or Lustre.
pub type MaybeItem {
  MaybeItem(id: Int, title: String, decided: Bool)
}

/// The aggregate keeps ID allocation together with the items so every adapter
/// (web UI, JSON API, or CLI) follows the same rules.
pub opaque type MaybeList {
  MaybeList(items: List(MaybeItem), next_id: Int)
}

pub fn new() -> MaybeList {
  MaybeList(items: [], next_id: 1)
}

pub fn example() -> MaybeList {
  MaybeList(
    items: [
      MaybeItem(1, "Take a pottery class", False),
      MaybeItem(2, "Plan a long weekend in Lisbon", False),
      MaybeItem(3, "Start a tiny herb garden", True),
    ],
    next_id: 4,
  )
}

/// Return the possibilities in display order.
pub fn items(maybe_list: MaybeList) -> List(MaybeItem) {
  maybe_list.items
}

pub fn add(maybe_list: MaybeList, title: String) -> MaybeList {
  let title = string.trim(title)
  case title {
    "" -> maybe_list
    _ ->
      MaybeList(
        items: [MaybeItem(maybe_list.next_id, title, False), ..maybe_list.items],
        next_id: maybe_list.next_id + 1,
      )
  }
}

pub fn rename(maybe_list: MaybeList, id: Int, title: String) -> MaybeList {
  let title = string.trim(title)
  case title {
    "" -> maybe_list
    _ ->
      MaybeList(
        ..maybe_list,
        items: list.map(maybe_list.items, fn(item) {
          case item {
            MaybeItem(item_id, _, decided) if item_id == id ->
              MaybeItem(item_id, title, decided)
            _ -> item
          }
        }),
      )
  }
}

pub fn toggle_decided(maybe_list: MaybeList, id: Int) -> MaybeList {
  MaybeList(
    ..maybe_list,
    items: list.map(maybe_list.items, fn(item) {
      case item {
        MaybeItem(item_id, title, decided) if item_id == id ->
          MaybeItem(item_id, title, !decided)
        _ -> item
      }
    }),
  )
}

pub fn delete(maybe_list: MaybeList, id: Int) -> MaybeList {
  MaybeList(
    ..maybe_list,
    items: list.filter(maybe_list.items, fn(item) {
      let MaybeItem(item_id, _, _) = item
      item_id != id
    }),
  )
}

pub fn undecided_count(maybe_list: MaybeList) -> Int {
  maybe_list.items
  |> list.filter(fn(item) {
    let MaybeItem(_, _, decided) = item
    !decided
  })
  |> list.length
}
