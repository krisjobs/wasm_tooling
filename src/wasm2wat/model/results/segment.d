module wasm2wat.model.results.segment;

// ==========================================

@BinaryReaderResult struct SourceMappingURL
{
  ubyte[] url;
}

// ==========================================

enum SegmentFlags
{
  IsPassive = 1,
  HasTableIndex = 2,
  FunctionsAsElements = 4,
}

// ==========================================

@BinaryReaderResult struct ElementSegment
{
  int index;
}

@BinaryReaderResult struct ElementSegmentBody
{
  uint[] elements;
  int elementType;
  bool asElements;
}

// ==========================================

@BinaryReaderResult struct DataSegment
{
  int index;
}

@BinaryReaderResult struct DataSegmentBody
{
  ubyte[] data;
}
