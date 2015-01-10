{===============================================================================

Simple (De)Compression routines (powered by ZLib)

©František Milt 4.2.2012

Version 1.0

===============================================================================}
unit SimpleCompress;

interface

uses
  Classes;

Function ZCompressStream(aStream: TStream): Boolean;
Function ZCompressFile(const FileName: String): Boolean;

Function ZDecompressStream(aStream: TStream): Boolean;
Function ZDecompressFile(const FileName: String): Boolean;

implementation

uses
  SysUtils, Zlib;

const
  buffer_size = 4096{Bytes};

Function ZCompressStream(aStream: TStream): Boolean;
var
  TempStream:     TMemoryStream;
  CompressionStr: TCompressionStream;
begin
try
  TempStream := TMemoryStream.Create;
  try
    CompressionStr := TCompressionStream.Create(clDefault,TempStream);
    try
      CompressionStr.CopyFrom(aStream,0);
    finally
      CompressionStr.Free;
    end;
    aStream.Position := 0;
    aStream.Size := aStream.CopyFrom(TempStream,0);
    Result := True;
  finally
    TempStream.Free;
  end;
except
  Result := False;
end;
end;

Function ZCompressFile(const FileName: String): Boolean;
var
  TempStream: TFileStream;
begin
try
  TempStream := TFileStream.Create(FileName,fmOpenReadWrite or fmShareExclusive);
  try
    Result := ZCompressStream(TempStream);
  finally
    TempStream.Free;
  end;
except
  Result := False;
end;
end;

Function ZDecompressStream(aStream: TStream): Boolean;
var
  TempStream:       TMemoryStream;
  DecompressionStr: TDecompressionStream;
  BuffLen:          Integer;
  Buffer:           Array[0..buffer_size - 1] of Byte;
begin
try
  TempStream := TMemoryStream.Create;
  try
    aStream.Position := 0;
    DecompressionStr := TDecompressionStream.Create(aStream);
    try
      Repeat
        BuffLen := DecompressionStr.Read(Buffer,SizeOf(Buffer));
        TempStream.WriteBuffer(Buffer,BuffLen);
      Until BuffLen <= 0;
    finally
      DecompressionStr.Free;
    end;
    aStream.Position := 0;
    aStream.Size := aStream.CopyFrom(TempStream,0);
    Result := True;
  finally
    TempStream.Free;
  end;
except
  Result := False;
end;
end;

Function ZDecompressFile(const FileName: String): Boolean;
var
  TempStream: TFileStream;
begin
try
  TempStream := TFileStream.Create(FileName,fmOpenReadWrite or fmShareExclusive);
  try
    Result := ZDecompressStream(TempStream);
  finally
    TempStream.Free;
  end;
except
  Result := False;
end;
end;

end.
