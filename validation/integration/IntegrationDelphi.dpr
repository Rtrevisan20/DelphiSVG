program IntegrationDelphi;

{ Phase 5.2 integration harness (Delphi side). Loads and renders every example
  SVG through the GDI+ path and writes a CSV line per file so the result can be
  compared against the Lazarus/LCL side (integration_lcl.csv).
  Sizing policy is intentionally shared with LCLTest.lpr:
    width/height -> viewBox -> 400 pad; if W or H > 1024 scale uniformly by W. }

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
  COutputPath = '..\report\integration_delphi.csv';

function ResolveSize(SVG: TSVG; var W, H: Integer): Boolean;
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
  Result := (W > 0) and (H > 0);
end;

procedure ProcessOne(const AFileName: string; var OutFile: Text);
var
  SVG: TSVG;
  Bitmap: TGPBitmap;
  Graphics: TGPGraphics;
  R: TGPRectF;
  W, H: Integer;
  LoadOk, RenderOk: Boolean;
  ErrMsg: string;
  Name: string;
  Count: Integer;
begin
  Name := ChangeFileExt(ExtractFileName(AFileName), '');
  LoadOk := False;
  RenderOk := False;
  ErrMsg := '';
  W := 0;
  H := 0;
  Count := 0;

  SVG := TSVG.Create;
  try
    try
      SVG.LoadFromFile(AFileName);
      LoadOk := True;
      Count := SVG.Count;
      ResolveSize(SVG, W, H);
      if LoadOk then
      begin
        Bitmap := TGPBitmap.Create(W, H);
        try
          Graphics := TGPGraphics.Create(Bitmap);
          try
            Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
            Graphics.Clear(MakeColor(255, 255, 255));
            R := ToGPRectF(CalcRect(Painter.MakeRect(0.0, 0, W, H), SVG.Width, SVG.Height, baCenterCenter));
            if (SVG.Width <= 0) or (SVG.Height <= 0) then
              R := Winapi.GDIPAPI.MakeRect(0.0, 0, W, H);
            SVG.PaintTo(Graphics, R, nil, 0);
            RenderOk := True;
          finally
            Graphics.Free;
          end;
        finally
          Bitmap.Free;
        end;
      end;
    except
      on E: Exception do
        ErrMsg := E.ClassName + ': ' + E.Message;
    end;
  finally
    SVG.Free;
  end;

  WriteLn(OutFile, Format('%s,%s,%d,%d,%d,%s,"%s"',
    [Name, BoolToStr(LoadOk, True), Count, W, H, BoolToStr(RenderOk, True), ErrMsg]));
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
        WriteLn(OutFile, 'name,load,count,w,h,render,error');
        Files := TDirectory.GetFiles(CExamplesPath, '*.svg');
        for F in Files do
          ProcessOne(F, OutFile);
      finally
        CloseFile(OutFile);
      end;
      WriteLn('IntegrationDelphi done: ', OutPath);
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