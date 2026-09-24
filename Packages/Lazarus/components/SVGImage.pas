unit SVGImage;

{$MODE Delphi}
{$M+}

interface

uses
  Classes, SysUtils, Controls, Graphics,
  {$IFDEF FPC}
  LMessages,
  {$ELSE}
  Messages,
  {$ENDIF}
  SVG, SVGImageList,
  Painter;

type
  TSVGImage = class(TGraphicControl)
  strict private
    FSVGImage: TSVG;
    FStream: TMemoryStream;
    FCenter: Boolean;
    FProportional: Boolean;
    FStretch: Boolean;
    FAutoSize: Boolean;
    FScale: Double;
    FOpacity: Byte;
    FFileName: TFileName;
    FImageList: TSVGImageList;
    FImageIndex: Integer;
    procedure SetCenter(Value: Boolean);
    procedure SetProportional(Value: Boolean);
    procedure SetOpacity(Value: Byte);
    procedure SetFileName(const Value: TFileName);
    procedure ReadData(Stream: TStream);
    procedure WriteData(Stream: TStream);
    procedure SetImageIndex(const Value: Integer);
    procedure SetStretch(const Value: Boolean);
    procedure SetScale(const Value: Double);
    procedure SetAutoSizeImage(const Value: Boolean);
    procedure WMPaint(var Msg: TLMPaint); message LM_PAINT;
  protected
    procedure DefineProperties(Filer: TFiler); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure CheckAutoSize;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    function Empty: Boolean;
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromStream(Stream: TStream);
    procedure Assign(Source: TPersistent); override;
    property SVG: TSVG read FSVGImage;
  published
    property AutoSize: Boolean read FAutoSize write SetAutoSizeImage;
    property Center: Boolean read FCenter write SetCenter;
    property Proportional: Boolean read FProportional write SetProportional;
    property Stretch: Boolean read FStretch write SetStretch;
    property Opacity: Byte read FOpacity write SetOpacity;
    property Scale: Double read FScale write SetScale;
    property FileName: TFileName read FFileName write SetFileName;
    property ImageList: TSVGImageList read FImageList write FImageList;
    property ImageIndex: Integer read FImageIndex write SetImageIndex;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
  end;

implementation

uses
  {$IFDEF FPC}
  PainterLCL,
  {$ELSE}
  Winapi.Windows, Winapi.GDIPAPI, Winapi.GDIPOBJ, System.IOUtils,
  {$ENDIF}
  Types;

{ TSVGImage }

constructor TSVGImage.Create(AOwner: TComponent);
begin
  inherited;
  FSVGImage := TSVG.Create;
  FProportional := False;
  FCenter := True;
  FStretch := True;
  FOpacity := 255;
  FScale := 1;
  FImageIndex := -1;
  FStream := TMemoryStream.Create;
end;

destructor TSVGImage.Destroy;
begin
  FSVGImage.Free;
  FStream.Free;
  inherited;
end;

procedure TSVGImage.Clear;
begin
  FSVGImage.Clear;
  FFileName := '';
  Invalidate;
end;

function TSVGImage.Empty: Boolean;
begin
  Result := FSVGImage.Count = 0;
end;

procedure TSVGImage.DefineProperties(Filer: TFiler);
begin
  Filer.DefineBinaryProperty('Data', ReadData, WriteData, True);
end;

procedure TSVGImage.CheckAutoSize;
begin
  if FAutoSize and (FSVGImage.Count > 0) then
    SetBounds(Left, Top,
      Round(FSVGImage.Width * FScale),
      Round(FSVGImage.Height * FScale));
end;

procedure TSVGImage.WMPaint(var Msg: TLMPaint);
var
  SVG: TSVG;
  {$IFDEF FPC}
  P: TPainter;
  {$ELSE}
  R: TRect;
  {$ENDIF}
