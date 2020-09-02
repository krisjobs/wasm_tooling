module wasm2wat.model.enums.types;

// ==========================================

enum ValueType
{
  I32 = 0x7f,
  I64 = 0x7e,
  F32 = 0x7d,
  F64 = 0x7c,
}

enum BlockType
{
  unspecified = 0,
  i32 = -0x01,
  i64 = -0x02,
  f32 = -0x03,
  f64 = -0x04,
  v128 = -0x05,
  anyfunc = -0x10,
  anyref = -0x11,
  func = -0x20,
  empty_block_type = -0x40,
}
