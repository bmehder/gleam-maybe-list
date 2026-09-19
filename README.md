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

The app loads once during initialization and saves only after successful domain
changes. Invalid or unavailable storage falls back safely to the example list.

## Run it locally

```sh
gleam run -m lustre/dev start
```

Then open <http://localhost:1234>.

## Run with time travel

The optional development entry point wraps the app with a time-travel inspector:

```sh
gleam run -m lustre/dev start maybelist_dev
```

Open the panel from the **Time Travel** button in the lower-right corner. Draft
typing, persistence responses, and every other application message are recorded
alongside the model they produce. Effects are not run while inspecting past
state. The normal `maybelist` entry point does not include the debugger.

### Add time travel to another Lustre app

Time travel is distributed as a tagged Git dependency. Add it to the
application's `gleam.toml`:

```toml
[dependencies]
timetravel = {
  git = "https://github.com/bmehder/timetravel.git",
  ref = "v0.1.0",
}
```

Keep the application's normal production entry point unchanged. Add a separate
development entry point, such as `src/my_app_dev.gleam`:

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

The inspector uses Tailwind classes. Add `src/my_app_dev.css` alongside the
development entry and explicitly include the dependency's source:

```css
@import "tailwindcss";
@source "../build/packages/timetravel/src";
```

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

For local, unminified development, `timetravel.application` can inspect values
automatically. A minified deployment must instead use
`timetravel.application_with_formatters` with application-owned functions that
pattern match on messages and models. Maybe List's `maybelist_dev` entry shows a
complete example. These formatters keep names such as `UpdateDraft` and `Model`
stable when JavaScript minification renames compiled Gleam classes.

## Check and build

```sh
gleam test
gleam run -m lustre/dev build
```
