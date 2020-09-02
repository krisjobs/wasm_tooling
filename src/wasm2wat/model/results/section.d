module wasm2wat.model.results.section;

import std.typecons : Nullable;

enum SectionCode
{
  UNKNOWN = -1,
  CUSTOM,
  TYPE, // Function signature declarations
  IMPORT, // Import declarations
  FUNCTION, // Function declarations
  TABLE, // Indirect function table and other tables
  MEMORY, // Memory attributes
  GLOBAL, // Global declarations
  EXPORT, // Exports
  START, // Start function declaration
  ELEMENT, // Elements section
  CODE, // Function bodies (code)
  DATA, // Data segments
}

// ==========================================

@BinaryReaderResult struct SectionInformation
{
  SectionCode id;
  ubyte[] name;
}

// ==========================================

@BinaryReaderResult struct ModuleHeader
{
  int magicNumber;
  int _version;
}
