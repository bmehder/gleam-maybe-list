import gleam/int
import gleam/list as gleam_list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg
import lustre/event
import maybelist/list as item_list
import maybelist/serialization
import support/confirmation
import support/local_storage

const storage_key = "maybelist.data"

pub type PersistenceStatus {
  Loading
  Ready
  PersistenceFailed
}

pub type Model {
  Model(
    item_list: item_list.ItemList,
    new_item_draft: String,
    editing_item_id: Option(item_list.ItemId),
    edit_draft: String,
    persistence_status: PersistenceStatus,
  )
}

pub type Msg {
  UpdateNewItemDraft(String)
  AddItem
  StartEditing(item_list.ItemId, String)
  UpdateEditDraft(String)
  SaveEdit(item_list.ItemId)
  CancelEdit
  ToggleDecided(item_list.ItemId)
  RequestDeleteItem(item_list.ItemId)
  DeleteItem(item_list.ItemId)
  StorageLoaded(local_storage.LoadResult(item_list.ItemList))
  StorageSaved(local_storage.SaveResult)
}

pub fn init(_arguments: Nil) -> #(Model, Effect(Msg)) {
  #(
    Model(
      item_list: item_list.example(),
      new_item_draft: "",
      editing_item_id: None,
      edit_draft: "",
      persistence_status: Loading,
    ),
    local_storage.load(
      key: storage_key,
      reader: serialization.decoder(),
      writer: serialization.encode,
      to_message: StorageLoaded,
    ),
  )
}

pub fn update(model: Model, message: Msg) -> #(Model, Effect(Msg)) {
  let updated = case message {
    UpdateNewItemDraft(value) -> Model(..model, new_item_draft: value)
    AddItem -> {
      let updated_list = item_list.add(model.item_list, model.new_item_draft)
      case updated_list == model.item_list {
        True -> model
        False -> Model(..model, item_list: updated_list, new_item_draft: "")
      }
    }
    StartEditing(id, title) ->
      Model(..model, editing_item_id: Some(id), edit_draft: title)
    UpdateEditDraft(value) -> Model(..model, edit_draft: value)
    SaveEdit(id) ->
      case string.trim(model.edit_draft) {
        "" -> model
        _ ->
          Model(
            ..model,
            item_list: item_list.rename(
              item_list: model.item_list,
              id: id,
              title: model.edit_draft,
            ),
            editing_item_id: None,
            edit_draft: "",
          )
      }
    CancelEdit -> Model(..model, editing_item_id: None, edit_draft: "")
    ToggleDecided(id) ->
      Model(..model, item_list: item_list.toggle_decided(model.item_list, id))
    RequestDeleteItem(_) -> model
    DeleteItem(id) ->
      Model(
        ..model,
        item_list: item_list.delete(model.item_list, id),
        editing_item_id: case model.editing_item_id {
          Some(editing_id) if editing_id == id -> None
          _ -> model.editing_item_id
        },
      )
    StorageLoaded(result) ->
      case result {
        local_storage.Loaded(saved_list) ->
          Model(..model, item_list: saved_list, persistence_status: Ready)
        local_storage.Missing -> Model(..model, persistence_status: Ready)
        local_storage.InvalidData | local_storage.LoadUnavailable ->
          Model(..model, persistence_status: PersistenceFailed)
      }
    StorageSaved(result) ->
      case result {
        local_storage.Saved -> Model(..model, persistence_status: Ready)
        local_storage.WriteFailed | local_storage.SaveUnavailable ->
          Model(..model, persistence_status: PersistenceFailed)
      }
  }

  let persistence_effect = case message, updated.item_list == model.item_list {
    StorageLoaded(_), _ -> effect.none()
    _, False ->
      local_storage.save(
        key: storage_key,
        value: updated.item_list,
        reader: serialization.decoder(),
        writer: serialization.encode,
        to_message: StorageSaved,
      )
    _, True -> effect.none()
  }

  let confirmation_effect = case message {
    RequestDeleteItem(id) ->
      confirmation.ask(
        "Delete this possibility? This decision is suspiciously permanent.",
        on_confirmation: DeleteItem(id),
      )
    _ -> effect.none()
  }

  #(updated, effect.batch([persistence_effect, confirmation_effect]))
}

