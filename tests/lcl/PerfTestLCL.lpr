program PerfTestLCL;

{ Phase 5.3 performance harness (Lazarus side). Mirror of validation\perf\PerfTest.dpr
  using the LCL backend (TPainterLCL). Writes a CSV (default
  ..\..\validation\report\perf_lcl.csv) comparable with perf_delphi.csv. }

{$mode objfpc}{$H+}

uses
  Interfaces,
  Classes, SysUtils, Graphics, LCLIntf,
  SVG,
  GDIPAPI,
  PainterLCL;

function QueryPerformanceFrequency(var L: QWord): LongBool; stdcall; external 'kernel32' name 'QueryPerformanceFrequency';
function QueryPerformanceCounter(var L: QWord): LongBool; stdcall; external 'kernel32' name 'QueryPerformanceCounter';

function NowMs: Double;
var
  C, F: QWord;
begin
  QueryPerformanceFrequency(F);
  QueryPerformanceCounter(C);
  Result := C * 1000.0 / F;
end;

const
  CExamplesPath = '..\examples';
  COutputPath = '..\..\validation\report\perf_lcl.csv';
  CIter = 5;

procedure ResolveSize(SVG: TSVG; var W, H: Integer);
var
  Scale: Double;
begin
  W := Round(SVG.Width);
  H := Round(SVG.Height);
  if (W <= 0) or (H <= 0) then
  begin
    W := Round(SVG.ViewBox.Width);
    H := Round(SVG.ViewBox.Height);
  end;
  if (W <= 0) or (H <= 0) then
  begin
    W := 400;
    H := 400;
  end;
  Scale := 1.0;
  if (W > 1024) or (H > 1024) then
    Scale := 1024.0 / (W * 1.0);
  W := Round(W * Scale);
  H := Round(H * Scale);
end;

var
  S: TSVG;
  Bmp: TBitmap;
  P: TPainterLCL;
  R: TGPRectF;
  OutFile: Text;
  Name, OutPath: string;
  F: TSearchRec;
  W, H, Len, I: LongInt;
  T0: Double;
  LoadMs, BestMs, SumMs: Double;
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  OutPath := COutputPath;
  if ParamCount >= 1 then
    OutPath := ParamStr(1);
  AssignFile(OutFile, OutPath);
  Rewrite(OutFile);
  try
    WriteLn(OutFile, 'name,w,h,count,load_ms,best_ms,avg_ms');
    if FindFirst(CExamplesPath + '\*.svg', faAnyFile, F) = 0 then
    try
      repeat
        Name := ChangeFileExt(F.Name, '');
        S := TSVG.Create;
        W := 0;
        H := 0;
        LoadMs := 0;
        BestMs := 1E9;
        SumMs := 0;
        try
          try
            T0 := NowMs;
            S.LoadFromFile(CExamplesPath + '\' + F.Name);
            LoadMs := NowMs - T0;
            ResolveSize(S, W, H);
            if (W > 0) and (H > 0) then
            begin
              Bmp := TBitmap.Create;
              try
                Bmp.Width := W;
                Bmp.Height := H;
                P := TPainterLCL.Create(Bmp.Canvas);
                try
                  R := GDIPAPI.MakeRect(0.0, 0, W, H);
                  S.SetBounds(R);
                  for I := 1 to CIter do
                  begin
                    Bmp.Canvas.Brush.Color := clWhite;
                    Bmp.Canvas.FillRect(0, 0, W, H);
                    T0 := NowMs;
                    S.Paint(P, nil, 0);
                    T0 := NowMs - T0;
                    if T0 < BestMs then
                      BestMs := T0;
                    SumMs := SumMs + T0;
                  end;
                finally
                  P.Free;
                end;
              finally
                Bmp.Free;
              end;
            end;
          except
            on E: Exception do
            begin
              LoadMs := -1;
              BestMs := -1;
              SumMs := 0;
              Writeln('error (', Name, '): ', E.Message);
            end;
          end;
        finally
          Len := S.Count;
          S.Free;
        end;
        WriteLn(OutFile, Format('%s,%d,%d,%d,%.3f,%.3f,%.3f',
          [Name, W, H, Len, LoadMs, BestMs, SumMs / CIter], FS));
      until FindNext(F) <> 0;
    finally
      FindClose(F);
    end;
  finally
    CloseFile(OutFile);
  end;
  Writeln('PerfTestLCL done.');
end.
