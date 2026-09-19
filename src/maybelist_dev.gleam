import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre
import maybelist/list as maybe_list
import maybelist/web
import support/local_storage
import timetravel

pub fn main() -> Nil {
  let app =
    timetravel.application_with_formatters(
      web.init,
      web.update,
      web.view,
      timetravel.Formatters(
        message_name: message_name,
        format_message: format_message,
        format_model: format_model,
      ),
    )
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

fn message_name(message: web.Msg) -> String {
  case message {
    web.UpdateDraft(_) -> "UpdateDraft"
    web.AddItem -> "AddItem"
    web.StartEditing(_, _) -> "StartEditing"
    web.UpdateEditDraft(_) -> "UpdateEditDraft"
    web.SaveEdit(_) -> "SaveEdit"
    web.CancelEdit -> "CancelEdit"
    web.ToggleDecided(_) -> "ToggleDecided"
    web.RequestDeleteItem(_) -> "RequestDeleteItem"
    web.DeleteItem(_) -> "DeleteItem"
    web.StorageLoaded(_) -> "StorageLoaded"
    web.StorageSaved(_) -> "StorageSaved"
  }
}

fn format_message(message: web.Msg) -> String {
  case message {
    web.UpdateDraft(value) -> "UpdateDraft(" <> string.inspect(value) <> ")"
    web.AddItem -> "AddItem"
    web.StartEditing(id, title) ->
      "StartEditing("
      <> int.to_string(id)
      <> ", "
      <> string.inspect(title)
      <> ")"
    web.UpdateEditDraft(value) ->
      "UpdateEditDraft(" <> string.inspect(value) <> ")"
    web.SaveEdit(id) -> "SaveEdit(" <> int.to_string(id) <> ")"
    web.CancelEdit -> "CancelEdit"
    web.ToggleDecided(id) -> "ToggleDecided(" <> int.to_string(id) <> ")"
    web.RequestDeleteItem(id) ->
      "RequestDeleteItem(" <> int.to_string(id) <> ")"
    web.DeleteItem(id) -> "DeleteItem(" <> int.to_string(id) <> ")"
    web.StorageLoaded(result) -> format_storage_loaded(result)
    web.StorageSaved(result) -> format_storage_saved(result)
  }
}

fn format_storage_loaded(
  result: local_storage.LoadResult(maybe_list.MaybeList),
) -> String {
  case result {
    local_storage.Loaded(saved_list) ->
      "StorageLoaded(Loaded(" <> format_maybe_list(saved_list) <> "))"
    local_storage.Missing -> "StorageLoaded(Missing)"
    local_storage.InvalidData -> "StorageLoaded(InvalidData)"
    local_storage.LoadUnavailable -> "StorageLoaded(LoadUnavailable)"
  }
}

fn format_storage_saved(result: local_storage.SaveResult) -> String {
  case result {
    local_storage.Saved -> "StorageSaved(Saved)"
    local_storage.WriteFailed -> "StorageSaved(WriteFailed)"
    local_storage.SaveUnavailable -> "StorageSaved(SaveUnavailable)"
  }
}

fn format_model(model: web.Model) -> String {
  let web.Model(
    maybe_list: maybe_list,
    draft: draft,
    editing_item_id: editing_item_id,
    edit_draft: edit_draft,
    persistence_status: persistence_status,
  ) = model

  [
    "Model(",
    "  maybe_list: " <> format_maybe_list(maybe_list),
    "  draft: " <> string.inspect(draft),
    "  editing_item_id: " <> format_editing_id(editing_item_id),
    "  edit_draft: " <> string.inspect(edit_draft),
    "  persistence_status: " <> format_persistence_status(persistence_status),
    ")",
  ]
  |> string.join("\n")
}

fn format_maybe_list(maybe_list: maybe_list.MaybeList) -> String {
  let items = maybe_list.items(maybe_list)
  case items {
    [] -> "MaybeList(items: [])"
    items -> {
      let formatted_items =
        items
        |> list.map(format_item)
        |> string.join(",\n")

      "MaybeList(\n    items: [\n" <> formatted_items <> "\n    ]\n  )"
    }
  }
}

fn format_item(item: maybe_list.MaybeItem) -> String {
  let maybe_list.MaybeItem(id, title, decided) = item
  "      MaybeItem(id: "
  <> int.to_string(id)
  <> ", title: "
  <> string.inspect(title)
  <> ", decided: "
  <> bool_to_string(decided)
  <> ")"
}

fn format_editing_id(editing_item_id) -> String {
  case editing_item_id {
    None -> "None"
    Some(id) -> "Some(" <> int.to_string(id) <> ")"
  }
}

fn format_persistence_status(status: web.PersistenceStatus) -> String {
  case status {
    web.Loading -> "Loading"
    web.Ready -> "Ready"
    web.PersistenceFailed -> "PersistenceFailed"
  }
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "True"
    False -> "False"
  }
}
