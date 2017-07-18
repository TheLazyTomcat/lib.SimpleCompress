{-------------------------------------------------------------------------------

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.

-------------------------------------------------------------------------------}
{===============================================================================

  Simple (De)Compression routines (powered by ZLib)

  ©František Milt 2017-07-18

  Version 1.2.2

  Dependencies:
    AuxTypes - github.com/ncs-sniper/Lib.AuxTypes
    StrRect  - github.com/ncs-sniper/Lib.StrRect

===============================================================================}
unit SimpleCompress;

{$IFDEF FPC}
  {$MODE ObjFPC}{$H+}
{$ENDIF}

interface

uses
  Classes;

Function ZCompressBuffer(InBuff: Pointer; InSize: Integer; out OutBuff: Pointer; out OutSize: Integer): Boolean;
Function ZCompressStream(Stream: TStream): Boolean; overload;
Function ZCompressStream(InStream, OutStream: TStream): Boolean; overload;
Function ZCompressFile(const FileName: String): Boolean; overload;
Function ZCompressFile(const InFileName, OutFileName: String): Boolean; overload;

Function ZDecompressBuffer(InBuff: Pointer; InSize: Integer; out OutBuff: Pointer; out OutSize: Integer): Boolean;
Function ZDecompressStream(Stream: TStream): Boolean; overload;
Function ZDecompressStream(InStream, OutStream: TStream): Boolean; overload;
Function ZDecompressFile(const FileName: String): Boolean; overload;
Function ZDecompressFile(const InFileName, OutFileName: String): Boolean; overload;

implementation

uses
  SysUtils,{$IFDEF FPC} PasZLib, ZStream{$ELSE} Zlib{$ENDIF}, AuxTypes, StrRect;

const
  buffer_size = $100000 {1MiB};

// Because TStream.CopyFrom can be painfully slow...
procedure CopyStream(Src, Dest: TStream);
var
  Buffer:     Pointer;
  BytesRead:  Integer;
begin
GetMem(Buffer,buffer_size);
try
  Src.Position := 0;
  Dest.Position := 0;
  repeat
    BytesRead := Src.Read(Buffer^,buffer_size);
    Dest.WriteBuffer(Buffer^,BytesRead);
  until BytesRead < buffer_size;
  Dest.Size := Src.Size;
finally
  FreeMem(Buffer,buffer_size);
end;
end;

//------------------------------------------------------------------------------

Function CheckResultCode(ResultCode: Integer): Integer;
begin
Result := ResultCode;
If ResultCode < 0 then
  raise Exception.CreateFmt('Zlib error %d.',[ResultCode]);
end;

//==============================================================================

Function ZCompressBuffer(InBuff: Pointer; InSize: Integer; out OutBuff: Pointer; out OutSize: Integer): Boolean;
{$IFDEF FPC}
var
  ZStream:    TZStream;
  SizeDelta:  Integer;
  ResultCode: Integer;
{$ENDIF}  
begin
try
  OutBuff := nil;
  OutSize := 0;
{$IFDEF FPC}
  FillChar({%H-}ZStream,SizeOf(TZStream),0);
  SizeDelta := ((InSize div 4) + 255) and not Integer(255);
  OutSize := SizeDelta;
  CheckResultCode(DeflateInit(ZStream,Z_DEFAULT_COMPRESSION));
  try
    ResultCode := Z_OK;
    ZStream.next_in := InBuff;
    ZStream.avail_in := InSize;
    repeat
      ReallocMem(OutBuff,OutSize);
      ZStream.next_out := {%H-}Pointer({%H-}PtrUInt(OutBuff) + PtrUInt(ZStream.total_out));
      ZStream.avail_out := Cardinal(OutSize) - ZStream.total_out;
      ResultCode := CheckResultCode(Deflate(ZStream,Z_NO_FLUSH));
      Inc(OutSize, SizeDelta);
    until (ResultCode = Z_STREAM_END) or (ZStream.avail_in = 0);
    // flush what is left in zlib internal state
    while ResultCode <> Z_STREAM_END do
      begin
        ReallocMem(OutBuff,OutSize);
        ZStream.next_out := {%H-}Pointer({%H-}PtrUInt(OutBuff) + PtrUInt(ZStream.total_out));
        ZStream.avail_out := Cardinal(OutSize) - ZStream.total_out;
        ResultCode := CheckResultCode(Deflate(ZStream,Z_FINISH));
        Inc(OutSize, SizeDelta);
      end;
    OutSize := ZStream.total_out;
    ReallocMem(OutBuff,OutSize);
    Result := True;
  finally
    CheckResultCode(DeflateEnd(ZStream));
  end;
{$ELSE}
// newer than Delphi 7 (but no idea when it has really changed)
{$IF CompilerVersion >= 16}
  ZCompress(InBuff,InSize,OutBuff,OutSize);
{$ELSE}
  CompressBuf(InBuff,InSize,OutBuff,OutSize);
{$IFEND}
  Result := True;
{$ENDIF}
except
  Result := False;
  If Assigned(OutBuff) and (OutSize <> 0) then
    FreeMem(OutBuff,OutSize);
