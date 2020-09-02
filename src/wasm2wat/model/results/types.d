module wasm2wat.model.results.types;

import std.typecons : Nullable;

// ==========================================

struct ResizableLimits
{
  int initial;
  Nullable!int maximum;
}

// ==========================================

@ImportEntryType @BinaryReaderResult struct TableType
{
  int elementType;
  ResizableLimits limits;
}

// ==========================================

@ImportEntryType @BinaryReaderResult struct MemoryType
{
  ResizableLimits limits;
  bool _shared;
}

// ==========================================

@ImportEntryType struct GlobalType
{
  int contentType;
  int mutability;
}

@BinaryReaderResult struct GlobalVariable
{
  GlobalType type;
}
