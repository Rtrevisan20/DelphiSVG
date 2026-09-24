program LCLTest;

{$mode objfpc}{$H+}

uses
  Interfaces,
  Classes, SysUtils, Graphics,
  SVG,
  GDIPAPI,
  PainterLCL;

var
  S: TSVG;
  Bmp: TBitmap;
  P: TPainterLCL;
  R: TGPRectF;
  W, H, X, Y, Filled, Total: Integer;
  Scale: Double;
  FileName: string;
  OutFile: string;
begin
  FileName := ParamStr(1);
  if FileName = '' then
    FileName := '..\examples\tiger.svg';
  OutFile := ParamStr(2);
  if OutFile = '' then
    OutFile := 'lcltest.bmp';
  if not FileExists(FileName) then
  begin
    Writeln('Arquivo nao encontrado: ', FileName);
    Halt(1);
  end;

  S := TSVG.Create;
  try
    try
      S.LoadFromFile(FileName);
    except
      on E: Exception do
      begin
        Writeln('Load FAILED: ', E.ClassName, ': ', E.Message);
        DumpExceptionBackTrace(Output);
        Halt(2);
      end;
    end;
    W := Round(S.Width);
    H := Round(S.Height);
    if (W <= 0) or (H <= 0) then
    begin
      W := Round(S.ViewBox.Width);
      H := Round(S.ViewBox.Height);
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

    Writeln(Format('%s: Loaded, Width=%d Height=%d Count=%d',
      [ExtractFileName(FileName), W, H, S.Count]));

    Bmp := TBitmap.Create;
    try
      Bmp.Width := W;
      Bmp.Height := H;
      Bmp.Canvas.Brush.Color := clWhite;
      Bmp.Canvas.FillRect(0, 0, W, H);

      P := TPainterLCL.Create(Bmp.Canvas);
      try
        R.X := 0;
        R.Y := 0;
        R.Width := W;
        R.Height := H;
        S.SetBounds(R);
        try
          S.Paint(P, nil, 0);
        except
          on E: Exception do
          begin
            Writeln('Paint FAILED: ', E.ClassName, ': ', E.Message);
            DumpExceptionBackTrace(Output);
            Halt(2);
          end;
        end;
      finally
        P.Free;
      end;

      Filled := 0;
      Total := 0;
      for Y := 0 to H - 1 do
        for X := 0 to W - 1 do
        begin
          Inc(Total);
          if Bmp.Canvas.Pixels[X, Y] <> clWhite then
            Inc(Filled);
        end;

Bmp.SaveToFile(OutFile);
  Writeln(Format('Filled pixels: %d of %d (%.2f%%)', [Filled, Total, Filled * 100.0 / Total]));
    finally
      Bmp.Free;
    end;
  finally
    S.Free;
  end;
end.