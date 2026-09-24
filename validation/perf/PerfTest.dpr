program PerfTest;

{ Phase 5.3 performance harness (Delphi side). Measures load (parse) time and
  best/average render time per example SVG through the GDI+ path and writes a
  CSV (default ..\report\perf_delphi.csv) so it can be compared with the LCL
  side (PerfTestLCL.lpr). Sizing policy shared with the other harnesses. }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils,
  System.IOUtils,
  System.Types,
  Winapi.ActiveX,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  SVG,
  Painter,
  PainterGdiPlus;

const
  CExamplesPath = '..\..\tests\examples';
  COutputPath = '..\report\perf_delphi.csv';
  CIter = 5;

function NowMs: Double;  // QueryPerformanceCounter based
var
  C, F: Int64;
begin
  QueryPerformanceFrequency(F);
  QueryPerformanceCounter(C);
  Result := C * 1000.0 / F;
end;

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

procedure MeasureOne(const AFileName: string; var OutFile: Text);
var
  SVG: TSVG;
  Bitmap: TGPBitmap;
  Graphics: TGPGraphics;
  R: TGPRectF;
  W, H, I, Cnt: Integer;
  T0: Double;
  LoadMs, BestMs, SumMs: Double;
  Name: string;
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Invariant;
  Name := ChangeFileExt(ExtractFileName(AFileName), '');
  W := 0;
  H := 0;
  Cnt := 0;
  LoadMs := 0;
  BestMs := 1E9;
  SumMs := 0;

  SVG := TSVG.Create;
  try
    try
      T0 := NowMs;
      SVG.LoadFromFile(AFileName);
      LoadMs := NowMs - T0;
      Cnt := SVG.Count;
      ResolveSize(SVG, W, H);

      if (W > 0) and (H > 0) then
      begin
        Bitmap := TGPBitmap.Create(W, H);
        try
          Graphics := TGPGraphics.Create(Bitmap);
          try
            Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
            R := ToGPRectF(CalcRect(Painter.MakeRect(0.0, 0, W, H), SVG.Width, SVG.Height, baCenterCenter));
            if (SVG.Width <= 0) or (SVG.Height <= 0) then
              R := Winapi.GDIPAPI.MakeRect(0.0, 0, W, H);
            for I := 1 to CIter do
            begin
              Graphics.Clear(MakeColor(255, 255, 255));
              T0 := NowMs;
              SVG.PaintTo(Graphics, R, nil, 0);
              T0 := NowMs - T0;
              if T0 < BestMs then
                BestMs := T0;
              SumMs := SumMs + T0;
            end;
          finally
            Graphics.Free;
          end;
        finally
          Bitmap.Free;
        end;
      end;
    except
      on E: Exception do
      begin
        LoadMs := -1;
        BestMs := -1;
        SumMs := 0;
        WriteLn('error (', Name, '): ', E.Message);
      end;
    end;
  finally
    SVG.Free;
  end;

  WriteLn(OutFile, Format('%s,%d,%d,%d,%.3f,%.3f,%.3f',
    [Name, W, H, Cnt, LoadMs, BestMs, SumMs / CIter], FS));
end;

var
  Files: TStringDynArray;
  F: string;
  OutFile: Text;
  OutPath: string;
begin
  CoInitialize(nil);
  try
    try
      OutPath := COutputPath;
      if ParamCount >= 1 then
        OutPath := ParamStr(1);
      AssignFile(OutFile, OutPath);
      Rewrite(OutFile);
      try
        WriteLn(OutFile, 'name,w,h,count,load_ms,best_ms,avg_ms');
        Files := TDirectory.GetFiles(CExamplesPath, '*.svg');
        for F in Files do
          MeasureOne(F, OutFile);
      finally
        CloseFile(OutFile);
      end;
      WriteLn('PerfTest done: ', OutPath);
    except
      on E: Exception do
      begin
        WriteLn('FATAL: ', E.Message);
        ExitCode := 1;
      end;
    end;
  finally
    CoUninitialize;
  end;
end.