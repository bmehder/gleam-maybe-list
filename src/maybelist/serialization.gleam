//// The versioned representation shared by local storage and future
//// import/export adapters.

import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import gleam/option.{None, Some}
import maybelist/list as item_list

pub const current_version = 1

pub fn decoder() -> Decoder(item_list.ItemList) {
  use version <- decode.field("version", decode.int)

  case version {
    1 -> {
      use items <- decode.field("items", decode.list(item_decoder()))
      case item_list.restore(items) {
        Some(list) -> decode.success(list)
        None ->
          decode.failure(item_list.new(), expected: "valid Maybe List items")
      }
    }
    _ -> decode.failure(item_list.new(), expected: "a supported format version")
  }
}

fn item_decoder() -> Decoder(item_list.Item) {
  use id <- decode.field("id", decode.int)
  use title <- decode.field("title", decode.string)
  use decided <- decode.field("decided", decode.bool)
  decode.success(item_list.Item(id:, title:, decided:))
}

pub fn encode(list: item_list.ItemList) -> Json {
  json.object([
    #("version", json.int(current_version)),
    #("items", json.array(item_list.items(list), encode_item)),
  ])
}

fn encode_item(item: item_list.Item) -> Json {
  let item_list.Item(id, title, decided) = item
  json.object([
    #("id", json.int(id)),
    #("title", json.string(title)),
    #("decided", json.bool(decided)),
  ])
}
