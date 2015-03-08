{-------------------------------------------------------------------------------

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.

-------------------------------------------------------------------------------}
{===============================================================================

Simple (De)Compression routines (powered by ZLib)

©František Milt 2015-01-10

Version 1.1

===============================================================================}
unit SimpleCompress;

interface

uses
  Classes;

Function ZCompressStream(Stream: TStream): Boolean;
Function ZCompressFile(const FileName: String): Boolean;

Function ZDecompressStream(Stream: TStream): Boolean;
Function ZDecompressFile(const FileName: String): Boolean;

implementation

uses
  SysUtils, {$IFDEF FPC}ZStream{$ELSE}Zlib{$ENDIF};

const
  buffer_size = 4096{Bytes};

Function ZCompressStream(Stream: TStream): Boolean;
var
  TempStream:     TMemoryStream;
  CompressionStr: TCompressionStream;
begin
try
  TempStream := TMemoryStream.Create;
  try
    CompressionStr := TCompressionStream.Create(clDefault,TempStream);
    try
      CompressionStr.CopyFrom(Stream,0);
    finally
      CompressionStr.Free;
    end;
    Stream.Position := 0;
    Stream.Size := Stream.CopyFrom(TempStream,0);
    Result := True;
  finally
    TempStream.Free;
  end;
except
  Result := False;
end;
end;

//------------------------------------------------------------------------------

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

//------------------------------------------------------------------------------

Function ZDecompressStream(Stream: TStream): Boolean;
var
  TempStream:       TMemoryStream;
  DecompressionStr: TDecompressionStream;
  BytesRead:        Integer;
  Buffer:           Pointer;
begin
try
  TempStream := TMemoryStream.Create;
  try
    Stream.Position := 0;
    DecompressionStr := TDecompressionStream.Create(Stream);
    try
      GetMem(Buffer,buffer_size);
      try
        repeat
          BytesRead := DecompressionStr.Read(Buffer^,SizeOf(Buffer));
          TempStream.WriteBuffer(Buffer^,BytesRead);
        until BytesRead <= 0;
      finally
        FreeMem(Buffer,buffer_size);
      end;
    finally
      DecompressionStr.Free;
    end;
    Stream.Position := 0;
    Stream.Size := Stream.CopyFrom(TempStream,0);
    Result := True;
  finally
    TempStream.Free;
  end;
except
  Result := False;
end;
end;

//------------------------------------------------------------------------------

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
