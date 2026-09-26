import lustre
import maybelist/web
import timetravel
import timetravel/internal/inspect

pub fn main() -> Nil {
  let app =
    timetravel.application_with_formatters(
      web.init,
      web.update,
      web.view,
      timetravel.Formatters(
        message_name: inspect.name,
        format_message: inspect.value,
        format_model: format_model,
      ),
    )
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

// The compiler may rename this constructor to Model2 in JavaScript when more
// than one module defines Model. Keep the public demo's app model label stable.
fn format_model(model: web.Model) -> String {
  case inspect.value(model) {
    "Model2(" <> fields -> "Model(" <> fields
    formatted -> formatted
  }
}
