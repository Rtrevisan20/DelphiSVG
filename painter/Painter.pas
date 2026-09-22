unit Painter;

{ TPainter — portable painting abstraction for the DelphiSVG core.

  Task 1.1 of the Delphi + Lazarus port. This unit defines the CONTRACT only:
  it contains no reference to Winapi/GDI+, FMX or LCL, so it compiles under
  both Delphi and Free Pascal. Each backend (TPainterGdiPlus, TPainterLCL)
  implements this contract.

  Types declared here mirror the GDI+ concepts actually used by the svg\ core
  (see the port plan in agents.md). Method names deliberately stay close to
  the GDI+ API to keep the refactoring of svg\ cheap. }

interface

{$IFDEF FPC}
{$MODE Delphi}
{$ENDIF}

uses
{$IFDEF FPC}
  Classes, SysUtils;
{$ELSE}
  System.Classes, System.SysUtils;
{$ENDIF}

type
  { Colors are plain 0xAARRGGBB values, so the core never depends on a
    platform color type. }
  TPainterColor = Cardinal;

  TPainterPoint = record
    X: Single;
    Y: Single;
  end;

  TPainterRect = record
    X: Single;
    Y: Single;
    Width: Single;
    Height: Single;
  end;

  { Affine matrix, 2D used by the SVG transform model (m33 is implied = 1). }
  TPainterMatrix = record
    m11: Single;
    m12: Single;
    m21: Single;
    m22: Single;
    m31: Single;
    m32: Single;
  end;

  TPainterFillMode = (pfmAlternate, pfmWinding);
  TPainterLineCap  = (plcFlat, plcRound, plcSquare);
  TPainterDashCap  = (pdcFlat, pdcRound);
  TPainterLineJoin = (pljMiter, pljRound, pljBevel);
  TPainterDashStyle = (pdsSolid, pdsCustom);

  { Text dekorations / font style bits, equivalent to the GDI+ TFontStyle
    bitmask used today. }
  TPainterFontStyle = set of (pfsBold, pfsItalic, pfsUnderline, pfsStrikeout);

  { Layout options for DrawString / MeasureString. Today the core always uses
    a "generic typographic" format with trailing spaces measured. }
  TPainterTextFormat = record
    GenericTypographic: Boolean;
    MeasureTrailingSpaces: Boolean;
  end;

  { Image drawing options (opacity applied through color matrix in GDI+). }
  TPainterImageOptions = record
    Opacity: Single; // 0..1
  end;

  { Marker for the "not implemented / unsupported" painter features. }
  EPainterError = class(Exception)
  end;

  { Constructors / helpers --------------------------------------------------- }
  function MakePoint(const X, Y: Single): TPainterPoint; overload;
  function MakeRect(const X, Y, W, H: Single): TPainterRect; overload;
  function MakeMatrix(const A11, A12, A21, A22, A31, A32: Single): TPainterMatrix;
  function MakeIdentityMatrix: TPainterMatrix;
  function PainterColor(const A, R, G, B: Byte): TPainterColor; overload;
  function PainterColor(const A: Byte; const Color: TPainterColor): TPainterColor; overload;
  function PainterColorOpacity(const Color: TPainterColor; const Opacity: Single): TPainterColor;
  function MatrixMultiply(const M1, M2: TPainterMatrix): TPainterMatrix;
  function MatrixTransformPoint(const M: TPainterMatrix; const P: TPainterPoint): TPainterPoint;

