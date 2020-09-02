module wasm2wat.workhorse.range;

class DataRange
{
  int start;
  int end;

  this(int start, int end)
  {
    this.start = start;
    this.end = end;
  }

  public void offset(int delta)
  {
    this.start += delta;
    this.end += delta;
  }
}
