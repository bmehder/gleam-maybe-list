import gleam/json
import gleam/option.{None, Some}
import gleeunit
import lustre/effect
import maybelist/list as item_list
import maybelist/serialization
import timetravel as time_travel

type TestMessage {
  Typed(String)
  Committed
}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn add_trims_and_allocates_an_id_test() {
  let updated = item_list.new() |> item_list.add("  Learn Gleam  ")
  assert item_list.items(updated) == [item_list.Item(1, "Learn Gleam", False)]
}

pub fn blank_titles_do_not_change_the_list_test() {
  let original = item_list.new()
  assert item_list.add(original, "   ") == original
  assert item_list.rename(original, 1, "   ") == original
}

pub fn rename_preserves_decision_state_test() {
  let updated =
    item_list.new()
    |> item_list.add("Old idea")
    |> item_list.toggle_decided(1)
    |> item_list.rename(1, "New idea")
  assert item_list.items(updated) == [item_list.Item(1, "New idea", True)]
}

pub fn delete_removes_only_the_matching_item_test() {
  let updated =
    item_list.new()
    |> item_list.add("First")
    |> item_list.add("Second")
    |> item_list.delete(1)
  assert item_list.items(updated) == [item_list.Item(2, "Second", False)]
}

pub fn undecided_count_ignores_decided_items_test() {
  let list_value =
    item_list.new()
    |> item_list.add("First")
    |> item_list.add("Second")
    |> item_list.toggle_decided(1)
  assert item_list.undecided_count(list_value) == 1
}

pub fn serialization_round_trip_test() {
  let original =
    item_list.new()
    |> item_list.add("First")
    |> item_list.add("Second")
    |> item_list.toggle_decided(1)

  let encoded = original |> serialization.encode |> json.to_string
  let assert Ok(decoded) = json.parse(encoded, serialization.decoder())

  assert item_list.items(decoded) == item_list.items(original)
}

pub fn serialization_rejects_unknown_versions_test() {
  let encoded = "{\"version\":99,\"items\":[]}"
  let assert Error(_) = json.parse(encoded, serialization.decoder())
}

pub fn restore_preserves_ids_and_continues_allocating_ids_test() {
  let assert Some(restored) =
    item_list.restore([
      item_list.Item(id: 4, title: "First", decided: False),
      item_list.Item(id: 9, title: "Third", decided: True),
    ])
  let restored = item_list.add(restored, "Fourth")

  assert item_list.items(restored)
    == [
      item_list.Item(10, "Fourth", False),
      item_list.Item(4, "First", False),
      item_list.Item(9, "Third", True),
    ]
}

pub fn restore_rejects_invalid_identity_and_titles_test() {
  assert item_list.restore([
      item_list.Item(id: 1, title: "One", decided: False),
      item_list.Item(id: 1, title: "Duplicate", decided: False),
    ])
    == None
  assert item_list.restore([
      item_list.Item(id: 0, title: "No identity", decided: False),
    ])
    == None
  assert item_list.restore([
      item_list.Item(id: 1, title: "   ", decided: False),
    ])
    == None
}

pub fn time_travel_records_every_message_and_navigates_test() {
  let #(initial, _) =
    time_travel.init(arguments: Nil, with: fn(_) {
      #(item_list.new(), effect.none())
    })

  let update = fn(model, message) {
    case message {
      Typed(title) -> #(item_list.add(model, title), effect.none())
      Committed -> #(model, effect.none())
    }
  }
  let #(typed_once, _) =
    time_travel.update(
      model: initial,
      message: time_travel.App(Typed("One")),
      with: update,
    )
  let #(typed_twice, _) =
    time_travel.update(
      model: typed_once,
      message: time_travel.App(Typed("Two")),
      with: update,
    )

  assert time_travel.position(typed_twice) == #(2, 2)
  assert item_list.items(time_travel.current(typed_twice))
    == [
      item_list.Item(2, "Two", False),
      item_list.Item(1, "One", False),
    ]

  let #(past, _) =
    time_travel.update(
      model: typed_twice,
      message: time_travel.Back,
      with: update,
    )
  assert time_travel.position(past) == #(1, 2)
  assert item_list.items(time_travel.current(past))
    == [item_list.Item(1, "One", False)]

  let #(present, _) =
    time_travel.update(
      model: past,
      message: time_travel.ReturnToPresent,
      with: update,
    )
  assert time_travel.current(present) == time_travel.current(typed_twice)
}

pub fn time_travel_limits_recorded_history_test() {
  let #(initial, _) =
    time_travel.init(arguments: Nil, with: fn(_) { #(0, effect.none()) })
  let update = fn(model, _message) { #(model + 1, effect.none()) }

  let history = record_commits(initial, 105, update)

  assert time_travel.position(history) == #(100, 100)
  assert time_travel.current(history) == 105
}

fn record_commits(model, remaining, update) {
  case remaining {
    0 -> model
    remaining -> {
      let #(next, _) =
        time_travel.update(
          model: model,
          message: time_travel.App(Committed),
          with: update,
        )
      record_commits(next, remaining - 1, update)
    }
  }
}

pub fn time_travel_can_jump_to_a_numbered_state_test() {
  let #(initial, _) =
    time_travel.init(arguments: Nil, with: fn(_) { #(0, effect.none()) })
  let update = fn(model, _message) { #(model + 1, effect.none()) }
  let after_three = record_commits(initial, 3, update)

  let #(first, _) =
    time_travel.update(
      model: after_three,
      message: time_travel.GoTo(1),
      with: update,
    )
  assert time_travel.current(first) == 1
  assert time_travel.position(first) == #(1, 3)

  let #(third, _) =
    time_travel.update(model: first, message: time_travel.GoTo(3), with: update)
  assert time_travel.current(third) == 3
}
