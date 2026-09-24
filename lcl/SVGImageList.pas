unit SVGImageList;

{$MODE Delphi}
{$M+}

interface

uses
  Classes, SysUtils, Controls, Graphics,
  SVG,
  Painter;

type
  TSVGCollectionItem = class(TCollectionItem)
  strict private
    FName: string;
    FSVG: TSVG;
    procedure SetName(const Value: string);
    procedure SetSVG(const Value: TSVG);
    procedure ReadSVG(Stream: TStream);
    procedure WriteSVG(Stream: TStream);
  protected
    procedure AssignTo(Dest: TPersistent); override;
    procedure DefineProperties(Filer: TFiler); override;
  public
    constructor Create(Collection: TCollection); override;
    destructor Destroy; override;
    property SVG: TSVG read FSVG write SetSVG;
  published
    property Name: string read FName write SetName;
  end;

  TSVGCollectionItems = class(TCollection)
  strict private
    FOwner: TPersistent;
    function GetItem(Index: Integer): TSVGCollectionItem;
    procedure SetItem(Index: Integer; const Value: TSVGCollectionItem);
  protected
    procedure Update(Item: TCollectionItem); override;
    procedure Notify(Item: TCollectionItem; Action: TCollectionNotification); override;
    function GetOwner: TPersistent; override;
  public
    constructor Create(AOwner: TPersistent);
    function Add: TSVGCollectionItem;
    procedure Assign(Source: TPersistent); override;
    property Items[Index: Integer]: TSVGCollectionItem read GetItem write SetItem; default;
  end;

  TSVGImageList = class(TComponent)
  strict private
    FImages: TSVGCollectionItems;
    FOpacity: Byte;
    function GetCount: Integer;
    function GetImages(Index: Integer): TSVG;
    function GetNames(Index: Integer): string;
    procedure SetImages(Index: Integer; const Value: TSVG);
    procedure SetNames(Index: Integer; const Value: string);
    procedure SetOpacity(const Value: Byte);
    procedure SetItems(const Value: TSVGCollectionItems);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Draw(ACanvas: TCanvas; X, Y, Index: Integer);
    function Add(const SVG: TSVG; const Name: string): Integer;
    procedure Delete(const Index: Integer);
    procedure Clear;
    function IndexOf(const Name: string): Integer;
    property Count: Integer read GetCount;
    property SVG[Index: Integer]: TSVG read GetImages write SetImages; default;
    property Names[Index: Integer]: string read GetNames write SetNames;
    property Opacity: Byte read FOpacity write SetOpacity default 255;
  published
    property Items: TSVGCollectionItems read FImages write SetItems;
  end;

implementation

uses
  {$IFDEF FPC}
  PainterLCL,
  {$ENDIF}
  StrUtils;

{ TSVGCollectionItem }

constructor TSVGCollectionItem.Create(Collection: TCollection);
begin
  inherited Create(Collection);
  FSVG := TSVG.Create;
end;

destructor TSVGCollectionItem.Destroy;
begin
  FSVG.Free;
  inherited;
end;

procedure TSVGCollectionItem.SetName(const Value: string);
begin
  if FName = Value then Exit;
  FName := Value;
  Changed(False);
end;

procedure TSVGCollectionItem.SetSVG(const Value: TSVG);
begin
  if FSVG = Value then Exit;
  FSVG.Assign(Value);
end;

procedure TSVGCollectionItem.ReadSVG(Stream: TStream);
var
  Size: LongInt;
  S: TMemoryStream;
begin
  Stream.Read(Size, SizeOf(Size));
  if Size > 0 then
  begin
    SetLength(FName, Size);
    Stream.Read(PChar(FName)^, Size * SizeOf(Char));
  end;
  Stream.Read(Size, SizeOf(Size));
  if Size > 0 then
  begin
    S := TMemoryStream.Create;
    try
      S.CopyFrom(Stream, Size);
      S.Position := 0;
      FSVG.LoadFromStream(S);
    finally
      S.Free;
    end;
  end
  else
    FSVG.Clear;
end;

procedure TSVGCollectionItem.WriteSVG(Stream: TStream);
var
  Size: LongInt;
  S: TMemoryStream;
begin
  Size := Length(FName);
  Stream.Write(Size, SizeOf(Size));
  if Size > 0 then
    Stream.WriteBuffer(PChar(FName)^, Size * SizeOf(Char));
  S := TMemoryStream.Create;
  try
    FSVG.SaveToStream(S);
    Size := S.Size;
    Stream.Write(Size, SizeOf(Size));
    S.Position := 0;
    if Size > 0 then
      Stream.CopyFrom(S, Size);
  finally
    S.Free;
  end;
