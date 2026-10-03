///|
/// 配置对象的 JSON 序列化 / 反序列化，用于 CLI 与脚本持久化水印参数。
///
/// 注意：`seed`（Int64）与 `color`（Int）在 JSON 中表示为 Number；
/// Int64 超过 2^53 时会丢失精度（水印种子常规取值远小于该值，可忽略）。

///|
fn text_cfg_to_json(cfg : TextConfig) -> Json {
  Json::object(
    Map([
      ("text", Json::string(cfg.text)),
      ("x", Json::number(cfg.x.to_double())),
      ("y", Json::number(cfg.y.to_double())),
      ("font_size", Json::number(cfg.font_size.to_double())),
      ("opacity", Json::number(cfg.opacity)),
      ("angle", Json::number(cfg.angle)),
      ("color", Json::number(cfg.color.to_double())),
      ("font", Json::string(cfg.font)),
    ]),
  )
}

///|
/// 将 `TextConfig` 序列化为 JSON 字符串。
pub fn text_config_to_json(cfg : TextConfig) -> String {
  Json::stringify(text_cfg_to_json(cfg))
}

///|
/// 从 JSON 字符串解析 `TextConfig`；字段缺失或格式错误返回 `None`。
pub fn text_config_from_json(s : String) -> TextConfig? {
  text_cfg_from_obj(@json.parse(s)) catch {
    _ => None
  }
}

///|
fn text_cfg_from_obj(j : Json) -> TextConfig? {
  match j {
    Object(m) => {
      let font = match j_str(m, "font") {
        Some(f) => f
        None => "ascii5x7" // 向后兼容：旧 JSON 无 font 字段
      }
      match
        (
          j_str(m, "text"),
          j_int(m, "x"),
          j_int(m, "y"),
          j_int(m, "font_size"),
          j_dbl(m, "opacity"),
          j_dbl(m, "angle"),
          j_int(m, "color"),
        ) {
        (
          Some(text),
          Some(x),
          Some(y),
          Some(font_size),
          Some(opacity),
          Some(angle),
          Some(color),
        ) => Some({ text, x, y, font_size, opacity, angle, color, font, })
        _ => None
      }
    }
    _ => None
  }
}

///|
/// 将 `DotConfig` 序列化为 JSON 字符串。
pub fn dot_config_to_json(cfg : DotConfig) -> String {
  Json::stringify(
    Json::object(
      Map([
        ("density", Json::number(cfg.density)),
        ("dot_size", Json::number(cfg.dot_size.to_double())),
        ("seed", Json::number(cfg.seed.to_double())),
        ("opacity", Json::number(cfg.opacity)),
        ("grid_offset_x", Json::number(cfg.grid_offset_x.to_double())),
        ("grid_offset_y", Json::number(cfg.grid_offset_y.to_double())),
      ]),
    ),
  )
}

///|
/// 从 JSON 字符串解析 `DotConfig`；字段缺失或格式错误返回 `None`。
pub fn dot_config_from_json(s : String) -> DotConfig? {
  dot_cfg_from_obj(@json.parse(s)) catch {
    _ => None
  }
}

///|
fn dot_cfg_from_obj(j : Json) -> DotConfig? {
  match j {
    Object(m) =>
      match
        (
          j_dbl(m, "density"),
          j_int(m, "dot_size"),
          j_i64(m, "seed"),
          j_dbl(m, "opacity"),
          j_int(m, "grid_offset_x"),
          j_int(m, "grid_offset_y"),
        ) {
        (
          Some(density),
          Some(dot_size),
          Some(seed),
          Some(opacity),
          Some(grid_offset_x),
          Some(grid_offset_y),
        ) =>
          Some({
            density,
            dot_size,
            seed,
            opacity,
            grid_offset_x,
            grid_offset_y,
          })
        _ => None
      }
    _ => None
  }
}

///|
/// 将 `TiledConfig` 序列化为 JSON 字符串。
pub fn tiled_config_to_json(cfg : TiledConfig) -> String {
  Json::stringify(
    Json::object(
      Map([
        ("text", Json::string(cfg.text)),
        ("font_size", Json::number(cfg.font_size.to_double())),
        ("spacing_x", Json::number(cfg.spacing_x.to_double())),
        ("spacing_y", Json::number(cfg.spacing_y.to_double())),
        ("opacity", Json::number(cfg.opacity)),
        ("color", Json::number(cfg.color.to_double())),
        ("font", Json::string(cfg.font)),
      ]),
    ),
  )
}

///|
/// 从 JSON 字符串解析 `TiledConfig`；字段缺失或格式错误返回 `None`。
pub fn tiled_config_from_json(s : String) -> TiledConfig? {
  tiled_cfg_from_obj(@json.parse(s)) catch {
    _ => None
  }
}

///|
fn tiled_cfg_from_obj(j : Json) -> TiledConfig? {
  match j {
    Object(m) => {
      let font = match j_str(m, "font") {
        Some(f) => f
        None => "ascii5x7" // 向后兼容：旧 JSON 无 font 字段
      }
      match
        (
          j_str(m, "text"),
          j_int(m, "font_size"),
          j_int(m, "spacing_x"),
          j_int(m, "spacing_y"),
          j_dbl(m, "opacity"),
          j_int(m, "color"),
        ) {
        (
          Some(text),
          Some(font_size),
          Some(spacing_x),
          Some(spacing_y),
          Some(opacity),
          Some(color),
        ) => Some({ text, font_size, spacing_x, spacing_y, opacity, color, font, })
        _ => None
      }
    }
    _ => None
  }
}

///|
fn j_str(m : Map[String, Json], k : String) -> String? {
  match m.get(k) {
    Some(j) =>
      match j {
        String(sv) => Some(sv)
        _ => None
      }
    _ => None
  }
}

///|
fn j_int(m : Map[String, Json], k : String) -> Int? {
  match m.get(k) {
    Some(j) =>
      match j {
        Number(d, ..) => Some(d.to_int())
        _ => None
      }
    _ => None
  }
}

///|
fn j_dbl(m : Map[String, Json], k : String) -> Double? {
  match m.get(k) {
    Some(j) =>
      match j {
        Number(d, ..) => Some(d)
        _ => None
      }
    _ => None
  }
}

///|
fn j_i64(m : Map[String, Json], k : String) -> Int64? {
  match m.get(k) {
    Some(j) =>
      match j {
        Number(d, ..) => Some(d.to_int64())
        _ => None
      }
    _ => None
  }
}
