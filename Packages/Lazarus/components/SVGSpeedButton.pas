unit SVGSpeedButton;

{$MODE Delphi}
{$M+}

interface

uses
  Classes, Controls, Graphics, Windows,
  {$IFDEF FPC}
  LMessages,
  {$ELSE}
  Messages,
  {$ENDIF}
  SVG,
  Painter;

type
  TSVGSpeedButton = class(TWinControl)
  strict private
    FSVG: TSVG;
    function GetSVG: TSVG;
    procedure SetSVG(const Value: TSVG);
  protected
    procedure PaintWindow(DC: HDC); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property SVG: TSVG read GetSVG write SetSVG;
  end;

implementation

uses
  {$IFDEF FPC}
  PainterLCL,
  {$ELSE}
  Winapi.Windows, Winapi.GDIPAPI, Winapi.GDIPOBJ, System.IOUtils,
  Vcl.Themes, Vcl.Controls,
  {$ENDIF}
  Types;

{ TSVGSpeedButton }

constructor TSVGSpeedButton.Create(AOwner: TComponent);
begin
  inherited;
  FSVG := TSVG.Create;
end;

destructor TSVGSpeedButton.Destroy;
begin
  FSVG.Free;
  inherited;
end;

function TSVGSpeedButton.GetSVG: TSVG;
begin
  Result := FSVG;
end;

procedure TSVGSpeedButton.SetSVG(const Value: TSVG);
begin
  if FSVG = Value then Exit;
  FSVG.Assign(Value);
  Invalidate;
end;

procedure TSVGSpeedButton.PaintWindow(DC: HDC);
var
  P: TPainter;
  Canvas: TCanvas;
begin
  Canvas := TCanvas.Create;
  try
    Canvas.Handle := DC;
    P := TPainterLCL.Create(Canvas);
    try
      if FSVG.Count > 0 then
        FSVG.Paint(P, nil, 0);
    finally
      P.Free;
    end;
  finally
    Canvas.Free;
  end;
  inherited;
end;

initialization
  Classes.RegisterClass(TSVGSpeedButton);
end.
