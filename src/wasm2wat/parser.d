module wasm2wat.parser;

immutable string watPlaceholder = "(module
  (type $t0 (func (param i32 i32) (result i32)))
  (func $addTwo (export \"addTwo\") (type $t0) (param $p0 i32) (param $p1 i32) (result i32)
    (i32.add
      (local.get $p0)
      (local.get $p1))))";

string wasm2Wat(const ubyte[] wasm) @safe pure
{
  wasm = null;
  return watPlaceholder;
}

// string _wasm2Wat(const ubyte[] wasm) @safe pure
// {
//     return watPlaceholder;
// }
