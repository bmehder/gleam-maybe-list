import gleeunit
import maybelist/list

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn add_trims_and_allocates_an_id_test() {
  let updated = list.new() |> list.add("  Learn Gleam  ")
  assert list.items(updated) == [list.MaybeItem(1, "Learn Gleam", False)]
}

pub fn blank_titles_do_not_change_the_list_test() {
  let original = list.new()
  assert list.add(original, "   ") == original
  assert list.rename(original, 1, "   ") == original
}

pub fn rename_preserves_decision_state_test() {
  let updated =
    list.new()
    |> list.add("Old idea")
    |> list.toggle_decided(1)
    |> list.rename(1, "New idea")
  assert list.items(updated) == [list.MaybeItem(1, "New idea", True)]
}

pub fn delete_removes_only_the_matching_item_test() {
  let updated =
    list.new() |> list.add("First") |> list.add("Second") |> list.delete(1)
  assert list.items(updated) == [list.MaybeItem(2, "Second", False)]
}

pub fn undecided_count_ignores_decided_items_test() {
  let maybe_list =
    list.new()
    |> list.add("First")
    |> list.add("Second")
    |> list.toggle_decided(1)
  assert list.undecided_count(maybe_list) == 1
}