begin
  if Assigned(FImageList) and (FImageIndex >= 0) and
     (FImageIndex < FImageList.Count) then
    SVG := FImageList.SVG[FImageIndex]
  else
    SVG := FSVGImage;

  if SVG.Count = 0 then
    Exit;

  if csDesigning in ComponentState then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Style := psDash;
    Canvas.Pen.Color := clBlack;
    Canvas.Rectangle(0, 0, Width, Height);
  end;

  {$IFDEF FPC}
  P := TPainterLCL.Create(Canvas);
  try
    SVG.SVGOpacity := FOpacity / 255;
    try
      SVG.Paint(P, nil, 0);
    finally
      SVG.SVGOpacity := 1;
    end;
  finally
    P.Free;
  end;
  {$ELSE}
  R := Rect(0, 0, Width, Height);
  SVG.PaintTo(Canvas.Handle, TGPRectF.Create(R.Left, R.Top, R.Right, R.Bottom), nil, 0);
  {$ENDIF}
end;

procedure TSVGImage.ReadData(Stream: TStream);
var
  Size: LongInt;
begin
  Stream.Read(Size, SizeOf(Size));
  FStream.Clear;
  if Size > 0 then
  begin
    FStream.CopyFrom(Stream, Size);
    FSVGImage.LoadFromStream(FStream);
  end
  else
    FSVGImage.Clear;
end;

procedure TSVGImage.WriteData(Stream: TStream);
var
  Size: LongInt;
begin
  Size := FStream.Size;
  Stream.Write(Size, SizeOf(Size));
  FStream.Position := 0;
  if FStream.Size > 0 then
    FStream.SaveToStream(Stream);
end;

procedure TSVGImage.LoadFromFile(const FileName: string);
begin
  if csLoading in ComponentState then
    Exit;
  try
    FStream.Clear;
    FStream.LoadFromFile(FileName);
    FSVGImage.LoadFromStream(FStream);
    FFileName := FileName;
  except
    Clear;
  end;
  CheckAutoSize;
  Invalidate;
end;

procedure TSVGImage.LoadFromStream(Stream: TStream);
begin
  try
    FFileName := '';
    FStream.Clear;
    FStream.LoadFromStream(Stream);
    FSVGImage.LoadFromStream(FStream);
  except
  end;
  CheckAutoSize;
  Invalidate;
end;

procedure TSVGImage.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FImageList) then
    FImageList := nil;
end;

procedure TSVGImage.Assign(Source: TPersistent);
begin
  if Source is TSVGImage then
  begin
    FSVGImage.LoadFromText(TSVGImage(Source).FSVGImage.Source);
    FImageIndex := -1;
    CheckAutoSize;
  end
  else if Source.ClassType = TSVG then
  begin
    FSVGImage.LoadFromText(TSVG(Source).Source);
    FImageIndex := -1;
    CheckAutoSize;
  end;
  Invalidate;
end;

procedure TSVGImage.SetAutoSizeImage(const Value: Boolean);
begin
  if Value = FAutoSize then Exit;
  FAutoSize := Value;
  CheckAutoSize;
end;

procedure TSVGImage.SetCenter(Value: Boolean);
begin
  if Value = FCenter then Exit;
  FCenter := Value;
  Invalidate;
end;

procedure TSVGImage.SetProportional(Value: Boolean);
begin
  if Value = FProportional then Exit;
  FProportional := Value;
  Invalidate;
end;

procedure TSVGImage.SetScale(const Value: Double);
begin
  if Value = FScale then Exit;
  FScale := Value;
  FAutoSize := False;
  Invalidate;
end;

procedure TSVGImage.SetStretch(const Value: Boolean);
begin
  if Value = FStretch then Exit;
  FStretch := Value;
  if FStretch then FAutoSize := False;
  Invalidate;
end;

procedure TSVGImage.SetOpacity(Value: Byte);
begin
  if Value = FOpacity then Exit;
  FOpacity := Value;
  Invalidate;
end;

procedure TSVGImage.SetFileName(const Value: TFileName);
begin
  if Value = FFileName then Exit;
  LoadFromFile(Value);
end;

procedure TSVGImage.SetImageIndex(const Value: Integer);
begin
  if FImageIndex = Value then Exit;
  FImageIndex := Value;
  CheckAutoSize;
  Invalidate;
end;

initialization
  TPicture.RegisterFileFormat('SVG', 'Scalable Vector Graphics', nil);
  RegisterClass(TSVGImage);

end.