type
  { Base class for all painter resources (pen, brush, path, font, image).
    Mirrors the GDI+ "last status" concept so validity can be tested the same
    way the core does today. }
  TPainterObject = class
  private
    FLastOK: Boolean;
  protected
    procedure SetStatusOK;      // call when creation/property applied fine
    procedure SetStatusFailed;  // call when an operation failed
  public
    constructor Create; virtual;
    function GetLastStatus: Boolean; virtual; // True = OK
  end;

  TPainterBrush = class(TPainterObject)
  public
    function Clone: TPainterBrush; virtual; abstract;
  end;

  TPainterSolidBrush = class(TPainterBrush)
  private
    FColor: TPainterColor;
  public
    constructor Create(const AColor: TPainterColor); reintroduce;
    property Color: TPainterColor read FColor;
  end;

  { Common gradient behavior shared by linear and radial brushes. }
  TPainterGradientBrush = class(TPainterBrush)
  public
    procedure SetInterpolationColors(const Colors: array of TPainterColor;
      const Positions: array of Single); virtual; abstract;
    procedure SetTransform(const Matrix: TPainterMatrix); virtual; abstract;
  end;

  TPainterLinearGradientBrush = class(TPainterGradientBrush)
  private
    FPoint1: TPainterPoint;
    FPoint2: TPainterPoint;
    FColor1: TPainterColor;
    FColor2: TPainterColor;
  public
    constructor Create(const P1, P2: TPainterPoint;
      const C1, C2: TPainterColor); reintroduce;
    property Point1: TPainterPoint read FPoint1;
    property Point2: TPainterPoint read FPoint2;
    property Color1: TPainterColor read FColor1;
    property Color2: TPainterColor read FColor2;
  end;

  { Radial gradient. GDI+ realizes it as a path gradient brush built from an
    ellipse; LCL will tessellate it. }
  TPainterRadialGradientBrush = class(TPainterGradientBrush)
  private
    FEllipse: TPainterRect; // ellipse that defines the gradient boundary
    FCenter: TPainterPoint;
  public
    constructor Create(const ALeft, ATop, AWidth, AHeight: Single); reintroduce;
    procedure SetCenterPoint(const Center: TPainterPoint); virtual; abstract;
    property Ellipse: TPainterRect read FEllipse;
    property Center: TPainterPoint read FCenter;
  end;

  TPainterPen = class(TPainterObject)
  private
    FColor: TPainterColor;
    FWidth: Single;
  public
    constructor Create(const AColor: TPainterColor; const AWidth: Single); reintroduce;
    procedure SetBrush(const Brush: TPainterBrush); virtual; abstract;
    procedure SetLineJoin(const Join: TPainterLineJoin); virtual; abstract;
    procedure SetMiterLimit(const Limit: Single); virtual; abstract;
    procedure SetLineCap(const StartCap, EndCap: TPainterLineCap;
      const DCap: TPainterDashCap); virtual; abstract;
    procedure SetDashPattern(const Pattern: array of Single); virtual; abstract;
    procedure SetDashStyle(const Style: TPainterDashStyle); virtual; abstract;
    procedure SetDashOffset(const Offset: Single); virtual; abstract;
    property Color: TPainterColor read FColor;
    property Width: Single read FWidth;
  end;

  TPainterFontFamily = class(TPainterObject)
  public
    constructor Create(const AName: string); reintroduce;
    function GetCellAscent(const Style: TPainterFontStyle): Integer; virtual; abstract;
    function GetEmHeight(const Style: TPainterFontStyle): Integer; virtual; abstract;
  end;

  TPainterFont = class(TPainterObject)
  public
    constructor Create(const Family: TPainterFontFamily;
      const Size: Single; const Style: TPainterFontStyle); reintroduce;
  end;

  TPainterImage = class(TPainterObject)
  public
    { Loads an image from an arbitrary stream (SVG <image> data / base64 /
      file bytes). The stream is read fully before returning. }
    constructor CreateFromStream(const Stream: TStream); virtual;
    function GetWidth: Integer; virtual; abstract;
    function GetHeight: Integer; virtual; abstract;
  end;

  { Path building contract. }
  TPainterPath = class(TPainterObject)
  public
    constructor Create; override;
    procedure StartFigure; virtual; abstract;
    procedure CloseFigure; virtual; abstract;
    procedure AddLine(const X1, Y1, X2, Y2: Single); virtual; abstract;
    procedure AddBezier(const X1, Y1, X2, Y2, X3, Y3, X4, Y4: Single); virtual; abstract;
    procedure AddArc(const X, Y, W, H, StartAngle, SweepAngle: Single); virtual; abstract;
    procedure AddEllipse(const X, Y, W, H: Single); virtual; abstract;
    procedure AddRectangle(const Rect: TPainterRect); virtual; abstract;
    procedure AddPolygon(const Points: array of TPainterPoint); virtual; abstract;
    procedure AddPath(const Path: TPainterPath; const Connect: Boolean); virtual; abstract;
    procedure AddString(const Text: string; const Family: TPainterFontFamily;
      const Style: TPainterFontStyle; const Size: Single;
      const Format: TPainterTextFormat); virtual; abstract;
    procedure SetFillMode(const FillMode: TPainterFillMode); virtual; abstract;
    procedure Transform(const Matrix: TPainterMatrix); virtual; abstract;
    function Clone: TPainterPath; virtual;
    function GetPointCount: Integer; virtual; abstract;
  end;

  { The painter itself: everything the svg\ core needs to rasterize. }
  TPainter = class
  public
    constructor Create; virtual;

    { --- resource factories ----------------------------------------------
      A concrete painter backend returns its own subclass instances through
      these factories (the caller owns and frees them). The object graph
      stays portable: the core never sees the backend handles. }
    function CreateSolidBrush(const AColor: TPainterColor): TPainterSolidBrush; virtual; abstract;
    function CreateLinearGradientBrush(const P1, P2: TPainterPoint;
      const C1, C2: TPainterColor): TPainterLinearGradientBrush; virtual; abstract;
    function CreateRadialGradientBrush(const ALeft, ATop, AWidth,
      AHeight: Single): TPainterRadialGradientBrush; virtual; abstract;
    function CreatePen(const AColor: TPainterColor;
      const AWidth: Single): TPainterPen; virtual; abstract;
    function CreateFontFamily(const AName: string): TPainterFontFamily; virtual; abstract;
    function CreateFont(const Family: TPainterFontFamily; const Size: Single;
      const Style: TPainterFontStyle): TPainterFont; virtual; abstract;
    function LoadImage(const Stream: TStream): TPainterImage; virtual; abstract;
    function CreatePath: TPainterPath; virtual; abstract;
    function CreateTextFormat(const GenericTypographic,
      MeasureTrailingSpaces: Boolean): TPainterTextFormat; virtual;

    { --- state ------------------------------------------------------------ }
    procedure SetSmoothingMode(const AntiAlias: Boolean); virtual; abstract;
    procedure SetTransform(const Matrix: TPainterMatrix); virtual; abstract;
    procedure ResetTransform; virtual; abstract;
    procedure GetTransform(out Matrix: TPainterMatrix); virtual; abstract;
    procedure SetClip(const Path: TPainterPath); virtual; abstract;
    procedure ResetClip; virtual; abstract;
    procedure Clear(const Color: TPainterColor); virtual; abstract;

    { --- geometry ---------------------------------------------------------- }
    procedure FillPath(const Brush: TPainterBrush; const Path: TPainterPath); virtual; abstract;
    procedure DrawPath(const Pen: TPainterPen; const Path: TPainterPath); virtual; abstract;
    procedure DrawLine(const Pen: TPainterPen;
      const X1, Y1, X2, Y2: Single); virtual; abstract;

    { --- raster ------------------------------------------------------------ }
    procedure DrawImage(const Image: TPainterImage; const Dest: TPainterRect;
      const Options: TPainterImageOptions); virtual; abstract;

    { --- text -------------------------------------------------------------- }
    procedure DrawString(const Text: string; const Font: TPainterFont;
      const Origin: TPainterPoint; const Format: TPainterTextFormat;
      const Brush: TPainterBrush); virtual; abstract;
    procedure MeasureString(const Text: string; const Font: TPainterFont;
      const Origin: TPainterPoint; const Format: TPainterTextFormat;
      var Rect: TPainterRect); virtual; abstract;
    { Kerning-aware width of a text run (GDI+ path today uses GetKerningPairs). }
    function MeasureText(const Text: string; const Font: TPainterFont): Single; virtual; abstract;

    { Builds the glyphs of Text into Path (used for textPath). }
    procedure AddTextToPath(const Path: TPainterPath; const Text: string;
      const Family: TPainterFontFamily; const Style: TPainterFontStyle;
      const Size: Single; const Origin: TPainterPoint;
      const Format: TPainterTextFormat); virtual; abstract;
    { Length of a flattened path (used by textPath offsets). }
    function GetPathLength(const Path: TPainterPath): Single; virtual; abstract;
  end;

