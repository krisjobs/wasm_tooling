module wasm2wat.workhorse.value;

import std.typecons : Nullable;

class Value64
{
  private ubyte[] _data;

  this(Nullable!ubyte[] data)
  {
    this._data = data.isNull() ? new ubyte[8] : data;
  }

  public ubyte[] getData()
  {
    return this._data;
  }

  // ==========================================

  public int toInt32()
  {
    return (this._data[0] | (this._data[1] << 8) | (this._data[2] << 16) | (this._data[3] << 24));
  }

  // ==========================================

  public double toDouble()
  {
    var power = 1;
    var sum;
    if (this._data[7] & 0x80)
    {
      sum = -1;
      for (var i = 0; i < 8; i++, power *= 256)
        sum -= power * (0xff ^ this._data[i]);
    }
    else
    {
      sum = 0;
      for (var i = 0; i < 8; i++, power *= 256)
        sum += power * this._data[i];
    }
    return sum;
  }

  // ==========================================

  public string toString()
  {
    var low = (this._data[0] | (this._data[1] << 8) | (this._data[2] << 16) | (this._data[3] << 24)) >>> 0;
    var high = (this._data[4] | (this._data[5] << 8) | (this._data[6] << 16) | (this._data[7] << 24)) >>> 0;
    if (low == 0 && high == 0)
    {
      return "0";
    }

    var sign = false;
    if (high >> 31)
    {
      high = 4294967296 - high;
      if (low > 0)
      {
        high--;
        low = 4294967296 - low;
      }
      sign = true;
    }
    var buf = [];
    while (high > 0)
    {
      var t = (high % 10) * 4294967296 + low;
      high = Math.floor(high / 10);
      buf.unshift((t % 10).toString());
      low = Math.floor(t / 10);
    }
    while (low > 0)
    {
      buf.unshift((low % 10).toString());
      low = Math.floor(low / 10);
    }
    if (sign)
      buf.unshift("-");
    return buf.join("");
  }
}
