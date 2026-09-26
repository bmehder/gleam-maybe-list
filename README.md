# Maybe List

A low-pressure list for things you might do, someday. Built with Gleam, Lustre,
and Tailwind CSS.

## Architecture

The business rules live in `src/maybelist/list.gleam`. They are pure Gleam and
have no dependency on Lustre, browser APIs, or persistence. The Lustre adapter
in `src/maybelist/web.gleam` owns only UI state and delegates every list change
to the domain module. A future HTTP API can use the same domain directly.

The versioned JSON format lives in `src/maybelist/serialization.gleam`, while the
generic `src/support/local_storage.gleam` module bridges Varasto to Lustre
effects without knowing anything about Maybe List. The same serialized format can
later support import/export and an API.

The app loads once during initialization. Each `update` branch that changes the
list explicitly returns a save effect, so the persistence behavior is visible
beside the model change. A small `save_to_local_storage` helper keeps the storage
configuration in one place. Invalid or unavailable storage falls back safely to
the example list.

Application messages describe events in subject-verb-object form, such as
`UserSubmittedNewItem` and `LocalStorageReturnedItemList`. Editing state keeps
the item ID and draft together as `Option(Editing)`, so the model cannot contain
an editing ID without its corresponding draft.

## Run it locally

```sh
gleam run -m lustre/dev start
```

Then open <http://localhost:1234>.

## Run with time travel

The optional development entry point at `dev/maybelist_dev.gleam` wraps the app
with a time-travel inspector. Its location keeps `timetravel` as a development
dependency and out of production builds.

```sh
gleam run -m lustre/dev start maybelist_dev
```

Open the panel from the **Time Travel** button in the lower-right corner. Draft
typing, persistence responses, and every other application message are recorded
alongside the model they produce. Effects are not run while inspecting past
state. The normal `maybelist` entry point does not include the debugger.

### Add time travel to another Lustre app

Add time travel as a development dependency:

```sh
gleam add --dev timetravel
```

This adds it to the application's `gleam.toml`:

```toml
[dev_dependencies]
timetravel = ">= 0.2.2 and < 1.0.0"
```

Keep the application's normal production entry point unchanged. Add a separate
development entry point, such as `dev/my_app_dev.gleam`:

```gleam
import lustre
import my_app/web
import timetravel

pub fn main() -> Nil {
  let app = timetravel.application(web.init, web.update, web.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
```

Replace `my_app/web` with the module containing the application's existing
`init`, `update`, and `view` functions. No changes to those functions or to the
application's message and model types are required.

The inspector injects its own prefixed CSS, so it does not require Tailwind or
any stylesheet configuration in the host application.

Start the wrapped development application with:

```sh
gleam run -m lustre/dev start my_app_dev
```

The wrapper records every application message and the model returned by its
update function, up to the latest 100 transitions. Timeline entries are
numbered and clickable. Selecting an earlier entry displays its recorded model
and temporarily prevents new application messages from being processed. **Back
to the Future** returns to the latest state.

This is snapshot playback: navigating the timeline restores recorded models;
it does not rerun messages or repeat HTTP requests, persistence writes, or other
effects. Keeping the debugger in a separate entry point also keeps it out of the
production bundle.

`timetravel.application` inspects values automatically in unminified builds.
JavaScript minifiers rename compiled Gleam constructors, so a minified debugger
build instead needs `timetravel.application_with_formatters` and
application-owned pattern-matching formatters. Maybe List deploys its development
entry unminified and supplies only a small demo formatter that keeps the
top-level label as `Model` instead of a compiler-generated name such as `Model2`.
Its normal production entry can still be minified.

## Check and build

```sh
gleam test
gleam run -m lustre/dev build
```
