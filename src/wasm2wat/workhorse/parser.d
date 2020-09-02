module wasm2wat.workhorse;

import wasm2wat.model;

import std.typecons : Nullable;

struct BinaryReaderResult(T = ubyte[])
{
private:
  T value;

  invariant
  {
    assert(hasUDA!(T, BinaryReaderResult));
  }

  alias value this;
}

struct BinaryReaderData
{
  BinaryReaderState state;
  BinaryReaderResult result;
}

enum BinaryReaderState
{
  ERROR = -1,
  INITIAL = 0,
  BEGIN_WASM = 1,
  END_WASM = 2,
  BEGIN_SECTION = 3,
  END_SECTION = 4,
  SKIPPING_SECTION = 5,
  READING_SECTION_RAW_DATA = 6,
  SECTION_RAW_DATA = 7,

  TYPE_SECTION_ENTRY = 11,
  IMPORT_SECTION_ENTRY = 12,
  FUNCTION_SECTION_ENTRY = 13,
  TABLE_SECTION_ENTRY = 14,
  MEMORY_SECTION_ENTRY = 15,
  GLOBAL_SECTION_ENTRY = 16,
  EXPORT_SECTION_ENTRY = 17,
  DATA_SECTION_ENTRY = 18,
  NAME_SECTION_ENTRY = 19,
  ELEMENT_SECTION_ENTRY = 20,
  LINKING_SECTION_ENTRY = 21,
  START_SECTION_ENTRY = 22,

  BEGIN_INIT_EXPRESSION_BODY = 25,
  INIT_EXPRESSION_OPERATOR = 26,
  END_INIT_EXPRESSION_BODY = 27,

  BEGIN_FUNCTION_BODY = 28,
  READING_FUNCTION_HEADER = 29,
  CODE_OPERATOR = 30,
  END_FUNCTION_BODY = 31,
  SKIPPING_FUNCTION_BODY = 32,

  BEGIN_ELEMENT_SECTION_ENTRY = 33,
  ELEMENT_SECTION_ENTRY_BODY = 34,
  END_ELEMENT_SECTION_ENTRY = 35,

  BEGIN_DATA_SECTION_ENTRY = 36,
  DATA_SECTION_ENTRY_BODY = 37,
  END_DATA_SECTION_ENTRY = 38,

  BEGIN_GLOBAL_SECTION_ENTRY = 39,
  END_GLOBAL_SECTION_ENTRY = 40,

  RELOC_SECTION_HEADER = 41,
  RELOC_SECTION_ENTRY = 42,

  SOURCE_MAPPING_URL = 43,
}

class BinaryReader
{
  // ===================== PRIVATE} =====================

  private ubyte[] _data;

  private int _pos;
  private int _length;
  private bool _eof;

  private int _sectionEntriesLeft;
  private SectionCode _sectionId;
  private DataRange _sectionRange;
  private DataRange _functionRange;
  private int _segmentFlags;

  // ===================== PUBLIC =====================

  public BinaryReaderState state;
  public BinaryReaderResult result;
  public Error error;

  // ===================== CONSTRUCTOR =====================

  this()
  {
    this._data = null;
    this._pos = 0;
    this._length = 0;
    this._eof = false;
    this.state = BinaryReaderState.INITIAL;
    this.result = null;
    this.error = null;
    this._sectionEntriesLeft = 0;
    this._sectionId = SectionCode.Unknown;
    this._sectionRange = null;
    this._functionRange = null;
  }

  // ===================== GET =====================

  public ubyte[] getData()
  {
    return this._data;
  }

  public int getPosition()
  {
    return this._pos;
  }

  public int getLength()
  {
    return this._length;
  }

  public OperatorInformation getCurrentOperationInformation()
  {
    if (OperatorInformation oi = cast(OperatorInformation) this._data)
    {
      return oi;
    }
    else
    {
      throw new StringException("Binary data does not contain a valid operator");
    }
  }

  public SectionInformation getCurrentSection()
  {
    if (SectionInformation si = cast(SectionInformation) this._data)
    {
      return si;
    }
    else
    {
      throw new StringException("Binary data does not contain a valid section");
    }
  }

  public FunctionInformation getCurrentFunction()
  {
    if (FunctionInformation fi = cast(FunctionInformation) this._data)
    {
      return fi;
    }
    else
    {
      throw new StringException("Binary data does not contain a valid function");
    }
  }

  // ===================== HAS =====================

  private bool hasBytes(int n)
  {
    return this._pos + n <= this._length;
  }

  public bool hasMoreBytes()
  {
    return this.hasBytes(1);
  }

  private bool hasautoIntBytes()
  {
    const auto pos = this._pos;
    while (pos < this._length)
    {
      if ((this._data[pos++] & 0x80) == 0)
        return true;
    }
    return false;
  }

  private bool hasStringBytes()
  {
    if (!this.hasautoIntBytes())
      return false;
    const auto pos = this._pos;
    auto length = this.readVarUint32() >>> 0;
    auto result = this.hasBytes(length);
    this._pos = pos;
    return result;
  }

  private bool hasSectionPayload()
  {
    return this.hasBytes(this._sectionRange.end - this._pos);
  }

  // ===================== SET =====================

  alias nullableBool = Nullable!bool;

  public void setData(ArrayBuffer buffer, int pos, int length, nullableBool eof)
  {
    auto posDelta = pos - this._pos;
    this._data = new ubyte[buffer];
    this._pos = pos;
    this._length = length;
    this._eof = eof.isNull() ? true : eof;
    if (this._sectionRange)
      this._sectionRange.offset(posDelta);
    if (this._functionRange)
      this._functionRange.offset(posDelta);
  }

  // ===================== PEEK =====================

  private int peekInt32()
  {
    const auto b1 = this._data[this._pos];
    const auto b2 = this._data[this._pos + 1];
    const auto b3 = this._data[this._pos + 2];
    const auto b4 = this._data[this._pos + 3];
    return b1 | (b2 << 8) | (b3 << 16) | (b4 << 24);
  }

  private uint peekUint32()
  {
    return this.peekInt32();
  }

  // ===================== READ =====================

  private ubyte readUint8()
  {
    return this._data[this._pos++];
  }

  private ushort readUint16()
  {
    const auto b1 = this._data[this._pos++];
    const auto b2 = this._data[this._pos++];
    return b1 | (b2 << 8);
  }

  private int readInt32()
  {
    const auto b1 = this._data[this._pos++];
    const auto b2 = this._data[this._pos++];
    const auto b3 = this._data[this._pos++];
    const auto b4 = this._data[this._pos++];
    return b1 | (b2 << 8) | (b3 << 16) | (b4 << 24);
  }

  private uint readUint32()
  {
    return this.readInt32();
  }

  private ubyte readVarUint1()
  {
    return this.readUint8();
  }

  private ubyte readVarInt7()
  {
    return (this.readUint8() << 25) >> 25;
  }

  private ubyte readVarUint7()
  {
    return this.readUint8();
  }

  private int readVarInt32()
  {
    auto _result = 0;
    auto shift = 0;
    while (true)
    {
      const byte _byte = this.readUint8();
      _result |= (_byte & 0x7f) << shift;
      shift += 7;
      if ((_byte & 0x80) == 0)
        break;
    }
    if (shift >= 32)
      return _result;
    const auto ashift = 32 - shift;
    return (_result << ashift) >> ashift;
  }

  private uint readVarUint32()
  {
    auto _result = 0;
    auto shift = 0;
    while (true)
    {
      const byte _byte = this.readUint8();
      _result |= (_byte & 0x7f) << shift;
      shift += 7;
      if ((_byte & 0x80) == 0)
        break;
    }
    return _result;
  }

  private long readVarInt64()
  {
    auto _result = new Uint8Array(8);
    auto i = 0;
    auto c = 0;
    auto shift = 0;
    while (true)
    {
      const auto _byte = this.readUint8();
      c |= (_byte & 0x7f) << shift;
      shift += 7;
      if (shift > 8)
      {
        _result[i++] = c & 0xff;
        c >>= 8;
        shift -= 8;
      }

      if ((_byte & 0x80) == 0)
        break;
    }
    const auto ashift = 32 - shift;
    c = (c << ashift) >> ashift;
    while (i < 8)
    {
      _result[i++] = c & 0xff;
      c >>= 8;
    }
    return new Int64(_result);
  }

