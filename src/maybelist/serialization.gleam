//// The versioned representation shared by local storage and future
//// import/export adapters.

import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import maybelist/list as maybe_list

pub const current_version = 1

pub fn decoder() -> Decoder(maybe_list.MaybeList) {
  use version <- decode.field("version", decode.int)

  case version {
    1 -> {
      use items <- decode.field("items", decode.list(item_decoder()))
      case maybe_list.restore(items) {
        Ok(maybe_list) -> decode.success(maybe_list)
        Error(_) ->
          decode.failure(maybe_list.new(), expected: "valid Maybe List items")
      }
    }
    _ ->
      decode.failure(maybe_list.new(), expected: "a supported format version")
  }
}

fn item_decoder() -> Decoder(#(Int, String, Bool)) {
  use id <- decode.field("id", decode.int)
  use title <- decode.field("title", decode.string)
  use decided <- decode.field("decided", decode.bool)
  decode.success(#(id, title, decided))
}

pub fn encode(maybe_list: maybe_list.MaybeList) -> Json {
  json.object([
    #("version", json.int(current_version)),
    #("items", json.array(maybe_list.items(maybe_list), encode_item)),
  ])
}

fn encode_item(item: maybe_list.MaybeItem) -> Json {
  let maybe_list.MaybeItem(id, title, decided) = item
  json.object([
    #("id", json.int(id)),
    #("title", json.string(title)),
    #("decided", json.bool(decided)),
  ])
}
