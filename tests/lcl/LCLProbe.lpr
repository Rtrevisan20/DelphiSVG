program LCLProbe;

{$mode objfpc}{$H+}

uses
  Interfaces,
  Classes, SysUtils, Graphics,
  Painter,
  PainterLCL;

var
  Bmp: TBitmap;
  P: TPainterLCL;
  Path: TPainterPath;
  Brush: TPainterBrush;
  X, Y, Filled, Total: Integer;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.Width := 200;
    Bmp.Height := 200;
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(0, 0, 200, 200);

    P := TPainterLCL.Create(Bmp.Canvas);
    try
      Path := NewSVGPath;
      Writeln('NewSVGPath nil? ', Path = nil);
      if Path <> nil then
      try
        Path.AddRectangle(MakeRect(20, 20, 120, 120));
        Brush := P.CreateSolidBrush(PainterColor(255, 255, 0, 0));
        try
          P.FillPath(Brush, Path);
        finally
          Brush.Free;
        end;
      finally
        Path.Free;
      end;

      Filled := 0;
      Total := 0;
      for Y := 0 to 199 do
        for X := 0 to 199 do
        begin
          Inc(Total);
          if Bmp.Canvas.Pixels[X, Y] <> clWhite then
            Inc(Filled);
        end;
      Bmp.SaveToFile('lclprobe.bmp');
      Writeln(Format('Probe filled: %d of %d', [Filled, Total]));
    finally
      P.Free;
    end;
  finally
    Bmp.Free;
  end;
end.