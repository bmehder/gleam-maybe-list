import gleam/list
import gleam/result
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

/// Reconstruct a list from boundary data without exposing its internal ID
/// allocation. IDs must be positive and unique, and titles must not be blank.
pub fn restore(entries: List(#(Int, String, Bool))) -> Result(MaybeList, Nil) {
  use #(items, highest_id) <- result.try(restore_items(
    entries,
    seen_ids: [],
    restored: [],
    highest_id: 0,
  ))
  Ok(MaybeList(items: list.reverse(items), next_id: highest_id + 1))
}

fn restore_items(
  entries: List(#(Int, String, Bool)),
  seen_ids seen_ids: List(Int),
  restored restored: List(MaybeItem),
  highest_id highest_id: Int,
) -> Result(#(List(MaybeItem), Int), Nil) {
  case entries {
    [] -> Ok(#(restored, highest_id))
    [#(id, title, decided), ..rest] -> {
      let title = string.trim(title)
      case id > 0 && title != "" && !list.contains(seen_ids, id) {
        False -> Error(Nil)
        True ->
          restore_items(
            rest,
            seen_ids: [id, ..seen_ids],
            restored: [MaybeItem(id, title, decided), ..restored],
            highest_id: case id > highest_id {
              True -> id
              False -> highest_id
            },
          )
      }
    }
  }
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

pub fn rename(
  maybe_list maybe_list: MaybeList,
  id id: Int,
  title title: String,
) -> MaybeList {
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
    decided == False
  })
  |> list.length
}