end;
end;

//------------------------------------------------------------------------------

Function ZCompressStream(Stream: TStream): Boolean;
var
  TempStream:         TMemoryStream;
  CompressionStream:  TCompressionStream;
  Buffer:             Pointer;
  BytesRead:          Integer;
begin
try
  TempStream := TMemoryStream.Create;
  try
    CompressionStream := TCompressionStream.Create(clDefault,TempStream);
    try
     GetMem(Buffer,buffer_size);
      try
        Stream.Position := 0;
        repeat
          BytesRead := Stream.Read(Buffer^,buffer_size);
          CompressionStream.WriteBuffer(Buffer^,BytesRead);
        until BytesRead < buffer_size;
      finally
        FreeMem(Buffer,buffer_size);
      end;
    finally
      CompressionStream.Free;
    end;
    CopyStream(TempStream,Stream);
    Result := True;
  finally
    TempStream.Free;
  end;
except
  Result := False;
end;
end;

//   ---   ---   ---   ---   ---   ---   ---   ---   ---   ---   ---   ---   ---

Function ZCompressStream(InStream, OutStream: TStream): Boolean;
var
  CompressionStream:  TCompressionStream;
  Buffer:             Pointer;
  BytesRead:          Integer;
begin
try
  If InStream = OutStream then
    Result := ZCompressStream(InStream)
  else
    begin
      OutStream.Position := 0;    
      CompressionStream := TCompressionStream.Create(clDefault,OutStream);
      try
       GetMem(Buffer,buffer_size);
        try
          InStream.Position := 0;
          repeat
            BytesRead := InStream.Read(Buffer^,buffer_size);
            CompressionStream.WriteBuffer(Buffer^,BytesRead);
          until BytesRead < buffer_size;
        finally
          FreeMem(Buffer,buffer_size);
        end;
      finally
        CompressionStream.Free;
      end;
      OutStream.Size := OutStream.Position;
      Result := True;      
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
  TempStream := TFileStream.Create(StrToRTL(FileName),fmOpenReadWrite or fmShareExclusive);
  try
    Result := SimpleCompress.ZCompressStream(TempStream);
  finally
    TempStream.Free;
  end;
except
  Result := False;
end;
end;

//   ---   ---   ---   ---   ---   ---   ---   ---   ---   ---   ---   ---   ---

Function ZCompressFile(const InFileName, OutFileName: String): Boolean;
var
  InFileStream:   TFileStream;
  OutFileStream:  TFileStream;
begin
If AnsiSameText(InFileName,OutFileName) then
  Result := ZCompressFile(InFileName)
else
  begin
    InFileStream := TFileStream.Create(StrToRTL(InFileName),fmOpenRead or fmShareDenyWrite);
    try
      OutFileStream := TFileStream.Create(StrToRTL(OutFileName),fmCreate or fmShareExclusive);
      try
        Result := SimpleCompress.ZCompressStream(InFileStream,OutFileStream);
      finally
        OutFileStream.Free;
      end;
    finally
      InFileStream.Free;
    end;
  end;
end;

//==============================================================================

