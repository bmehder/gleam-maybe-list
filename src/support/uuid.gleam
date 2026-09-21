//// Browser UUID generation kept outside the pure Maybe List domain.

@external(javascript, "./uuid_ffi.mjs", "v4")
pub fn v4() -> String