implementation

{ --- helper functions ------------------------------------------------------ }

function MakePoint(const X, Y: Single): TPainterPoint;
begin
  Result.X := X;
  Result.Y := Y;
end;

function MakeRect(const X, Y, W, H: Single): TPainterRect;
begin
  Result.X := X;
  Result.Y := Y;
  Result.Width := W;
  Result.Height := H;
end;

function MakeMatrix(const A11, A12, A21, A22, A31, A32: Single): TPainterMatrix;
begin
  Result.m11 := A11;
  Result.m12 := A12;
  Result.m21 := A21;
  Result.m22 := A22;
  Result.m31 := A31;
  Result.m32 := A32;
end;

function MakeIdentityMatrix: TPainterMatrix;
begin
  Result := MakeMatrix(1, 0, 0, 1, 0, 0);
end;

function PainterColor(const A, R, G, B: Byte): TPainterColor;
begin
  Result := (Cardinal(A) shl 24) or (Cardinal(R) shl 16) or
    (Cardinal(G) shl 8) or Cardinal(B);
end;

function PainterColor(const A: Byte; const Color: TPainterColor): TPainterColor;
begin
  Result := (Cardinal(A) shl 24) or (Color and $00FFFFFF);
end;

function PainterColorOpacity(const Color: TPainterColor;
  const Opacity: Single): TPainterColor;