  private ubyte[] readStringBytes()
  {
    const auto length = this.readVarUint32() >>> 0;
    return this.readBytes(length);
  }

  private ubyte[] readBytes(int length)
  {
    const auto _result = this._data.subarray(this._pos, this._pos + length);
    this._pos += length;
    return new Uint8Array(_result); // making a clone of the data
  }

  private FunctionType readFuncType()
  {
    const auto form = this.readVarInt7();
    auto paramCount = this.readVarUint32() >>> 0;
    auto paramTypes = new Int8Array(paramCount);
    for (auto i = 0; i < paramCount; i++)
      paramTypes[i] = this.readVarInt7();
    auto returnCount = this.readVarUint1();
    auto returnTypes = new Int8Array(returnCount);
    for (auto i = 0; i < returnCount; i++)
      returnTypes[i] = this.readVarInt7();
    return FunctionType(form, paramTypes, returnTypes);
  }

  private ResizableLimits readResizableLimits(bool maxPresent)
  {
    const auto initial = this.readVarUint32() >>> 0;
    int maximum;
    if (maxPresent)
    {
      maximum = this.readVarUint32() >>> 0;
    }

    return ResizableLimits(initial, maximum);
  }

  private TableType readTableType()
  {
    const auto elementType = this.readVarInt7();
    const auto flags = this.readVarUint32() >>> 0;
    const auto limits = this.readResizableLimits(!!(flags & 0x01));

    return TableType(elementType, limits);
  }

  private MemoryType readMemoryType()
  {
    const auto flags = this.readVarUint32() >>> 0;
    auto _shared = !!(flags & 0x02);
    const auto limits = this.readResizableLimits(!!(flags & 0x01));

    return MemoryType(limits, _shared);
  }

  private GlobalType readGlobalType()
  {
    if (!this.hasautoIntBytes())
    {
      return null;
    }
    const auto pos = this._pos;
    const auto contentType = this.readVarInt7();
    if (!this.hasautoIntBytes())
    {
      this._pos = pos;
      return null;
    }
    const auto mutability = this.readVarUint1();
    return GlobalType(contentType, mutability);
  }

  private bool readTypeEntry()
  {
    if (this._sectionEntriesLeft == 0)
    {
      this.skipSection();
      return this.read();
    }

    this.state = BinaryReaderState.TYPE_SECTION_ENTRY;
    this.result = this.readFuncType();
    this._sectionEntriesLeft--;
    return true;
  }

  private bool readImportEntry()
  {
    if (this._sectionEntriesLeft == 0)
    {
      this.skipSection();
      return this.read();
    }

    this.state = BinaryReaderState.IMPORT_SECTION_ENTRY;

    const auto _module = this.readStringBytes();
    const auto field = this.readStringBytes();
    const auto kind = this.readUint8();

    switch (kind)
    {
    case ExternalKind.Function:
      auto funcTypeIndex = this.readVarUint32() >>> 0;
      this.result = ImportEntry(_module, field, kind, funcTypeIndex, null);
      break;
    case ExternalKind.Table:
      auto type = this.readTableType();
      this.result = ImportEntry!TableType(_module, field, kind, null, type);
      break;
    case ExternalKind.Memory:
      auto type = this.readMemoryType();
      this.result = ImportEntry!MemoryType(_module, field, kind, null, type);
      break;
    case ExternalKind.Global:
      auto type = this.readGlobalType();
      this.result = ImportEntry!GlobalType(_module, field, kind, null, type);
      break;
    }

    this._sectionEntriesLeft--;
    return true;
  }

  private bool readExportEntry()
  {
    if (this._sectionEntriesLeft == 0)
    {
      this.skipSection();
      return this.read();
    }

    this.state = BinaryReaderState.EXPORT_SECTION_ENTRY;

    auto field = this.readStringBytes();
    auto kind = this.readUint8();
    auto index = this.readVarUint32() >>> 0;

    this.result = ExportEntry(field, kind, index);

    this._sectionEntriesLeft--;
    return true;
  }

  private bool readFunctionEntry()
  {
    if (this._sectionEntriesLeft == 0)
    {
      this.skipSection();
      return this.read();
    }

    this.state = BinaryReaderState.FUNCTION_SECTION_ENTRY;

    auto typeIndex = this.readVarUint32() >>> 0;

    this.result = FunctionEntry(typeIndex);

    this._sectionEntriesLeft--;
    return true;
  }

  private bool readTableEntry()
  {
    if (this._sectionEntriesLeft == 0)
    {
      this.skipSection();
      return this.read();
    }

    this.state = BinaryReaderState.TABLE_SECTION_ENTRY;

    this.result = this.readTableType();

    this._sectionEntriesLeft--;
    return true;
  }

  private bool readMemoryEntry()
  {
    if (this._sectionEntriesLeft == 0)
    {
      this.skipSection();
      return this.read();
    }

    this.state = BinaryReaderState.MEMORY_SECTION_ENTRY;

    this.result = this.readMemoryType();

    this._sectionEntriesLeft--;
    return true;
  }

  private bool readGlobalEntry()
  {
    if (this._sectionEntriesLeft == 0)
    {
      this.skipSection();
      return this.read();
    }

    const auto globalType = this.readGlobalType();
    if (!globalType)
    {
      this.state = BinaryReaderState.GLOBAL_SECTION_ENTRY;
      return false;
    }

    this.state = BinaryReaderState.BEGIN_GLOBAL_SECTION_ENTRY;
    this.result = Globalautoiable(globalType);

    this._sectionEntriesLeft--;
    return true;
  }

  private bool readElementEntry()
  {
    if (this._sectionEntriesLeft == 0)
    {
      this.skipSection();
      return this.read();
    }

    if (!this.hasautoIntBytes())
    {
      this.state = BinaryReaderState.ELEMENT_SECTION_ENTRY;
      return false;
    }
    const flags = this.readVarUint7();
    let tableIndex = 0;
    if (flags & SegmentFlags.HasTableIndex)
    {
      tableIndex = this.readVarUint32();
    }

    this.state = BinaryReaderState.BEGIN_ELEMENT_SECTION_ENTRY;

    this.result = ElementSegment(tableIndex);

    this._sectionEntriesLeft--;
    this._segmentFlags = flags;
    return true;
  }

  private bool readElementEntryBody()
  {
    let funcType = Type.unspecified;
    const pos = this._pos;
    if (this._segmentFlags & (SegmentFlags.IsPassive | SegmentFlags.HasTableIndex))
    {
      if (!this.hasMoreBytes())
        return false;
      funcType = this.readVarInt7();
    }

    if (!this.hasautoIntBytes())
    {
      this._pos = pos;
      return false;
    }
    const numElemements = this.readVarUint32();
    const elements = new Uint32Array(numElemements);
    for (let i = 0; i < numElemements; i++)
    {
      if (this._segmentFlags & SegmentFlags.FunctionsAsElements)
      {
        if (!this.hasMoreBytes())
        {
          this._pos = pos;
          return false;
        }
        // Read initializer expression, which must either be null ref or func ref
        let operator = this.readUint8();
        if (operator == OperatorCode.REF_NULL)
        {
          elements[i] = NULL_FUNCTION_INDEX;
        }
        else if (operator == OperatorCode.REF_FUNC)
        {
          if (!this.hasautoIntBytes())
          {
            this._pos = pos;
            return false;
          }
          elements[i] = this.readVarInt32();
        }
        else
        {
          this.error = new Error("Invalid initializer expression for element");
          return true;
        }
        if (!this.hasMoreBytes())
        {
          this._pos = pos;
          return false;
        }
        operator = this.readUint8();
        if (operator != OperatorCode.END)
        {
          this.error = new Error("Expected end of initializer expression for element");
          return true;
        }
      }
      else
      {
        if (!this.hasautoIntBytes())
        {
          this._pos = pos;
          return false;
        }
        elements[i] = this.readVarUint32();
      }
    }
    this.state = BinaryReaderState.ELEMENT_SECTION_ENTRY_BODY;

    auto asElements = !!(this._segmentFlags & SegmentFlags.FunctionsAsElements);
    this.result = ElementSegmentBody(elements, funcType, asElements);

    return true;
  }