end;

procedure TSVGCollectionItem.DefineProperties(Filer: TFiler);
begin
  inherited;
  Filer.DefineBinaryProperty('SVGData', ReadSVG, WriteSVG, FSVG.Source <> '');
end;

procedure TSVGCollectionItem.AssignTo(Dest: TPersistent);
begin
  if Dest is TSVGCollectionItem then
  begin
    TSVGCollectionItem(Dest).FSVG.Assign(FSVG);
    TSVGCollectionItem(Dest).FName := FName;
  end
  else
    inherited;
end;

{ TSVGCollectionItems }

constructor TSVGCollectionItems.Create(AOwner: TPersistent);
begin
  inherited Create(TSVGCollectionItem);
  FOwner := AOwner;
end;

function TSVGCollectionItems.GetItem(Index: Integer): TSVGCollectionItem;
begin
  Result := TSVGCollectionItem(inherited Items[Index]);
end;

procedure TSVGCollectionItems.SetItem(Index: Integer;
  const Value: TSVGCollectionItem);
begin
  inherited Items[Index] := Value;
end;

procedure TSVGCollectionItems.Update(Item: TCollectionItem);
begin
  inherited;
end;

procedure TSVGCollectionItems.Notify(Item: TCollectionItem;
  Action: TCollectionNotification);
begin
  inherited;
end;

function TSVGCollectionItems.GetOwner: TPersistent;
begin
  Result := FOwner;
end;

function TSVGCollectionItems.Add: TSVGCollectionItem;
begin
  Result := TSVGCollectionItem(inherited Add);
end;

procedure TSVGCollectionItems.Assign(Source: TPersistent);
begin
  if Source is TSVGCollectionItems then
    inherited Assign(Source)
  else
    inherited;
end;

{ TSVGImageList }

constructor TSVGImageList.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FImages := TSVGCollectionItems.Create(Self);
  FOpacity := 255;
end;

destructor TSVGImageList.Destroy;
begin
  FImages.Free;
  inherited;
end;

procedure TSVGImageList.SetItems(const Value: TSVGCollectionItems);
begin
  if Value = FImages then
    Exit;
  if Value <> nil then
    FImages.Assign(Value)
  else
    FImages.Clear;
end;

function TSVGImageList.GetCount: Integer;
begin
  Result := FImages.Count;
end;

function TSVGImageList.GetImages(Index: Integer): TSVG;
begin
  Result := FImages[Index].SVG;
end;

function TSVGImageList.GetNames(Index: Integer): string;
begin
  Result := FImages[Index].Name;
end;

procedure TSVGImageList.SetImages(Index: Integer; const Value: TSVG);
begin
  FImages[Index].SVG.Assign(Value);
end;

procedure TSVGImageList.SetNames(Index: Integer; const Value: string);
begin
  FImages[Index].Name := Value;
end;

procedure TSVGImageList.SetOpacity(const Value: Byte);
begin
  if FOpacity = Value then Exit;
  FOpacity := Value;
end;

procedure TSVGImageList.Draw(ACanvas: TCanvas; X, Y, Index: Integer);
var
  ASVG: TSVG;
  P: TPainter;
begin
  if (Index < 0) or (Index >= FImages.Count) then Exit;
  ASVG := FImages[Index].SVG;
  if ASVG.Count = 0 then Exit;

  {$IFDEF FPC}
  P := TPainterLCL.Create(ACanvas);
  try
    ASVG.SVGOpacity := FOpacity / 255;
    try
      ASVG.Paint(P, nil, 0);
    finally
      ASVG.SVGOpacity := 1;
    end;
  finally
    P.Free;
  end;
  {$ENDIF}
end;

function TSVGImageList.Add(const SVG: TSVG; const Name: string): Integer;
var
  Item: TSVGCollectionItem;
begin
  Item := FImages.Add;
  Item.SVG.Assign(SVG);
  Item.Name := Name;
  Result := Item.Index;
end;

procedure TSVGImageList.Delete(const Index: Integer);
begin
  if (Index >= 0) and (Index < FImages.Count) then
    FImages.Delete(Index);
end;

procedure TSVGImageList.Clear;
begin
  FImages.Clear;
end;

function TSVGImageList.IndexOf(const Name: string): Integer;
begin
  Result := -1;
  for Result := 0 to FImages.Count - 1 do
    if SameText(FImages[Result].Name, Name) then Exit;
end;

initialization
  RegisterClass(TSVGImageList);
end.
