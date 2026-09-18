import lustre
import maybelist/web

pub fn main() -> Nil {
  let app = lustre.application(web.init, web.update, web.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