  private bool readDataEntry()
  {
    if (this._sectionEntriesLeft == 0)
    {
      this.skipSection();
      return this.read();
    }

    if (!this.hasautoIntBytes())
    {
      return false;
    }

    this._segmentFlags = this.readVarUint32();
    let index = 0;
    if (this._segmentFlags == SegmentFlags.HasTableIndex)
    {
      index = this.readVarUint32();
    }

    this.state = BinaryReaderState.BEGIN_DATA_SECTION_ENTRY;

    this.result = DataSegment(index);

    this._sectionEntriesLeft--;
    return true;
  }

  private bool readDataEntryBody()
  {
    if (!this.hasStringBytes())
    {
      return false;
    }

    this.state = BinaryReaderState.DATA_SECTION_ENTRY_BODY;

    auto data = this.readStringBytes();

    this.result = DataSegmentBody(data);

    return true;
  }

  private bool readInitExpressionBody()
  {
    this.state = BinaryReaderState.BEGIN_INIT_EXPRESSION_BODY;
    this.result = null;
    return true;
  }

  private MemoryAddress readMemoryImmediate()
  {
    auto flags = this.readVarUint32() >>> 0;
    auto offset = this.readVarUint32() >>> 0;

    return MemoryAddress(flags, offset);
  }

  private int readLineIndex()
  {
    auto index = this.readUint8();
    return index;
  }

  private Naming[] readNameMap()
  {
    const auto count = this.readVarUint32();
    Naming[] _result;
    for (auto i = 0; i < count; i++)
    {
      auto index = this.readVarUint32();
      auto name = this.readStringBytes();

      _result.push(Naming(index, name));
    }

    return _result;
  }

  private bool readNameEntry()
  {
    const auto pos = this._pos;
    if (pos >= this._sectionRange.end)
    {
      this.skipSection();
      return this.read();
    }
    if (!this.hasautoIntBytes())
      return false;

    const NameType type = this.readVarUint7();
    if (!this.hasautoIntBytes())
    {
      this._pos = pos;
      return false;
    }

    auto payloadLength = this.readVarUint32();
    if (!this.hasBytes(payloadLength))
    {
      this._pos = pos;
      return false;
    }

    switch (type)
    {
    case NameType.Module:
      auto moduleName = this.readStringBytes();
      this.result = ModuleNameEntry(type, moduleName);
      break;

    case NameType.Function:
      auto names = this.readNameMap();

      this.result = FunctionNameEntry(type, names);
      break;

    case NameType.Local:
      const auto funcsLength = this.readVarUint32();
      LocalName[] funcs;
      for (auto i = 0; i < funcsLength; i++)
      {
        const auto funcIndex = this.readVarUint32();
        auto locals = this.readNameMap();
        funcs.push(LocalName(funcIndex, locals));
      }

      this.result = LocalNameEntry(type, funcs);
      break;

    default:
      this.error = new Error(`Bad name entry type: ${type}`);
      this.state = BinaryReaderState.ERROR;
      return true;
    }

    this.state = BinaryReaderState.NAME_SECTION_ENTRY;

    return true;
  }

  private bool readRelocHeader()
  {
    // See https://github.com/WebAssembly/tool-conventions/blob/master/Linking.md
    if (!this.hasVarIntBytes())
    {
      return false;
    }
    const auto pos = this._pos;
    SectionCode sectionId = this.readVarUint7();
    string sectionName;

    if (sectionId == SectionCode.Custom)
    {
      if (!this.hasStringBytes())
      {
        this._pos = pos;
        return false;
      }
      sectionName = this.readStringBytes();
    }

    this.state = BinaryReaderState.RELOC_SECTION_HEADER;

    this.result = RelocHeader(sectionId, sectionName);

    return true;
  }

  private bool readLinkingEntry()
  {
    if (this._sectionEntriesLeft == 0)
    {
      this.skipSection();
      return this.read();
    }

    if (!this.hasVarIntBytes())
      return false;
    const auto pos = this._pos;
    LinkingType type = this.readVarUint32() >>> 0;
    int index;

    switch (type)
    {
    case LinkingType.StackPointer:
      if (!this.hasVarIntBytes())
      {
        this._pos = pos;
        return false;
      }
      index = this.readVarUint32();
      break;
    default:
      this.error = new Error(`Bad linking type: ${type}`);
      this.state = BinaryReaderState.ERROR;
      return true;
    }

    this.state = BinaryReaderState.LINKING_SECTION_ENTRY;

    this.result = LinkingEntry(type, index);

    this._sectionEntriesLeft--;
    return true;
  }

  private bool readSourceMappingURL()
  {
    if (!this.hasStringBytes())
      return false;
    auto url = this.readStringBytes();

    this.state = BinaryReaderState.SOURCE_MAPPING_URL;

    this.result = SourceMappingURL(url);

    return true;
  }

  private bool readRelocEntry()
  {
    if (this._sectionEntriesLeft == 0)
    {
      this.skipSection();
      return this.read();
    }

    if (!this.hasVarIntBytes())
      return false;

    const auto pos = this._pos;
    const RelocType type = this.readVarUint7();
    if (!this.hasVarIntBytes())
    {
      this._pos = pos;
      return false;
    }

    const auto offset = this.readVarUint32();
    if (!this.hasVarIntBytes())
    {
      this._pos = pos;
      return false;
    }
    auto index = this.readVarUint32();
    Nullable!int addend = null;

    switch (type)
    {
    case RelocType.FunctionIndex_LEB:
    case RelocType.TableIndex_SLEB:
    case RelocType.TableIndex_I32:
    case RelocType.TypeIndex_LEB:
    case RelocType.GlobalIndex_LEB:
      break;
    case RelocType.GlobalAddr_LEB:
    case RelocType.GlobalAddr_SLEB:
    case RelocType.GlobalAddr_I32:
      if (!this.hasVarIntBytes())
      {
        this._pos = pos;
        return false;
      }
      addend = this.readVarUint32();
      break;
    default:
      this.error = new Error(`Bad relocation type: ${type}`);
      this.state = BinaryReaderState.ERROR;
      return true;
    }

    this.state = BinaryReaderState.RELOC_SECTION_ENTRY;

    this.result = RelocEntry(type, offset, index, addend);

    this._sectionEntriesLeft--;
    return true;
  }

  // ===================== OPERATOR =====================

  private bool readCodeOperator_0xfc()
  {
    if (!this.hasVarIntBytes())
    {
      return false;
    }

    const auto code = this.readVarUint32() | 0xfc00;
    ubyte reserved, segmentIndex, destinationIndex, tableIndex;

    switch (code)
    {
    case OperatorCode.I32_TRUNC_SAT_F32_S:
    case OperatorCode.I32_TRUNC_SAT_F32_U:
    case OperatorCode.I32_TRUNC_SAT_F64_S:
    case OperatorCode.I32_TRUNC_SAT_F64_U:
    case OperatorCode.I64_TRUNC_SAT_F32_S:
    case OperatorCode.I64_TRUNC_SAT_F32_U:
    case OperatorCode.I64_TRUNC_SAT_F64_S:
    case OperatorCode.I64_TRUNC_SAT_F64_U:
      break;
    case OperatorCode.MEMORY_COPY: // Currently memory index must be zero.
      reserved = this.readVarUint1();
      reserved = this.readVarUint1();
      break;
    case OperatorCode.MEMORY_FILL:
      reserved = this.readVarUint1();
      break;
    case OperatorCode.TABLE_INIT:
      segmentIndex = this.readVarUint32() >>> 0;
      tableIndex = this.readVarUint32() >>> 0;
      break;
    case OperatorCode.TABLE_COPY:
      tableIndex = this.readVarUint32() >>> 0;
      destinationIndex = this.readVarUint32() >>> 0;
      break;
    case OperatorCode.TABLE_GROW:
    case OperatorCode.TABLE_SIZE:
    case OperatorCode.TABLE_FILL:
      tableIndex = this.readVarUint32() >>> 0;
      break;
    case OperatorCode.MEMORY_INIT:
      segmentIndex = this.readVarUint32() >>> 0;
      reserved = this.readVarUint1();
      break;
    case OperatorCode.DATA_DROP:
    case OperatorCode.ELEM_DROP:
      segmentIndex = this.readVarUint32() >>> 0;
      break;
    default:
      this.error = new Error(`Unknown operator: ${code}`);
      this.state = BinaryReaderState.ERROR;
      return true;
    }

    this.result = OperatorInformation(code, null, null, null, null, null, null,
        null, null, null, null, null, tableIndex, segmentIndex, destinationIndex);

    return true;
  }