pub fn view(model: Model) -> Element(Msg) {
  let open_count = item_list.undecided_count(model.item_list)
  html.div(
    [
      attribute.class(
        "min-h-screen bg-stone-50 text-stone-900 selection:bg-lime-200",
      ),
    ],
    [
      background_decoration(),
      html.main(
        [
          attribute.class(
            "relative mx-auto flex min-h-screen w-full max-w-3xl flex-col px-5 py-8 sm:px-8 sm:py-14",
          ),
        ],
        [
          header_view(),
          html.section([attribute.class("mt-12 sm:mt-16")], [
            html.div(
              [attribute.class("mb-4 flex items-end justify-between gap-4")],
              [
                html.div([], [
                  html.p(
                    [
                      attribute.class(
                        "text-xs font-bold uppercase tracking-[0.2em] text-stone-400",
                      ),
                    ],
                    [html.text("Productivity, allegedly")],
                  ),
                  html.h2(
                    [
                      attribute.class(
                        "mt-1 text-2xl font-semibold tracking-tight",
                      ),
                    ],
                    [html.text("What are we avoiding today?")],
                  ),
                ]),
                html.p(
                  [attribute.class("shrink-0 pb-1 text-sm text-stone-500")],
                  [
                    html.strong(
                      [attribute.class("font-semibold text-stone-800")],
                      [html.text(int.to_string(open_count))],
                    ),
                    html.text(case open_count {
                      1 -> " loose end"
                      _ -> " loose ends"
                    }),
                  ],
                ),
              ],
            ),
            add_form(model),
            item_list(model),
            persistence_notice(model.persistence_status),
          ]),
          footer_view(),
        ],
      ),
    ],
  )
}

fn persistence_notice(status: PersistenceStatus) -> Element(Msg) {
  case status {
    Loading ->
      html.p([attribute.class("mt-3 text-center text-xs text-stone-400")], [
        html.text("Recovering your unresolved business…"),
      ])
    Ready -> html.text("")
    PersistenceFailed ->
      html.p(
        [
          attribute.class(
            "mt-3 rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-center text-xs text-amber-800",
          ),
        ],
        [
          html.text(
            "Your maybes are staying in this tab. Even the browser declined to commit.",
          ),
        ],
      )
  }
}

fn header_view() -> Element(Msg) {
  html.header([], [
    html.div(
      [
        attribute.class(
          "inline-flex items-center gap-2 rounded-full border border-stone-200 bg-white/80 px-3 py-1.5 text-xs font-semibold text-stone-600 shadow-sm backdrop-blur",
        ),
      ],
      [
        html.span([attribute.class("h-2 w-2 rounded-full bg-lime-400")], []),
        html.text("Productivity-adjacent"),
      ],
    ),
    html.h1(
      [
        attribute.class(
          "mt-6 text-5xl font-bold leading-[0.95] tracking-[-0.055em] text-stone-950 sm:text-7xl",
        ),
      ],
      [
        html.text("Maybe"),
        html.span([attribute.class("text-lime-500")], [html.text(".")]),
        html.br([]),
        html.span([attribute.class("text-stone-400")], [html.text("Just")]),
        html.text(" Nothing"),
      ],
    ),
    html.p(
      [
        attribute.class(
          "mt-6 max-w-lg text-base leading-7 text-stone-600 sm:text-lg",
        ),
      ],
      [
        html.text(
          "For everything you absolutely intend to do. Eventually. Probably.",
        ),
      ],
    ),
  ])
}

fn add_form(model: Model) -> Element(Msg) {
  html.form(
    [
      event.on_submit(fn(_) { AddItem }),
      attribute.class(
        "group flex gap-2 rounded-2xl border border-stone-200 bg-white p-2 shadow-sm transition focus-within:border-stone-400 focus-within:shadow-md",
      ),
    ],
    [
      html.input([
        attribute.type_("text"),
        attribute.name("maybe"),
        attribute.autocomplete("off"),
        attribute.value(model.new_item_draft),
        attribute.placeholder("Pretend you'll do something…"),
        attribute.aria_label("A new possibility"),
        attribute.class(
          "min-w-0 flex-1 bg-transparent px-3 py-2.5 text-base outline-none placeholder:text-stone-400",
        ),
        event.on_input(UpdateNewItemDraft),
      ]),
      html.button(
        [
          attribute.type_("submit"),
          attribute.disabled(string.trim(model.new_item_draft) == ""),
          attribute.class(
            "rounded-xl bg-stone-900 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-lime-500 hover:text-stone-950 disabled:cursor-not-allowed disabled:bg-stone-200 disabled:text-stone-400 sm:px-5",
          ),
        ],
        [html.text("Add to limbo")],
      ),
    ],
  )
}

