import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// The identity of an item within a Maybe List.
pub type ItemId =
  Int

/// A possibility in a Maybe List. This type belongs to the domain and has no
/// knowledge of HTTP, browsers, storage, or Lustre.
pub type Item {
  Item(id: ItemId, title: String, decided: Bool)
}

/// The aggregate keeps ID allocation together with the items so every adapter
/// (web UI, JSON API, or CLI) follows the same rules.
pub opaque type ItemList {
  ItemList(items: List(Item), next_item_id: ItemId)
}

pub fn new() -> ItemList {
  ItemList(items: [], next_item_id: 1)
}

pub fn example() -> ItemList {
  ItemList(
    items: [
      Item(1, "Take a pottery class", False),
      Item(2, "Plan a long weekend in Lisbon", False),
      Item(3, "Start a tiny herb garden", True),
    ],
    next_item_id: 4,
  )
}

/// Reconstruct a list from boundary data without exposing its internal ID
/// allocation. IDs must be positive and unique, and titles must not be blank.
pub fn restore(entries: List(Item)) -> Option(ItemList) {
  case restore_items(entries, seen_ids: [], restored: [], highest_id: 0) {
    Some(#(items, highest_id)) ->
      Some(ItemList(items: list.reverse(items), next_item_id: highest_id + 1))
    None -> None
  }
}

fn restore_items(
  entries: List(Item),
  seen_ids seen_ids: List(ItemId),
  restored restored: List(Item),
  highest_id highest_id: ItemId,
) -> Option(#(List(Item), ItemId)) {
  case entries {
    [] -> Some(#(restored, highest_id))
    [Item(id, title, decided), ..rest] -> {
      let title = string.trim(title)
      case id > 0 && title != "" && !list.contains(seen_ids, id) {
        False -> None
        True ->
          restore_items(
            rest,
            seen_ids: [id, ..seen_ids],
            restored: [Item(id, title, decided), ..restored],
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
pub fn items(item_list: ItemList) -> List(Item) {
  item_list.items
}

pub fn add(item_list: ItemList, title: String) -> ItemList {
  let title = string.trim(title)
  case title {
    "" -> item_list
    _ ->
      ItemList(
        items: [Item(item_list.next_item_id, title, False), ..item_list.items],
        next_item_id: item_list.next_item_id + 1,
      )
  }
}

pub fn rename(
  item_list item_list: ItemList,
  id id: ItemId,
  title title: String,
) -> ItemList {
  let new_title = string.trim(title)
  case new_title {
    "" -> item_list
    _ ->
      ItemList(
        ..item_list,
        items: list.map(item_list.items, fn(item) {
          case item {
            Item(item_id, _, decided) if item_id == id ->
              Item(item_id, new_title, decided)
            _ -> item
          }
        }),
      )
  }
}

pub fn toggle_decided(item_list: ItemList, id: ItemId) -> ItemList {
  ItemList(
    ..item_list,
    items: list.map(item_list.items, fn(item) {
      case item {
        Item(item_id, title, decided) if item_id == id ->
          Item(item_id, title, !decided)
        _ -> item
      }
    }),
  )
}

pub fn delete(item_list: ItemList, id: ItemId) -> ItemList {
  ItemList(
    ..item_list,
    items: list.filter(item_list.items, fn(item) {
      let Item(item_id, _, _) = item
      item_id != id
    }),
  )
}

pub fn undecided_count(item_list: ItemList) -> Int {
  item_list.items
  |> list.filter(fn(item) {
    let Item(_, _, decided) = item
    decided == False
  })
  |> list.length
}