  private bool readCodeOperator_0xfd()
  {
    const MAX_CODE_OPERATOR_0XFD_SIZE = 17;
    const auto pos = this._pos;
    if (!this._eof && pos + MAX_CODE_OPERATOR_0XFD_SIZE > this._length)
    {
      return false;
    }

    if (!this.hasVarIntBytes())
    {
      return false;
    }
    const auto code = this.readVarUint32() | 0xfd00;

    MemoryAddress memoryAddress;
    ubyte[] literal;
    int lineIndex;
    ubyte[] lines;
    switch (code)
    {
    case OperatorCode.V128_LOAD:
    case OperatorCode.V128_STORE:
      memoryAddress = this.readMemoryImmediate();
      break;
    case OperatorCode.V128_CONST:
      literal = this.readBytes(16);
      break;
    case OperatorCode.V8X16_SHUFFLE:
      lines = new Uint8Array(16);
      for (auto i = 0; i < lines.length; i++)
        lines[i] = this.readLineIndex(32);
      break;
    case OperatorCode.I8X16_EXTRACT_LANE_S:
    case OperatorCode.I8X16_EXTRACT_LANE_U:
    case OperatorCode.I8X16_REPLACE_LANE:
      lineIndex = this.readLineIndex(16);
      break;
    case OperatorCode.I16X8_EXTRACT_LANE_S:
    case OperatorCode.I16X8_EXTRACT_LANE_U:
    case OperatorCode.I16X8_REPLACE_LANE:
      lineIndex = this.readLineIndex(8);
      break;
    case OperatorCode.I32X4_EXTRACT_LANE:
    case OperatorCode.I32X4_REPLACE_LANE:
    case OperatorCode.F32X4_EXTRACT_LANE:
    case OperatorCode.F32X4_REPLACE_LANE:
      lineIndex = this.readLineIndex(4);
      break;
    case OperatorCode.I64X2_EXTRACT_LANE:
    case OperatorCode.I64X2_REPLACE_LANE:
    case OperatorCode.F64X2_EXTRACT_LANE:
    case OperatorCode.F64X2_REPLACE_LANE:
      lineIndex = this.readLineIndex(2);
      break;
    case OperatorCode.I8X16_SPLAT:
    case OperatorCode.I16X8_SPLAT:
    case OperatorCode.I32X4_SPLAT:
    case OperatorCode.I64X2_SPLAT:
    case OperatorCode.F32X4_SPLAT:
    case OperatorCode.F64X2_SPLAT:
    case OperatorCode.I8X16_EQ:
    case OperatorCode.I8X16_NE:
    case OperatorCode.I8X16_LT_S:
    case OperatorCode.I8X16_LT_U:
    case OperatorCode.I8X16_GT_S:
    case OperatorCode.I8X16_GT_U:
    case OperatorCode.I8X16_LE_S:
    case OperatorCode.I8X16_LE_U:
    case OperatorCode.I8X16_GE_S:
    case OperatorCode.I8X16_GE_U:
    case OperatorCode.I16X8_EQ:
    case OperatorCode.I16X8_NE:
    case OperatorCode.I16X8_LT_S:
    case OperatorCode.I16X8_LT_U:
    case OperatorCode.I16X8_GT_S:
    case OperatorCode.I16X8_GT_U:
    case OperatorCode.I16X8_LE_S:
    case OperatorCode.I16X8_LE_U:
    case OperatorCode.I16X8_GE_S:
    case OperatorCode.I16X8_GE_U:
    case OperatorCode.I32X4_EQ:
    case OperatorCode.I32X4_NE:
    case OperatorCode.I32X4_LT_S:
    case OperatorCode.I32X4_LT_U:
    case OperatorCode.I32X4_GT_S:
    case OperatorCode.I32X4_GT_U:
    case OperatorCode.I32X4_LE_S:
    case OperatorCode.I32X4_LE_U:
    case OperatorCode.I32X4_GE_S:
    case OperatorCode.I32X4_GE_U:
    case OperatorCode.F32X4_EQ:
    case OperatorCode.F32X4_NE:
    case OperatorCode.F32X4_LT:
    case OperatorCode.F32X4_GT:
    case OperatorCode.F32X4_LE:
    case OperatorCode.F32X4_GE:
    case OperatorCode.F64X2_EQ:
    case OperatorCode.F64X2_NE:
    case OperatorCode.F64X2_LT:
    case OperatorCode.F64X2_GT:
    case OperatorCode.F64X2_LE:
    case OperatorCode.F64X2_GE:
    case OperatorCode.V128_NOT:
    case OperatorCode.V128_AND:
    case OperatorCode.V128_OR:
    case OperatorCode.V128_XOR:
    case OperatorCode.V128_BITSELECT:
    case OperatorCode.I8X16_NEG:
    case OperatorCode.I8X16_ANY_TRUE:
    case OperatorCode.I8X16_ALL_TRUE:
    case OperatorCode.I8X16_SHL:
    case OperatorCode.I8X16_SHR_S:
    case OperatorCode.I8X16_SHR_U:
    case OperatorCode.I8X16_ADD:
    case OperatorCode.I8X16_ADD_SATURATE_S:
    case OperatorCode.I8X16_ADD_SATURATE_U:
    case OperatorCode.I8X16_SUB:
    case OperatorCode.I8X16_SUB_SATURATE_S:
    case OperatorCode.I8X16_SUB_SATURATE_U:
    case OperatorCode.I16X8_NEG:
    case OperatorCode.I16X8_ANY_TRUE:
    case OperatorCode.I16X8_ALL_TRUE:
    case OperatorCode.I16X8_SHL:
    case OperatorCode.I16X8_SHR_S:
    case OperatorCode.I16X8_SHR_U:
    case OperatorCode.I16X8_ADD:
    case OperatorCode.I16X8_ADD_SATURATE_S:
    case OperatorCode.I16X8_ADD_SATURATE_U:
    case OperatorCode.I16X8_SUB:
    case OperatorCode.I16X8_SUB_SATURATE_S:
    case OperatorCode.I16X8_SUB_SATURATE_U:
    case OperatorCode.I16X8_MUL:
    case OperatorCode.I32X4_NEG:
    case OperatorCode.I32X4_ANY_TRUE:
    case OperatorCode.I32X4_ALL_TRUE:
    case OperatorCode.I32X4_SHL:
    case OperatorCode.I32X4_SHR_S:
    case OperatorCode.I32X4_SHR_U:
    case OperatorCode.I32X4_ADD:
    case OperatorCode.I32X4_SUB:
    case OperatorCode.I32X4_MUL:
    case OperatorCode.I64X2_NEG:
    case OperatorCode.I64X2_SHL:
    case OperatorCode.I64X2_SHR_S:
    case OperatorCode.I64X2_SHR_U:
    case OperatorCode.I64X2_ADD:
    case OperatorCode.I64X2_SUB:
    case OperatorCode.F32X4_ABS:
    case OperatorCode.F32X4_NEG:
    case OperatorCode.F32X4_SQRT:
    case OperatorCode.F32X4_ADD:
    case OperatorCode.F32X4_SUB:
    case OperatorCode.F32X4_MUL:
    case OperatorCode.F32X4_DIV:
    case OperatorCode.F32X4_MIN:
    case OperatorCode.F32X4_MAX:
    case OperatorCode.F64X2_ABS:
    case OperatorCode.F64X2_NEG:
    case OperatorCode.F64X2_SQRT:
    case OperatorCode.F64X2_ADD:
    case OperatorCode.F64X2_SUB:
    case OperatorCode.F64X2_MUL:
    case OperatorCode.F64X2_DIV:
    case OperatorCode.F64X2_MIN:
    case OperatorCode.F64X2_MAX:
    case OperatorCode.I32X4_TRUNC_SAT_F32X4_S:
    case OperatorCode.I32X4_TRUNC_SAT_F32X4_U:
    case OperatorCode.F32X4_CONVERT_I32X4_S:
    case OperatorCode.F32X4_CONVERT_I32X4_U:
      break;
    default:
      this.error = new Error(`Unknown operator: ${code}`);
      this.state = BinaryReaderState.ERROR;
      return true;
    }

    this.result = OperatorInformation(code, literal, lineIndex, lines, null,
        null, null, memoryAddress, null, null, null, null, null, null, null);

    return true;
  }