fn item_list(model: Model) -> Element(Msg) {
  case item_list.items(model.item_list) {
    [] ->
      html.div(
        [
          attribute.class(
            "mt-5 rounded-2xl border border-dashed border-stone-300 px-6 py-14 text-center",
          ),
        ],
        [
          html.p([attribute.class("text-3xl")], [html.text("¯\\_(ツ)_/¯")]),
          html.p([attribute.class("mt-4 font-semibold")], [
            html.text("Suspiciously empty"),
          ]),
          html.p([attribute.class("mt-1 text-sm text-stone-500")], [
            html.text("Either you're thriving or you forgot everything."),
          ]),
        ],
      )
    items ->
      html.ul(
        [attribute.class("mt-5 space-y-3")],
        gleam_list.map(items, fn(item) { item_view(item, model) }),
      )
  }
}

fn item_view(item: item_list.Item, model: Model) -> Element(Msg) {
  let item_list.Item(id, title, decided) = item
  let is_editing = case model.editing_item_id {
    Some(editing_id) -> editing_id == id
    None -> False
  }
  html.li(
    [
      attribute.class(
        "group rounded-2xl border bg-white shadow-sm transition hover:-translate-y-0.5 hover:shadow-md",
      ),
      attribute.classes([
        #("border-stone-200", !decided),
        #("border-lime-200 bg-lime-50/40", decided),
      ]),
    ],
    case is_editing {
      True -> edit_view(id, model.edit_draft)
      False -> display_view(id, title, decided)
    },
  )
}

fn display_view(
  id: item_list.ItemId,
  title: String,
  decided: Bool,
) -> List(Element(Msg)) {
  [
    html.div([attribute.class("flex items-center gap-3 p-3 sm:p-4")], [
      html.button(
        [
          attribute.type_("button"),
          event.on_click(ToggleDecided(id)),
          attribute.aria_label(case decided {
            True -> "Return to maybe"
            False -> "Mark as decided"
          }),
          attribute.class(
            "flex h-9 w-9 shrink-0 items-center justify-center rounded-full border text-sm font-bold transition",
          ),
          attribute.classes([
            #(
              "border-stone-300 text-transparent hover:border-lime-400 hover:bg-lime-50",
              !decided,
            ),
            #("border-lime-400 bg-lime-400 text-stone-950", decided),
          ]),
        ],
        [html.text("✓")],
      ),
      html.div([attribute.class("min-w-0 flex-1")], [
        html.p(
          [
            attribute.class("break-words font-medium leading-6"),
            attribute.classes([
              #("text-stone-400 line-through decoration-stone-300", decided),
            ]),
          ],
          [html.text(title)],
        ),
        html.p([attribute.class("mt-0.5 text-xs font-medium text-stone-400")], [
          html.text(case decided {
            True -> "Look at you, deciding things."
            False -> "Commitment pending"
          }),
        ]),
      ]),
      html.div(
        [
          attribute.class(
            "flex shrink-0 gap-1 opacity-100 transition sm:opacity-0 sm:group-hover:opacity-100 sm:group-focus-within:opacity-100",
          ),
        ],
        [
          icon_button("Edit", "✎", StartEditing(id, title)),
          icon_button("Delete", "×", RequestDeleteItem(id)),
        ],
      ),
    ]),
  ]
}

