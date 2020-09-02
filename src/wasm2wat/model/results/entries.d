module wasm2wat.model.results.entries;

import std.typecons : Nullable;

// ==========================================

enum ExternalKind
{
  Function = 0,
  Table = 1,
  Memory = 2,
  Global = 3,
}

struct Naming
{
  int index;
  ubyte[] name;
}

// ==========================================

private struct ImportEntryType
{
}

@BinaryReaderResult struct ImportEntry(T = FunctionType)
{
  invariant
  {
    assert(hasUDA!(T, ImportEntryType));
  }

  ubyte[] _module;
  ubyte[] field;
  ExternalKind kind;
  Nullable!int funcTypeIndex;
  T type;
}

// ==========================================

@BinaryReaderResult struct ExportEntry
{
  ubyte[] field;
  ExternalKind kind;
  int index;
}

// ==========================================

enum NameType
{
  Module = 0,
  Function = 1,
  Local = 2,
}

@BinaryReaderResult struct NameEntry
{
  NameType type;
}

// ==========================================

struct ModuleNameEntry
{
  NameEntry ne;
  byte[] moduleName;

  alias ne this;
}

// ==========================================

struct Locals
{
  int count;
  int type;
}

@BinaryReaderResult struct FunctionEntry
{
  int typeIndex;
}

struct FunctionNameEntry
{
  NameEntry ne;
  Naming[] names;

  alias ne this;
}

@ImportEntryType @BinaryReaderResult struct FunctionType
{
  int form;
  byte[] params;
  byte[] returns;
}

@BinaryReaderResult struct FunctionInformation
{
  Locals[] locals;
}

// ==========================================

struct LocalName
{
  int index;
  Naming[] locals;
}

struct LocalNameEntry
{
  NameEntry ne;
  LocalName[] funcs;

  alias ne this;
}

// ==========================================

@BinaryReaderResult struct StartEntry
{
  int index;
}

// ==========================================

enum LinkingType
{
  StackPointer = 1
}

@BinaryReaderResult struct LinkingEntry
{
  LinkingType type;
  Nullable!int index;
}
