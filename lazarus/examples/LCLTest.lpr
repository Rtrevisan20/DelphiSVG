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
  FileName: string;
begin
  FileName := ParamStr(1);
  if FileName = '' then
    FileName := '..\..\examples\tiger.svg';
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
    if W <= 0 then W := 400;
    if H <= 0 then H := 400;
    if W > 1024 then W := 1024;
    if H > 1024 then H := 1024;

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

      Bmp.SaveToFile('lcltest.bmp');
      Writeln(Format('Filled pixels: %d of %d (%.2f%%)', [Filled, Total, Filled * 100.0 / Total]));
    finally
      Bmp.Free;
    end;
  finally
    S.Free;
  end;
end.