fn edit_view(id: item_list.ItemId, value: String) -> List(Element(Msg)) {
  [
    html.form(
      [
        event.on_submit(fn(_) { SaveEdit(id) }),
        attribute.class("flex items-center gap-2 p-3 sm:p-4"),
      ],
      [
        html.input([
          attribute.type_("text"),
          attribute.value(value),
          attribute.autofocus(True),
          attribute.aria_label("Edit possibility"),
          attribute.class(
            "min-w-0 flex-1 rounded-xl border border-stone-300 bg-stone-50 px-3 py-2 text-sm outline-none transition focus:border-stone-600 focus:bg-white",
          ),
          event.on_input(UpdateEditDraft),
        ]),
        html.button(
          [
            attribute.type_("submit"),
            attribute.class(
              "rounded-lg bg-stone-900 px-3 py-2 text-sm font-semibold text-white hover:bg-lime-500 hover:text-stone-950",
            ),
          ],
          [html.text("Save")],
        ),
        html.button(
          [
            attribute.type_("button"),
            event.on_click(CancelEdit),
            attribute.class(
              "rounded-lg px-2 py-2 text-sm font-medium text-stone-500 hover:bg-stone-100 hover:text-stone-900",
            ),
          ],
          [html.text("Cancel")],
        ),
      ],
    ),
  ]
}

fn icon_button(label: String, icon: String, message: Msg) -> Element(Msg) {
  html.button(
    [
      attribute.type_("button"),
      event.on_click(message),
      attribute.aria_label(label),
      attribute.title(label),
      attribute.class(
        "flex h-9 w-9 items-center justify-center rounded-lg text-lg text-stone-400 transition hover:bg-stone-100 hover:text-stone-900",
      ),
    ],
    [html.text(icon)],
  )
}

fn background_decoration() -> Element(Msg) {
  html.div(
    [attribute.class("pointer-events-none fixed inset-0 overflow-hidden")],
    [
      html.div(
        [
          attribute.class(
            "absolute -right-32 -top-32 h-80 w-80 rounded-full bg-lime-200/40 blur-3xl",
          ),
        ],
        [],
      ),
      html.div(
        [
          attribute.class(
            "absolute -bottom-40 -left-40 h-96 w-96 rounded-full bg-amber-100/60 blur-3xl",
          ),
        ],
        [],
      ),
    ],
  )
}

fn footer_view() -> Element(Msg) {
  html.footer(
    [
      attribute.class(
        "mt-auto flex items-center justify-center gap-2 pt-16 text-center text-xs text-stone-400",
      ),
    ],
    [
      html.text("Built for decisive action. Just not today."),
      html.a(
        [
          attribute.href("https://github.com/bmehder/gleam-maybe-list"),
          attribute.target("_blank"),
          attribute.rel("noreferrer"),
          attribute.aria_label("View Maybe List on GitHub"),
          attribute.class(
            "rounded-md p-1 text-stone-300 transition hover:bg-stone-100 hover:text-stone-600 focus:outline-none focus:ring-2 focus:ring-lime-400",
          ),
        ],
        [github_icon()],
      ),
    ],
  )
}

fn github_icon() -> Element(Msg) {
  html.svg(
    [
      attribute.width(16),
      attribute.height(16),
      attribute.attribute("viewBox", "0 0 24 24"),
      attribute.attribute("fill", "currentColor"),
      attribute.aria_hidden(True),
    ],
    [
      svg.path([
        attribute.attribute(
          "d",
          "M12 .7a11.3 11.3 0 0 0-3.6 22c.6.1.8-.2.8-.5v-2c-3.3.7-4-1.4-4-1.4-.5-1.3-1.2-1.6-1.2-1.6-1-.7.1-.7.1-.7 1.1.1 1.7 1.1 1.7 1.1 1 1.7 2.7 1.2 3.4.9.1-.7.4-1.2.8-1.5-2.7-.3-5.5-1.4-5.5-6a4.7 4.7 0 0 1 1.2-3.2 4.4 4.4 0 0 1 .1-3.2s1-.3 3.3 1.2a11.4 11.4 0 0 1 6 0c2.3-1.5 3.3-1.2 3.3-1.2a4.4 4.4 0 0 1 .1 3.2 4.7 4.7 0 0 1 1.2 3.2c0 4.6-2.8 5.7-5.5 6 .4.4.8 1.1.8 2.2v3.3c0 .3.2.6.8.5A11.3 11.3 0 0 0 12 .7Z",
        ),
      ]),
    ],
  )
}
