import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// The identity of an item within a Maybe List.
pub type ItemId =
  String

/// A possibility in a Maybe List. This type belongs to the domain and has no
/// knowledge of HTTP, browsers, storage, or Lustre.
pub type Item {
  Item(id: ItemId, title: String, decided: Bool)
}

pub opaque type ItemList {
  ItemList(items: List(Item))
}

pub fn new() -> ItemList {
  ItemList(items: [])
}

pub fn example() -> ItemList {
  ItemList(items: [
    Item("22e718d4-9cf8-4d13-b5a4-ea5f7618729e", "Take a pottery class", False),
    Item(
      "3dbc9bf8-fb53-4d0c-a7d1-6ca8406efa61",
      "Plan a long weekend in Lisbon",
      False,
    ),
    Item(
      "50acfd7e-5d63-46a1-91a9-87a75499f606",
      "Start a tiny herb garden",
      True,
    ),
  ])
}

/// Reconstruct a list from boundary data. IDs and titles must not be blank,
/// and IDs must be unique.
pub fn restore(entries: List(Item)) -> Option(ItemList) {
  case restore_items(entries, seen_ids: [], restored: []) {
    Some(items) -> Some(ItemList(items: items |> list.reverse))
    None -> None
  }
}

fn restore_items(
  entries: List(Item),
  seen_ids seen_ids: List(ItemId),
  restored restored: List(Item),
) -> Option(List(Item)) {
  case entries {
    [] -> Some(restored)
    [Item(id, title, decided), ..rest] -> {
      let id = string.trim(id)
      let title = string.trim(title)
      case id != "" && title != "" && !list.contains(seen_ids, id) {
        False -> None
        True ->
          restore_items(rest, seen_ids: [id, ..seen_ids], restored: [
            Item(id, title, decided),
            ..restored
          ])
      }
    }
  }
}

/// Return the possibilities in display order.
pub fn items(item_list: ItemList) -> List(Item) {
  item_list.items
}

pub fn add(item_list: ItemList, id: ItemId, title: String) -> ItemList {
  let id = string.trim(id)
  let title = string.trim(title)
  let id_exists =
    list.any(item_list.items, fn(item) {
      let Item(item_id, _, _) = item
      item_id == id
    })
  case id == "" || title == "" || id_exists {
    True -> item_list
    _ -> ItemList(items: [Item(id, title, False), ..item_list.items])
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