  private bool readCodeOperator_0xfe()
  {
    const MAX_CODE_OPERATOR_0XFE_SIZE = 11;
    const auto pos = this._pos;
    if (!this._eof && pos + MAX_CODE_OPERATOR_0XFE_SIZE > this._length)
    {
      return false;
    }
    if (!this.hasVarIntBytes())
    {
      return false;
    }
    const auto code = this.readVarUint32() | 0xfe00;
    MemoryAddress memoryAddress;

    switch (code)
    {
    case OperatorCode.ATOMIC_NOTIFY:
    case OperatorCode.I32_ATOMIC_WAIT:
    case OperatorCode.I64_ATOMIC_WAIT:
    case OperatorCode.I32_ATOMIC_LOAD:
    case OperatorCode.I64_ATOMIC_LOAD:
    case OperatorCode.I32_ATOMIC_LOAD8_U:
    case OperatorCode.I32_ATOMIC_LOAD16_U:
    case OperatorCode.I64_ATOMIC_LOAD8_U:
    case OperatorCode.I64_ATOMIC_LOAD16_U:
    case OperatorCode.I64_ATOMIC_LOAD32_U:
    case OperatorCode.I32_ATOMIC_STORE:
    case OperatorCode.I64_ATOMIC_STORE:
    case OperatorCode.I32_ATOMIC_STORE8:
    case OperatorCode.I32_ATOMIC_STORE16:
    case OperatorCode.I64_ATOMIC_STORE8:
    case OperatorCode.I64_ATOMIC_STORE16:
    case OperatorCode.I64_ATOMIC_STORE32:
    case OperatorCode.I32_ATOMIC_RMW_ADD:
    case OperatorCode.I64_ATOMIC_RMW_ADD:
    case OperatorCode.I32_ATOMIC_RMW8_ADD_U:
    case OperatorCode.I32_ATOMIC_RMW16_ADD_U:
    case OperatorCode.I64_ATOMIC_RMW8_ADD_U:
    case OperatorCode.I64_ATOMIC_RMW16_ADD_U:
    case OperatorCode.I64_ATOMIC_RMW32_ADD_U:
    case OperatorCode.I32_ATOMIC_RMW_SUB:
    case OperatorCode.I64_ATOMIC_RMW_SUB:
    case OperatorCode.I32_ATOMIC_RMW8_SUB_U:
    case OperatorCode.I32_ATOMIC_RMW16_SUB_U:
    case OperatorCode.I64_ATOMIC_RMW8_SUB_U:
    case OperatorCode.I64_ATOMIC_RMW16_SUB_U:
    case OperatorCode.I64_ATOMIC_RMW32_SUB_U:
    case OperatorCode.I32_ATOMIC_RMW_AND:
    case OperatorCode.I64_ATOMIC_RMW_AND:
    case OperatorCode.I32_ATOMIC_RMW8_AND_U:
    case OperatorCode.I32_ATOMIC_RMW16_AND_U:
    case OperatorCode.I64_ATOMIC_RMW8_AND_U:
    case OperatorCode.I64_ATOMIC_RMW16_AND_U:
    case OperatorCode.I64_ATOMIC_RMW32_AND_U:
    case OperatorCode.I32_ATOMIC_RMW_OR:
    case OperatorCode.I64_ATOMIC_RMW_OR:
    case OperatorCode.I32_ATOMIC_RMW8_OR_U:
    case OperatorCode.I32_ATOMIC_RMW16_OR_U:
    case OperatorCode.I64_ATOMIC_RMW8_OR_U:
    case OperatorCode.I64_ATOMIC_RMW16_OR_U:
    case OperatorCode.I64_ATOMIC_RMW32_OR_U:
    case OperatorCode.I32_ATOMIC_RMW_XOR:
    case OperatorCode.I64_ATOMIC_RMW_XOR:
    case OperatorCode.I32_ATOMIC_RMW8_XOR_U:
    case OperatorCode.I32_ATOMIC_RMW16_XOR_U:
    case OperatorCode.I64_ATOMIC_RMW8_XOR_U:
    case OperatorCode.I64_ATOMIC_RMW16_XOR_U:
    case OperatorCode.I64_ATOMIC_RMW32_XOR_U:
    case OperatorCode.I32_ATOMIC_RMW_XCHG:
    case OperatorCode.I64_ATOMIC_RMW_XCHG:
    case OperatorCode.I32_ATOMIC_RMW8_XCHG_U:
    case OperatorCode.I32_ATOMIC_RMW16_XCHG_U:
    case OperatorCode.I64_ATOMIC_RMW8_XCHG_U:
    case OperatorCode.I64_ATOMIC_RMW16_XCHG_U:
    case OperatorCode.I64_ATOMIC_RMW32_XCHG_U:
    case OperatorCode.I32_ATOMIC_RMW_CMPXCHG:
    case OperatorCode.I64_ATOMIC_RMW_CMPXCHG:
    case OperatorCode.I32_ATOMIC_RMW8_CMPXCHG_U:
    case OperatorCode.I32_ATOMIC_RMW16_CMPXCHG_U:
    case OperatorCode.I64_ATOMIC_RMW8_CMPXCHG_U:
    case OperatorCode.I64_ATOMIC_RMW16_CMPXCHG_U:
    case OperatorCode.I64_ATOMIC_RMW32_CMPXCHG_U:
      memoryAddress = this.readMemoryImmediate();
      break;
    case OperatorCode.ATOMIC_FENCE:
      {
        const auto consistency_model = this.readUint8();
        if (consistency_model != 0)
        {
          this.error = new Error("atomic.fence consistency model must be 0");
          this.state = BinaryReaderState.ERROR;
          return true;
        }
        break;
      }
    default:
      this.error = new Error(`Unknown operator: ${code}`);
      this.state = BinaryReaderState.ERROR;
      return true;
    }

    this.result = OperatorInformation(code, null, null, null, null, null, null,
        memoryAddress, null, null, null, null, null, null, null);

    return true;
  }

