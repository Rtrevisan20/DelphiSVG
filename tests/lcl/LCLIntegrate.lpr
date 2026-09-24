program LCLIntegrate;

{ Phase 5.2 integration harness (Lazarus side). Loads and renders every example
  SVG through the LCL backend (TPainterLCL) and writes a CSV line per file,
  mirroring IntegrationDelphi.dpr from validation\integration.
  Sizing policy is intentionally shared:
    width/height -> viewBox -> 400 pad; if W or H > 1024 scale uniformly by W. }

{$mode objfpc}{$H+}

uses
  Interfaces,
  Classes, SysUtils, Graphics,
  SVG,
  GDIPAPI,
  PainterLCL;

const
  CExamplesPath = '..\examples';
  COutputPath = '..\..\validation\report\integration_lcl.csv';

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
  Name, ErrMsg: string;
  LoadOk, RenderOk: Boolean;
  F: TSearchRec;
  W, H, Count: Integer;
begin
  if ParamCount >= 1 then
    AssignFile(OutFile, ParamStr(1))
  else
    AssignFile(OutFile, COutputPath);
  Rewrite(OutFile);
  try
    WriteLn(OutFile, 'name,load,count,w,h,render,error');
    if FindFirst(CExamplesPath + '\*.svg', faAnyFile, F) = 0 then
    try
      repeat
        Name := ChangeFileExt(F.Name, '');
        S := TSVG.Create;
        LoadOk := False;
        RenderOk := False;
        ErrMsg := '';
        W := 0;
        H := 0;
        Count := 0;
        try
          try
            S.LoadFromFile(CExamplesPath + '\' + F.Name);
            LoadOk := True;
            Count := S.Count;
            ResolveSize(S, W, H);
            Bmp := TBitmap.Create;
            try
              Bmp.Width := W;
              Bmp.Height := H;
              Bmp.Canvas.Brush.Color := clWhite;
              Bmp.Canvas.FillRect(0, 0, W, H);
              P := TPainterLCL.Create(Bmp.Canvas);
              try
                R := GDIPAPI.MakeRect(0.0, 0, W, H);
                S.SetBounds(R);
                S.Paint(P, nil, 0);
                RenderOk := True;
              finally
                P.Free;
              end;
            finally
              Bmp.Free;
            end;
          except
            on E: Exception do
              ErrMsg := E.ClassName + ': ' + E.Message;
          end;
        finally
          S.Free;
        end;
        WriteLn(OutFile, Format('%s,%s,%d,%d,%d,%s,"%s"',
          [Name, BoolToStr(LoadOk, True), Count, W, H, BoolToStr(RenderOk, True), ErrMsg]));
      until FindNext(F) <> 0;
    finally
      FindClose(F);
    end;
  finally
    CloseFile(OutFile);
  end;
  Writeln('LCLIntegrate done.');
end.