var
  A: Byte;
begin
  A := Round((Color shr 24 and $FF) * Opacity);
  Result := PainterColor(A, Color and $FFFFFF);
end;

function MatrixMultiply(const M1, M2: TPainterMatrix): TPainterMatrix;
begin
  Result.m11 := M1.m11 * M2.m11 + M1.m12 * M2.m21;
  Result.m12 := M1.m11 * M2.m12 + M1.m12 * M2.m22;
  Result.m21 := M1.m21 * M2.m11 + M1.m22 * M2.m21;
  Result.m22 := M1.m21 * M2.m12 + M1.m22 * M2.m22;
  Result.m31 := M1.m31 * M2.m11 + M1.m32 * M2.m21 + M2.m31;
  Result.m32 := M1.m31 * M2.m12 + M1.m32 * M2.m22 + M2.m32;
end;

function MatrixTransformPoint(const M: TPainterMatrix;
  const P: TPainterPoint): TPainterPoint;
begin
  Result.X := M.m11 * P.X + M.m21 * P.Y + M.m31;
  Result.Y := M.m12 * P.X + M.m22 * P.Y + M.m32;
end;

{ --- TPainterObject -------------------------------------------------------- }

constructor TPainterObject.Create;
begin
  inherited Create;
  FLastOK := True;
end;

function TPainterObject.GetLastStatus: Boolean;
begin
  Result := FLastOK;
end;

procedure TPainterObject.SetStatusOK;
begin
  FLastOK := True;
end;

procedure TPainterObject.SetStatusFailed;
begin
  FLastOK := False;
end;

{ --- TPainterSolidBrush ---------------------------------------------------- }

constructor TPainterSolidBrush.Create(const AColor: TPainterColor);
begin
  inherited Create;
  FColor := AColor;
end;

{ --- TPainterLinearGradientBrush ------------------------------------------- }

constructor TPainterLinearGradientBrush.Create(const P1, P2: TPainterPoint;
  const C1, C2: TPainterColor);
begin
  inherited Create;
  FPoint1 := P1;
  FPoint2 := P2;
  FColor1 := C1;
  FColor2 := C2;
end;

{ --- TPainterRadialGradientBrush ------------------------------------------- }

constructor TPainterRadialGradientBrush.Create(const ALeft, ATop, AWidth,
  AHeight: Single);
begin
  inherited Create;
  FEllipse := MakeRect(ALeft, ATop, AWidth, AHeight);
  FCenter := MakePoint(ALeft + AWidth / 2, ATop + AHeight / 2);
end;

{ --- TPainterPen ----------------------------------------------------------- }

constructor TPainterPen.Create(const AColor: TPainterColor;
  const AWidth: Single);
begin
  inherited Create;
  FColor := AColor;
  FWidth := AWidth;
end;

{ --- TPainterFontFamily ---------------------------------------------------- }

constructor TPainterFontFamily.Create(const AName: string);
begin
  inherited Create;
end;

{ --- TPainterFont ---------------------------------------------------------- }

constructor TPainterFont.Create(const Family: TPainterFontFamily;
  const Size: Single; const Style: TPainterFontStyle);
begin
  inherited Create;
end;

{ --- TPainterImage --------------------------------------------------------- }

constructor TPainterImage.CreateFromStream(const Stream: TStream);
begin
  inherited Create;
end;

{ --- TPainterPath ---------------------------------------------------------- }

constructor TPainterPath.Create;
begin
  inherited Create;
end;

function TPainterPath.Clone: TPainterPath;
begin
  Result := nil;
end;

{ --- TPainter -------------------------------------------------------------- }

constructor TPainter.Create;
begin
  inherited Create;
end;

function TPainter.CreateTextFormat(const GenericTypographic,
  MeasureTrailingSpaces: Boolean): TPainterTextFormat;
begin
  Result.GenericTypographic := GenericTypographic;
  Result.MeasureTrailingSpaces := MeasureTrailingSpaces;
end;

end.