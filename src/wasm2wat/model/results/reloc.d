module wasm2wat.model.results.reloc;

import wasm2wat.model.section.code : SectionCode;

import std.typecons : Nullable;

// ==========================================

enum RelocType {
  FunctionIndex_LEB = 0,
  TableIndex_SLEB = 1,
  TableIndex_I32 = 2,
  GlobalAddr_LEB = 3,
  GlobalAddr_SLEB = 4,
  GlobalAddr_I32 = 5,
  TypeIndex_LEB = 6,
  GlobalIndex_LEB = 7,
}

// ==========================================

@BinaryReaderResult
struct RelocHeader {
  SectionCode id;
  ubyte[] name;
}

@BinaryReaderResult
struct RelocEntry {
  RelocType type;
  int offset;
  int index;
  Nullable!int addend;
}