Function ZDecompressBuffer(InBuff: Pointer; InSize: Integer; out OutBuff: Pointer; out OutSize: Integer): Boolean;
{$IFDEF FPC}
var
  ZStream:    TZStream;
  SizeDelta:  Integer;
  ResultCode: Integer;
{$ENDIF}  
begin
try
  OutBuff := nil;
  OutSize := 0;
{$IFDEF FPC}
  FillChar({%H-}ZStream,SizeOf(TZStream),0);
  SizeDelta := (InSize + 255) and not Integer(255);
  OutSize := SizeDelta;
  CheckResultCode(InflateInit(ZStream));
  try
    ResultCode := Z_OK;
    ZStream.next_in := InBuff;
    ZStream.avail_in := InSize;
    while (ResultCode <> Z_STREAM_END) and (ZStream.avail_in > 0) do
      repeat
        ReallocMem(OutBuff,OutSize);
        ZStream.next_out := {%H-}Pointer({%H-}PtrUInt(OutBuff) + PtrUInt(ZStream.total_out));
        ZStream.avail_out := Cardinal(OutSize) - ZStream.total_out;
        ResultCode := CheckResultCode(Inflate(ZStream,Z_NO_FLUSH));
        Inc(OutSize, SizeDelta);
      until (ResultCode = Z_STREAM_END) or (ZStream.avail_out > 0);
    OutSize := ZStream.total_out;
    ReallocMem(OutBuff,OutSize);
    Result := True;
  finally
    CheckResultCode(InflateEnd(ZStream));
  end;
{$ELSE}
{$IF CompilerVersion >= 16}
  ZDecompress(InBuff,InSize,OutBuff,OutSize);
{$ELSE}
  DecompressBuf(InBuff,InSize,buffer_size,OutBuff,OutSize);
{$IFEND}
  Result := True;
{$ENDIF}
except
  Result := False;
  If Assigned(OutBuff) and (OutSize <> 0) then
    FreeMem(OutBuff,OutSize);
end;
end;

//------------------------------------------------------------------------------

Function ZDecompressStream(Stream: TStream): Boolean;
var
  TempStream:           TMemoryStream;
  DecompressionStream:  TDecompressionStream;
  Buffer:               Pointer;
  BytesRead:            Integer;
begin
try
  TempStream := TMemoryStream.Create;
  try
    Stream.Position := 0;
    DecompressionStream := TDecompressionStream.Create(Stream);
    try
      GetMem(Buffer,buffer_size);
      try
        repeat
          BytesRead := DecompressionStream.Read(Buffer^,buffer_size);
          TempStream.WriteBuffer(Buffer^,BytesRead);
        until BytesRead < buffer_size;
      finally
        FreeMem(Buffer,buffer_size);
      end;
    finally
      DecompressionStream.Free;
    end;
    CopyStream(TempStream,Stream);
    Result := True;
  finally
    TempStream.Free;
  end;
except
  Result := False;
end;
end;

//   ---   ---   ---   ---   ---   ---   ---   ---   ---   ---   ---   ---   ---

Function ZDecompressStream(InStream, OutStream: TStream): Boolean;
var
  DecompressionStream:  TDecompressionStream;
  Buffer:               Pointer;
  BytesRead:            Integer;
begin
try
  InStream.Position := 0;
  DecompressionStream := TDecompressionStream.Create(InStream);
  try
    GetMem(Buffer,buffer_size);
    try
      OutStream.Position := 0;
      repeat
        BytesRead := DecompressionStream.Read(Buffer^,buffer_size);
        OutStream.WriteBuffer(Buffer^,BytesRead);
      until BytesRead < buffer_size;
    finally
      FreeMem(Buffer,buffer_size);
    end;
  finally
    DecompressionStream.Free;
  end;
  OutStream.Size := OutStream.Position;
  Result := True;
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
  TempStream := TFileStream.Create(StrToRTL(FileName),fmOpenReadWrite or fmShareExclusive);
  try
    Result := SimpleCompress.ZDecompressStream(TempStream);
  finally
    TempStream.Free;
  end;
except
  Result := False;
end;
end;

//------------------------------------------------------------------------------

Function ZDecompressFile(const InFileName, OutFileName: String): Boolean;
var
  InFileStream:   TFileStream;
  OutFileStream:  TFileStream;
begin
If AnsiSameText(InFileName,OutFileName) then
  Result := ZCompressFile(InFileName)
else
  begin
    InFileStream := TFileStream.Create(StrToRTL(InFileName),fmOpenRead or fmShareDenyWrite);
    try
      OutFileStream := TFileStream.Create(StrToRTL(OutFileName),fmCreate or fmShareExclusive);
      try
        Result := SimpleCompress.ZDecompressStream(InFileStream,OutFileStream);
      finally
        OutFileStream.Free;
      end;
    finally
      InFileStream.Free;
    end;
  end;
end;

end.
