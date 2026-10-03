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
      assert_eq(c.dot_size, 1)
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