  private bool readCodeOperator()
  {
    if (this.state == BinaryReaderState.CODE_OPERATOR && this._pos >= this._functionRange.end)
    {
      this.skipFunctionBody();
      return this.read();
    }
    else if (this.state == BinaryReaderState.INIT_EXPRESSION_OPERATOR
        && this.result && this.getCurrentOperationInformation().code == OperatorCode.END)
    {
      this.state = BinaryReaderState.END_INIT_EXPRESSION_BODY;
      this.result = null;
      return true;
    }

    const MAX_CODE_OPERATOR_SIZE = 11; // i64.const or load/store
    const auto pos = this._pos;
    if (!this._eof && pos + MAX_CODE_OPERATOR_SIZE > this._length)
    {
      return false;
    }
    const auto code = this._data[this._pos++];

    int blockType, brDepth, funcIndex, typeIndex, tableIndex, localIndex,
      globalIndex, literal, reserved;

    Nullable!MemoryAddress memoryAddress = null;
    Nullable!int[] brTable = null;

    switch (code)
    {
    case OperatorCode.BLOCK:
    case OperatorCode.LOOP:
    case OperatorCode.IF:
      blockType = this.readVarInt7();
      break;
    case OperatorCode.BR:
    case OperatorCode.BR_IF:
      brDepth = this.readVarUint32() >>> 0;
      break;
    case OperatorCode.BR_TABLE:
      auto tableCount = this.readVarUint32() >>> 0;
      if (!this.hasBytes(tableCount + 1))
      {
        // We need at least (tableCount + 1) bytes
        this._pos = pos;
        return false;
      }
      brTable = [];
      for (auto i = 0; i <= tableCount; i++)
      {
        // including default
        if (!this.hasVarIntBytes())
        {
          this._pos = pos;
          return false;
        }
        brTable.push(this.readVarUint32() >>> 0);
      }
      break;
    case OperatorCode.CALL:
    case OperatorCode.RETURN_CALL:
    case OperatorCode.REF_FUNC:
      funcIndex = this.readVarUint32() >>> 0;
      break;
    case OperatorCode.CALL_INDIRECT:
    case OperatorCode.RETURN_CALL_INDIRECT:
      typeIndex = this.readVarUint32() >>> 0;
      reserved = this.readVarUint1();
      break;
    case OperatorCode.LOCAL_GET:
    case OperatorCode.LOCAL_SET:
    case OperatorCode.LOCAL_TEE:
      localIndex = this.readVarUint32() >>> 0;
      break;
    case OperatorCode.GLOBAL_GET:
    case OperatorCode.GLOBAL_SET:
      globalIndex = this.readVarUint32() >>> 0;
      break;
    case OperatorCode.TABLE_GET:
    case OperatorCode.TABLE_SET:
      tableIndex = this.readVarUint32() >>> 0;
      break;
    case OperatorCode.I32_LOAD:
    case OperatorCode.I64_LOAD:
    case OperatorCode.F32_LOAD:
    case OperatorCode.F64_LOAD:
    case OperatorCode.I32_LOAD8_S:
    case OperatorCode.I32_LOAD8_U:
    case OperatorCode.I32_LOAD16_S:
    case OperatorCode.I32_LOAD16_U:
    case OperatorCode.I64_LOAD8_S:
    case OperatorCode.I64_LOAD8_U:
    case OperatorCode.I64_LOAD16_S:
    case OperatorCode.I64_LOAD16_U:
    case OperatorCode.I64_LOAD32_S:
    case OperatorCode.I64_LOAD32_U:
    case OperatorCode.I32_STORE:
    case OperatorCode.I64_STORE:
    case OperatorCode.F32_STORE:
    case OperatorCode.F64_STORE:
    case OperatorCode.I32_STORE8:
    case OperatorCode.I32_STORE16:
    case OperatorCode.I64_STORE8:
    case OperatorCode.I64_STORE16:
    case OperatorCode.I64_STORE32:
      memoryAddress = this.readMemoryImmediate();
      break;
    case OperatorCode.CURRENT_MEMORY:
    case OperatorCode.GROW_MEMORY:
      reserved = this.readVarUint1();
      break;
    case OperatorCode.I32_CONST:
      literal = this.readVarInt32();
      break;
    case OperatorCode.I64_CONST:
      literal = this.readVarInt64();
      break;
    case OperatorCode.F32_CONST:
      literal = new DataView(this._data.buffer,
          this._data.byteOffset).getFloat32(this._pos, true);
      this._pos += 4;
      break;
    case OperatorCode.F64_CONST:
      literal = new DataView(this._data.buffer,
          this._data.byteOffset).getFloat64(this._pos, true);
      this._pos += 8;
      break;
    case OperatorCode.PREFIX_0XFC:
      if (this.readCodeOperator_0xfc())
      {
        return true;
      }
      this._pos = pos;
      return false;
    case OperatorCode.PREFIX_0XFD:
      if (this.readCodeOperator_0xfd())
      {
        return true;
      }
      this._pos = pos;
      return false;
    case OperatorCode.PREFIX_0XFE:
      if (this.readCodeOperator_0xfe())
      {
        return true;
      }
      this._pos = pos;
      return false;
    case OperatorCode.UNREACHABLE:
    case OperatorCode.NOP:
    case OperatorCode.ELSE:
    case OperatorCode.END:
    case OperatorCode.RETURN:
    case OperatorCode.DROP:
    case OperatorCode.SELECT:
    case OperatorCode.I32_EQZ:
    case OperatorCode.I32_EQ:
    case OperatorCode.I32_NE:
    case OperatorCode.I32_LT_S:
    case OperatorCode.I32_LT_U:
    case OperatorCode.I32_GT_S:
    case OperatorCode.I32_GT_U:
    case OperatorCode.I32_LE_S:
    case OperatorCode.I32_LE_U:
    case OperatorCode.I32_GE_S:
    case OperatorCode.I32_GE_U:
    case OperatorCode.I64_EQZ:
    case OperatorCode.I64_EQ:
    case OperatorCode.I64_NE:
    case OperatorCode.I64_LT_S:
    case OperatorCode.I64_LT_U:
    case OperatorCode.I64_GT_S:
    case OperatorCode.I64_GT_U:
    case OperatorCode.I64_LE_S:
    case OperatorCode.I64_LE_U:
    case OperatorCode.I64_GE_S:
    case OperatorCode.I64_GE_U:
    case OperatorCode.F32_EQ:
    case OperatorCode.F32_NE:
    case OperatorCode.F32_LT:
    case OperatorCode.F32_GT:
    case OperatorCode.F32_LE:
    case OperatorCode.F32_GE:
    case OperatorCode.F64_EQ:
    case OperatorCode.F64_NE:
    case OperatorCode.F64_LT:
    case OperatorCode.F64_GT:
    case OperatorCode.F64_LE:
    case OperatorCode.F64_GE:
    case OperatorCode.I32_CLZ:
    case OperatorCode.I32_CTZ:
    case OperatorCode.I32_POPCNT:
    case OperatorCode.I32_ADD:
    case OperatorCode.I32_SUB:
    case OperatorCode.I32_MUL:
    case OperatorCode.I32_DIV_S:
    case OperatorCode.I32_DIV_U:
    case OperatorCode.I32_REM_S:
    case OperatorCode.I32_REM_U:
    case OperatorCode.I32_AND:
    case OperatorCode.I32_OR:
    case OperatorCode.I32_XOR:
    case OperatorCode.I32_SHL:
    case OperatorCode.I32_SHR_S:
    case OperatorCode.I32_SHR_U:
    case OperatorCode.I32_ROTL:
    case OperatorCode.I32_ROTR:
    case OperatorCode.I64_CLZ:
    case OperatorCode.I64_CTZ:
    case OperatorCode.I64_POPCNT:
    case OperatorCode.I64_ADD:
    case OperatorCode.I64_SUB:
    case OperatorCode.I64_MUL:
    case OperatorCode.I64_DIV_S:
    case OperatorCode.I64_DIV_U:
    case OperatorCode.I64_REM_S:
    case OperatorCode.I64_REM_U:
    case OperatorCode.I64_AND:
    case OperatorCode.I64_OR:
    case OperatorCode.I64_XOR:
    case OperatorCode.I64_SHL:
    case OperatorCode.I64_SHR_S:
    case OperatorCode.I64_SHR_U:
    case OperatorCode.I64_ROTL:
    case OperatorCode.I64_ROTR:
    case OperatorCode.F32_ABS:
    case OperatorCode.F32_NEG:
    case OperatorCode.F32_CEIL:
    case OperatorCode.F32_FLOOR:
    case OperatorCode.F32_TRUNC:
    case OperatorCode.F32_NEAREST:
    case OperatorCode.F32_SQRT:
    case OperatorCode.F32_ADD:
    case OperatorCode.F32_SUB:
    case OperatorCode.F32_MUL:
    case OperatorCode.F32_DIV:
    case OperatorCode.F32_MIN:
    case OperatorCode.F32_MAX:
    case OperatorCode.F32_COPYSIGN:
    case OperatorCode.F64_ABS:
    case OperatorCode.F64_NEG:
    case OperatorCode.F64_CEIL:
    case OperatorCode.F64_FLOOR:
    case OperatorCode.F64_TRUNC:
    case OperatorCode.F64_NEAREST:
    case OperatorCode.F64_SQRT:
    case OperatorCode.F64_ADD:
    case OperatorCode.F64_SUB:
    case OperatorCode.F64_MUL:
    case OperatorCode.F64_DIV:
    case OperatorCode.F64_MIN:
    case OperatorCode.F64_MAX:
    case OperatorCode.F64_COPYSIGN:
    case OperatorCode.I32_WRAP_I64:
    case OperatorCode.I32_TRUNC_F32_S:
    case OperatorCode.I32_TRUNC_F32_U:
    case OperatorCode.I32_TRUNC_F64_S:
    case OperatorCode.I32_TRUNC_F64_U:
    case OperatorCode.I64_EXTEND_I32_S:
    case OperatorCode.I64_EXTEND_I32_U:
    case OperatorCode.I64_TRUNC_F32_S:
    case OperatorCode.I64_TRUNC_F32_U:
    case OperatorCode.I64_TRUNC_F64_S:
    case OperatorCode.I64_TRUNC_F64_U:
    case OperatorCode.F32_CONVERT_I32_S:
    case OperatorCode.F32_CONVERT_I32_U:
    case OperatorCode.F32_CONVERT_I64_S:
    case OperatorCode.F32_CONVERT_I64_U:
    case OperatorCode.F32_DEMOTE_F64:
    case OperatorCode.F64_CONVERT_I32_S:
    case OperatorCode.F64_CONVERT_I32_U:
    case OperatorCode.F64_CONVERT_I64_S:
    case OperatorCode.F64_CONVERT_I64_U:
    case OperatorCode.F64_PROMOTE_F32:
    case OperatorCode.I32_REINTERPRET_F32:
    case OperatorCode.I64_REINTERPRET_F64:
    case OperatorCode.F32_REINTERPRET_I32:
    case OperatorCode.F64_REINTERPRET_I64:
    case OperatorCode.I32_EXTEND8_S:
    case OperatorCode.I32_EXTEND16_S:
    case OperatorCode.I64_EXTEND8_S:
    case OperatorCode.I64_EXTEND16_S:
    case OperatorCode.I64_EXTEND32_S:
    case OperatorCode.REF_NULL:
    case OperatorCode.REF_IS_NULL:
      break;
    default:
      this.error = new Error(`Unknown operator: ${code}`);
      this.state = BinaryReaderState.ERROR;
      return true;
    }

    this.result = OperatorInformation(code, literal, null, null, blockType, brTable, brDepth,
        memoryAddress, funcIndex, typeIndex, tableIndex, localIndex, globalIndex, null, null);

    return true;
  }

