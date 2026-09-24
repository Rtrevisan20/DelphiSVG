unit SVGImageRegister;

{$MODE Delphi}

interface

uses
  Classes, Controls,
  SVGImage,
  SVGImageList,
  SVGSpeedButton;

procedure Register;

implementation

uses
  LResources;

procedure Register;
begin
  RegisterComponents('SVG', [TSVGImage, TSVGImageList, TSVGSpeedButton]);
end;

initialization

{$I svgicons.lrs}

end.
