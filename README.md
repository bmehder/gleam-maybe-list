# Maybe List

A low-pressure list for things you might do, someday. Built with Gleam, Lustre,
and Tailwind CSS.

## Architecture

The business rules live in `src/maybelist/list.gleam`. They are pure Gleam and
have no dependency on Lustre, browser APIs, or persistence. The Lustre adapter
in `src/maybelist/web.gleam` owns only UI state and delegates every list change
to the domain module. A future HTTP API can use the same domain directly.

The web app uses `lustre.application` and managed effects from the start, ready
for local storage and import/export without changing the architecture.

## Run it locally

```sh
gleam run -m lustre/dev start
```

Then open <http://localhost:1234>.

## Check and build

```sh
gleam test
gleam run -m lustre/dev build
```
# gleam-maybe-list
