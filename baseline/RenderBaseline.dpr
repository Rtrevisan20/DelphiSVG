program RenderBaseline;

{ Generates reference PNG baselines for the test SVGs using the Delphi
  GDI+ rendering path. Output goes to the png\ subfolder.
  (c) DelphiSVG port work — part of test baseline task. }

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
  GDIPUtils;

const
  CPngEncoder: TGUID = '{557CF406-1A04-11D3-9A73-0000F81EF32E}';
  CMaxPixels = 1024;
  CExamplesPath = '..\examples';
  COutputPath = 'png';

function SaveBitmapToFile(Bitmap: TGPBitmap; const AFileName: string): Boolean;
var
  Status: TStatus;
begin
  Status := Bitmap.Save(PWideChar(AFileName), CPngEncoder);
  Result := (Status = Ok);
  if not Result then
    WriteLn('   (save status=', Ord(Status), ')');
end;

procedure RenderOne(const AFileName: string);
var
  SVG: TSVG;
  Bitmap: TGPBitmap;
  Graphics: TGPGraphics;
  R: TGPRectF;
  W, H: Integer;
  Scale: Double;
  OutName: string;
begin
  OutName := TPath.Combine(COutputPath, ChangeFileExt(ExtractFileName(AFileName), '.png'));
  if TFile.Exists(OutName) then
  begin
    WriteLn('skip (exists): ', OutName);
    Exit;
  end;

  SVG := TSVG.Create;
  try
    SVG.LoadFromFile(AFileName);
    if SVG.Count = 0 then
    begin
      WriteLn('skip (empty): ', ExtractFileName(AFileName));
      Exit;
    end;

    W := Round(SVG.Width);
    H := Round(SVG.Height);
    if (W <= 0) or (H <= 0) then
    begin
      W := Round(SVG.ViewBox.Width);
      H := Round(SVG.ViewBox.Height);
    end;
    if (W <= 0) or (H <= 0) then
    begin
      WriteLn('skip (no size): ', ExtractFileName(AFileName));
      Exit;
    end;

    Scale := 1.0;
    if (W > CMaxPixels) or (H > CMaxPixels) then
      Scale := CMaxPixels / (W * 1.0);
    W := Round(W * Scale);
    H := Round(H * Scale);

    Bitmap := TGPBitmap.Create(W, H);
    try
      Graphics := TGPGraphics.Create(Bitmap);
      try
        Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
        Graphics.Clear(MakeColor(255, 255, 255));
        R := CalcRect(MakeRect(0.0, 0, W, H), SVG.Width * Scale, SVG.Height * Scale, baCenterCenter);
        if (SVG.Width <= 0) or (SVG.Height <= 0) then
          R := MakeRect(0.0, 0, W, H);
        SVG.PaintTo(Graphics, R, nil, 0);
      finally
        Graphics.Free;
      end;
      if SaveBitmapToFile(Bitmap, OutName) then
        WriteLn('ok: ', OutName, '  ', W, 'x', H)
      else
        WriteLn('FAILED save: ', OutName);
    finally
      Bitmap.Free;
    end;
  finally
    SVG.Free;
  end;
end;

var
  Files: TStringDynArray;
  F: string;
begin
  CoInitialize(nil);
  try
    try
      if not TDirectory.Exists(COutputPath) then
        TDirectory.CreateDirectory(COutputPath);

      Files := TDirectory.GetFiles(CExamplesPath, '*.svg');
      WriteLn(Format('%d reference SVGs found.', [Length(Files)]));
      for F in Files do
      begin
        try
          RenderOne(F);
        except
          on E: Exception do
            WriteLn('error (', ExtractFileName(F), '): ', E.Message);
        end;
      end;
      WriteLn('Done.');
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