///|
test "text config json roundtrip" {
  let cfg = TextConfig::new("HELLO", 10, 20, 2, 0.5, 0xFF00_00FF)
  let s = text_config_to_json(cfg)
  let back = text_config_from_json(s)
  match back {
    Some(c) => {
      assert_eq(c.text, "HELLO")
      assert_eq(c.x, 10)
      assert_eq(c.y, 20)
      assert_eq(c.font_size, 2)
      assert_eq(c.opacity, 0.5)
      assert_eq(c.color, 0xFF00_00FF)
    }
    None => assert_true(false)
  }
}

///|
test "dot config json roundtrip" {
  let cfg = DotConfig::default()
  let s = dot_config_to_json(cfg)
  let back = dot_config_from_json(s)
  match back {
    Some(c) => {
      assert_eq(c.density, 0.05)
      assert_eq(c.dot_size, 3)
      assert_eq(c.seed, 42L)
      assert_eq(c.opacity, 1.0)
      assert_eq(c.grid_offset_x, 0)
      assert_eq(c.grid_offset_y, 0)
    }
    None => assert_true(false)
  }
}

///|
test "tiled config json roundtrip" {
  let cfg = TiledConfig::new("WM", 1, 3, 5, 0.8, 0xFF00_00FF)
  let s = tiled_config_to_json(cfg)
  let back = tiled_config_from_json(s)
  match back {
    Some(c) => {
      assert_eq(c.text, "WM")
      assert_eq(c.font_size, 1)
      assert_eq(c.spacing_x, 3)
      assert_eq(c.spacing_y, 5)
      assert_eq(c.opacity, 0.8)
      assert_eq(c.color, 0xFF00_00FF)
    }
    None => assert_true(false)
  }
}

///|
test "json parse error returns None" {
  assert_true(text_config_from_json("{not json") is None)
  assert_true(dot_config_from_json("") is None)
  assert_true(tiled_config_from_json("123") is None)
}

///|
test "tiled config cjk16 roundtrip (font field)" {
  let cfg = TiledConfig::new("直播间", 3, 60, 40, 0.5, 0xFF00_00FF, font="cjk16")
  let s = tiled_config_to_json(cfg)
  let back = tiled_config_from_json(s)
  match back {
    Some(b) => {
      assert_eq(b.font, "cjk16")
      assert_eq(b.text, "直播间")
    }
    None => assert_true(false)
  }
}

///|
test "tiled config old json defaults to ascii5x7" {
  // 旧版 JSON 无 font 字段 → 默认 ascii5x7（向后兼容）
  let s = "{\"text\":\"LIVE\",\"font_size\":2,\"spacing_x\":40,\"spacing_y\":40,\"opacity\":1.0,\"color\":4294967295}"
  let back = tiled_config_from_json(s)
  match back {
    Some(b) => assert_eq(b.font, "ascii5x7")
    None => assert_true(false)
  }
}

///|
test "text config json tolerates missing angle field" {
  // 早期版本 JSON 无 angle 字段：应默认 0.0 解析成功（与 font 缺省兼容一致）
  let old = "{\"text\":\"x\",\"x\":0,\"y\":0,\"font_size\":1,\"opacity\":0.5,\"color\":255}"
  match text_config_from_json(old) {
    Some(cfg) => {
      assert_eq(cfg.angle, 0.0)
      assert_eq(cfg.font, "ascii5x7")
    }
    None => assert_true(false)
  }
}
