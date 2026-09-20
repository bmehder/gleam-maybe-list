import lustre
import maybelist/web
import timetravel

pub fn main() -> Nil {
  let app = timetravel.application(web.init, web.update, web.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