  private bool readFunctionBody()
  {
    if (this._sectionEntriesLeft == 0)
    {
      this.skipSection();
      return this.read();
    }

    if (!this.hasVarIntBytes())
      return false;
    const auto pos = this._pos;
    const auto size = this.readVarUint32() >>> 0;
    auto bodyEnd = this._pos + size;
    if (!this.hasVarIntBytes())
    {
      this._pos = pos;
      return false;
    }
    const auto localCount = this.readVarUint32() >>> 0;
    Locals[] locals;
    for (auto i = 0; i < localCount; i++)
    {
      if (!this.hasVarIntBytes())
      {
        this._pos = pos;
        return false;
      }
      const auto count = this.readVarUint32() >>> 0;
      if (!this.hasVarIntBytes())
      {
        this._pos = pos;
        return false;
      }
      auto type = this.readVarInt7();
      locals.push(Locals(count, type));
    }
    auto bodyStart = this._pos;
    this.state = BinaryReaderState.BEGIN_FUNCTION_BODY;
    this.result = FunctionInformation(locals);

    this._functionRange = new DataRange(bodyStart, bodyEnd);
    this._sectionEntriesLeft--;
    return true;
  }

  private bool readSectionHeader()
  {
    if (this._pos >= this._length && this._eof)
    {
      this._sectionId = SectionCode.Unknown;
      this._sectionRange = null;
      this.result = null;
      this.state = BinaryReaderState.END_WASM;
      return true;
    }
    // TODO: Handle _eof.
    if (this._pos < this._length - 4)
    {
      const auto magicNumber = this.peekInt32();
      if (magicNumber == WASM_MAGIC_NUMBER)
      {
        this._sectionId = SectionCode.Unknown;
        this._sectionRange = null;
        this.result = null;
        this.state = BinaryReaderState.END_WASM;
        return true;
      }
    }
    if (!this.hasVarIntBytes())
      return false;
    const auto sectionStart = this._pos;
    const auto id = this.readVarUint7();
    if (!this.hasVarIntBytes())
    {
      this._pos = sectionStart;
      return false;
    }
    const auto payloadLength = this.readVarUint32() >>> 0;
    auto name = null;
    auto payloadEnd = this._pos + payloadLength;
    if (id == 0)
    {
      if (!this.hasStringBytes())
      {
        this._pos = sectionStart;
        return false;
      }
      name = this.readStringBytes();
    }
    this.result = SectionInformation(id, name);

    this._sectionId = id;
    this._sectionRange = new DataRange(this._pos, payloadEnd);
    this.state = BinaryReaderState.BEGIN_SECTION;
    return true;
  }

  private bool readSectionRawData()
  {
    auto payloadLength = this._sectionRange.end - this._sectionRange.start;
    if (!this.hasBytes(payloadLength))
    {
      return false;
    }
    this.state = BinaryReaderState.SECTION_RAW_DATA;
    this.result = this.readBytes(payloadLength);
    return true;
  }

  private bool readSectionBody()
  {
    if (this._pos >= this._sectionRange.end)
    {
      this.result = null;
      this.state = BinaryReaderState.END_SECTION;
      this._sectionId = SectionCode.Unknown;
      this._sectionRange = null;
      return true;
    }
    auto currentSection = this.getCurrentSection();

    switch (currentSection.id)
    {
    case SectionCode.Type:
      if (!this.hasSectionPayload())
        return false;
      this._sectionEntriesLeft = this.readVarUint32() >>> 0;
      return this.readTypeEntry();
    case SectionCode.Import:
      if (!this.hasSectionPayload())
        return false;
      this._sectionEntriesLeft = this.readVarUint32() >>> 0;
      return this.readImportEntry();
    case SectionCode.Export:
      if (!this.hasSectionPayload())
        return false;
      this._sectionEntriesLeft = this.readVarUint32() >>> 0;
      return this.readExportEntry();
    case SectionCode.Function:
      if (!this.hasSectionPayload())
        return false;
      this._sectionEntriesLeft = this.readVarUint32() >>> 0;
      return this.readFunctionEntry();
    case SectionCode.Table:
      if (!this.hasSectionPayload())
        return false;
      this._sectionEntriesLeft = this.readVarUint32() >>> 0;
      return this.readTableEntry();
    case SectionCode.Memory:
      if (!this.hasSectionPayload())
        return false;
      this._sectionEntriesLeft = this.readVarUint32() >>> 0;
      return this.readMemoryEntry();
    case SectionCode.Global:
      if (!this.hasVarIntBytes())
        return false;
      this._sectionEntriesLeft = this.readVarUint32() >>> 0;
      return this.readGlobalEntry();
    case SectionCode.Start:
      if (!this.hasVarIntBytes())
        return false;
      this.state = BinaryReaderState.START_SECTION_ENTRY;
      auto index = this.readVarUint32();
      this.result = StartEntry(index);
      return true;
    case SectionCode.Code:
      if (!this.hasVarIntBytes())
        return false;
      this._sectionEntriesLeft = this.readVarUint32() >>> 0;
      this.state = BinaryReaderState.READING_FUNCTION_HEADER;
      return this.readFunctionBody();
    case SectionCode.Element:
      if (!this.hasVarIntBytes())
        return false;
      this._sectionEntriesLeft = this.readVarUint32() >>> 0;
      return this.readElementEntry();
    case SectionCode.Data:
      if (!this.hasVarIntBytes())
        return false;
      this._sectionEntriesLeft = this.readVarUint32() >>> 0;
      this.state = BinaryReaderState.DATA_SECTION_ENTRY;
      return this.readDataEntry();
    case SectionCode.Custom:
      const auto customSectionName = bytesToString(currentSection.name);
      if (customSectionName == "name")
      {
        return this.readNameEntry();
      }
      if (customSectionName.indexOf("reloc.") == 0)
      {
        return this.readRelocHeader();
      }
      if (customSectionName == "linking")
      {
        if (!this.hasVarIntBytes())
          return false;
        this._sectionEntriesLeft = this.readVarUint32() >>> 0;
        return this.readLinkingEntry();
      }
      if (customSectionName == "sourceMappingURL")
      {
        return this.readSourceMappingURL();
      }
      return this.readSectionRawData();
    default:
      this.error = new Error(`Unsupported section: ${this._sectionId}`);
      this.state = BinaryReaderState.ERROR;
      return true;
    }
  }

  public bool read()
  {
    switch (this.state)
    {
    case BinaryReaderState.INITIAL:
      if (!this.hasBytes(8))
        return false;
      const auto magicNumber = this.readUint32();
      if (magicNumber != WASM_MAGIC_NUMBER)
      {
        this.error = new Error("Bad magic number");
        this.state = BinaryReaderState.ERROR;
        return true;
      }
      const auto _version = this.readUint32();
      if (_version != WASM_SUPPORTED_VERSION && _version != WASM_SUPPORTED_EXPERIMENTAL_VERSION)
      {
        this.error = new Error(`Bad version number ${version}`);
        this.state = BinaryReaderState.ERROR;
        return true;
      }
      this.result = ModuleHeader(magicNumber, _version);
      this.state = BinaryReaderState.BEGIN_WASM;
      return true;
    case BinaryReaderState.END_WASM:
      this.result = null;
      this.state = BinaryReaderState.BEGIN_WASM;
      if (this.hasMoreBytes())
      {
        this.state = BinaryReaderState.INITIAL;
        return this.read();
      }
      return false;
    case BinaryReaderState.ERROR:
      return true;
    case BinaryReaderState.BEGIN_WASM:
    case BinaryReaderState.END_SECTION:
      return this.readSectionHeader();
    case BinaryReaderState.BEGIN_SECTION:
      return this.readSectionBody();
    case BinaryReaderState.SKIPPING_SECTION:
      if (!this.hasSectionPayload())
      {
        return false;
      }
      this.state = BinaryReaderState.END_SECTION;
      this._pos = this._sectionRange.end;
      this._sectionId = SectionCode.Unknown;
      this._sectionRange = null;
      this.result = null;
      return true;
    case BinaryReaderState.SKIPPING_FUNCTION_BODY:
      this.state = BinaryReaderState.END_FUNCTION_BODY;
      this._pos = this._functionRange.end;
      this._functionRange = null;
      this.result = null;
      return true;
    case BinaryReaderState.TYPE_SECTION_ENTRY:
      return this.readTypeEntry();
    case BinaryReaderState.IMPORT_SECTION_ENTRY:
      return this.readImportEntry();
    case BinaryReaderState.EXPORT_SECTION_ENTRY:
      return this.readExportEntry();
    case BinaryReaderState.FUNCTION_SECTION_ENTRY:
      return this.readFunctionEntry();
    case BinaryReaderState.TABLE_SECTION_ENTRY:
      return this.readTableEntry();
    case BinaryReaderState.MEMORY_SECTION_ENTRY:
      return this.readMemoryEntry();
    case BinaryReaderState.GLOBAL_SECTION_ENTRY:
    case BinaryReaderState.END_GLOBAL_SECTION_ENTRY:
      return this.readGlobalEntry();
    case BinaryReaderState.BEGIN_GLOBAL_SECTION_ENTRY:
      return this.readInitExpressionBody();
    case BinaryReaderState.ELEMENT_SECTION_ENTRY:
    case BinaryReaderState.END_ELEMENT_SECTION_ENTRY:
      return this.readElementEntry();
    case BinaryReaderState.BEGIN_ELEMENT_SECTION_ENTRY:
      if (this._segmentFlags & SegmentFlags.IsPassive)
      {
        return this.readElementEntryBody();
      }
      else
      {
        return this.readInitExpressionBody();
      }
    case BinaryReaderState.ELEMENT_SECTION_ENTRY_BODY:
      this.state = BinaryReaderState.END_ELEMENT_SECTION_ENTRY;
      this.result = null;
      return true;
    case BinaryReaderState.DATA_SECTION_ENTRY:
    case BinaryReaderState.END_DATA_SECTION_ENTRY:
      return this.readDataEntry();
    case BinaryReaderState.BEGIN_DATA_SECTION_ENTRY:
      if (this._segmentFlags & SegmentFlags.IsPassive)
      {
        return this.readDataEntryBody();
      }
      else
      {
        return this.readInitExpressionBody();
      }
    case BinaryReaderState.DATA_SECTION_ENTRY_BODY:
      this.state = BinaryReaderState.END_DATA_SECTION_ENTRY;
      this.result = null;
      return true;
    case BinaryReaderState.END_INIT_EXPRESSION_BODY:
      switch (this._sectionId)
      {
      case SectionCode.Global:
        this.state = BinaryReaderState.END_GLOBAL_SECTION_ENTRY;
        return true;
      case SectionCode.Data:
        return this.readDataEntryBody();
      case SectionCode.Element:
        return this.readElementEntryBody();
      }
      this.error = new Error(`Unexpected section type: ${this._sectionId}`);
      this.state = BinaryReaderState.ERROR;
      return true;
    case BinaryReaderState.NAME_SECTION_ENTRY:
      return this.readNameEntry();
    case BinaryReaderState.RELOC_SECTION_HEADER:
      if (!this.hasVarIntBytes())
        return false;
      this._sectionEntriesLeft = this.readVarUint32() >>> 0;
      return this.readRelocEntry();
    case BinaryReaderState.LINKING_SECTION_ENTRY:
      return this.readLinkingEntry();
    case BinaryReaderState.SOURCE_MAPPING_URL:
      this.state = BinaryReaderState.END_SECTION;
      this.result = null;
      return true;
    case BinaryReaderState.RELOC_SECTION_ENTRY:
      return this.readRelocEntry();
    case BinaryReaderState.READING_FUNCTION_HEADER:
    case BinaryReaderState.END_FUNCTION_BODY:
      return this.readFunctionBody();
    case BinaryReaderState.BEGIN_FUNCTION_BODY:
      this.state = BinaryReaderState.CODE_OPERATOR;
      return this.readCodeOperator();
    case BinaryReaderState.BEGIN_INIT_EXPRESSION_BODY:
      this.state = BinaryReaderState.INIT_EXPRESSION_OPERATOR;
      return this.readCodeOperator();
    case BinaryReaderState.CODE_OPERATOR:
    case BinaryReaderState.INIT_EXPRESSION_OPERATOR:
      return this.readCodeOperator();
    case BinaryReaderState.READING_SECTION_RAW_DATA:
      return this.readSectionRawData();
    case BinaryReaderState.START_SECTION_ENTRY:
    case BinaryReaderState.SECTION_RAW_DATA:
      this.state = BinaryReaderState.END_SECTION;
      this.result = null;
      return true;
    default:
      this.error = new Error(`Unsupported state: ${this.state}`);
      this.state = BinaryReaderState.ERROR;
      return true;
    }
  }

  public void skipSection()
  {
    if (this.state == BinaryReaderState.ERROR || this.state == BinaryReaderState.INITIAL
        || this.state == BinaryReaderState.END_SECTION
        || this.state == BinaryReaderState.BEGIN_WASM || this.state == BinaryReaderState.END_WASM)
      return;
    this.state = BinaryReaderState.SKIPPING_SECTION;
  }

  public void skipFunctionBody()
  {
    if (this.state != BinaryReaderState.BEGIN_FUNCTION_BODY
        && this.state != BinaryReaderState.CODE_OPERATOR)
      return;
    this.state = BinaryReaderState.SKIPPING_FUNCTION_BODY;
  }

  public void skipInitExpression()
  {
    while (this.state == BinaryReaderState.INIT_EXPRESSION_OPERATOR)
      this.readCodeOperator();
  }

  public void fetchSectionRawData()
  {
    if (this.state != BinaryReaderState.BEGIN_SECTION)
    {
      this.error = new Error(`Unsupported state: ${this.state}`);
      this.state = BinaryReaderState.ERROR;
      return;
    }
    this.state = BinaryReaderState.READING_SECTION_RAW_DATA;
  }
}
