program SVGDemo;

{$MODE Delphi}

uses
  Interfaces,
  Forms, Controls, ExtCtrls, StdCtrls, Classes, SysUtils,
  SVG, SVGImage, SVGImageList, SVGSpeedButton;

type
  TNav = class
    procedure PrevClick(Sender: TObject);
    procedure NextClick(Sender: TObject);
  end;

var
  FormMain: TForm;
  Bar: TPanel;
  BtnPrev, BtnNext: TButton;
  LblIndex: TLabel;
  Img: TSVGImage;
  ImgList: TSVGImageList;
  SwBtn: TSVGSpeedButton;
  Nav: TNav;
  CurrentIndex: Integer;

function FindExample(const Name: string): string;
const
  MaxCands = 4;
var
  Cand: array[0..MaxCands - 1] of string;
  I: Integer;
begin
  Cand[0] := ExtractFilePath(ParamStr(0)) + '..\..\..\..\tests\examples\' + Name;
  Cand[1] := ExtractFilePath(ParamStr(0)) + '..\..\..\tests\examples\' + Name;
  Cand[2] := '..\..\..\..\tests\examples\' + Name;
  Cand[3] := '..\..\tests\examples\' + Name;
  Result := '';
  for I := 0 to MaxCands - 1 do
    if FileExists(Cand[I]) then
    begin
      Result := Cand[I];
      Exit;
    end;
end;

procedure LoadList;
var
  Names: array[0..2] of string;
  S: TSVG;
  I: Integer;
begin
  Names[0] := 'circles.svg';
  Names[1] := 'paths.svg';
  Names[2] := 'tiger.svg';
  for I := 0 to 2 do
  begin
    S := TSVG.Create;
    try
      S.LoadFromFile(FindExample(Names[I]));
      ImgList.Add(S, ChangeFileExt(Names[I], ''));
    finally
      S.Free;
    end;
  end;
end;

procedure UpdateImage;
begin
  if CurrentIndex < 0 then
    CurrentIndex := ImgList.Count - 1;
  if CurrentIndex >= ImgList.Count then
    CurrentIndex := 0;
  Img.ImageIndex := CurrentIndex;
  LblIndex.Caption := Format('Imagem: %d/%d (%s)   |   TSVGSpeedButton: 32x32 embutido',
    [CurrentIndex + 1, ImgList.Count, ImgList.Names[CurrentIndex]]);
end;

procedure TNav.PrevClick(Sender: TObject);
begin
  Dec(CurrentIndex);
  UpdateImage;
end;

procedure TNav.NextClick(Sender: TObject);
begin
  Inc(CurrentIndex);
  UpdateImage;
end;

var
  SmallSVG: TSVG;
begin
  Application.Initialize;
  Application.MainFormOnTaskBar := True;

  CurrentIndex := 0;
  Nav := TNav.Create;

  FormMain := TForm.Create(nil);
  FormMain.Caption := 'DelphiSVG (LCL) - TSVGImage / TSVGImageList / TSVGSpeedButton';
  FormMain.Position := poScreenCenter;
  FormMain.ClientWidth := 1080;
  FormMain.ClientHeight := 720;

  Bar := TPanel.Create(FormMain);
  Bar.Parent := FormMain;
  Bar.Align := alTop;
  Bar.Height := 44;
  Bar.Caption := '';

  BtnPrev := TButton.Create(FormMain);
  BtnPrev.Parent := Bar;
  BtnPrev.Caption := '< Anterior';
  BtnPrev.Left := 8;
  BtnPrev.Top := 10;
  BtnPrev.OnClick := Nav.PrevClick;

  BtnNext := TButton.Create(FormMain);
  BtnNext.Parent := Bar;
  BtnNext.Caption := 'Proximo >';
  BtnNext.Left := 120;
  BtnNext.Top := 10;
  BtnNext.OnClick := Nav.NextClick;

  LblIndex := TLabel.Create(FormMain);
  LblIndex.Parent := Bar;
  LblIndex.Left := 260;
  LblIndex.Top := 16;

  SwBtn := TSVGSpeedButton.Create(FormMain);
  SwBtn.Parent := Bar;
  SwBtn.Left := 700;
  SwBtn.Top := 6;
  SwBtn.Width := 32;
  SwBtn.Height := 32;
  SmallSVG := TSVG.Create;
  try
    SmallSVG.LoadFromText(
      '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32">' +
      '<rect width="32" height="32" rx="6" fill="#2196F3"/>' +
      '<circle cx="16" cy="16" r="7" fill="#FFC107"/>' +
      '<path d="M8 20 L14 20 L11 26 Z" fill="#fff"/></svg>');
    SwBtn.SVG.Assign(SmallSVG);
  finally
    SmallSVG.Free;
  end;

  ImgList := TSVGImageList.Create(FormMain);
  ImgList.Opacity := 255;
  LoadList;

  Img := TSVGImage.Create(FormMain);
  Img.Parent := FormMain;
  Img.Align := alClient;
  Img.ImageList := ImgList;
  UpdateImage;

  Application.CreateForm(TForm, FormMain);
  Application.Run;

  Nav.Free;
  ImgList.Free;
  Img.Free;
  SwBtn.Free;
  Bar.Free;
  FormMain.Free;
end.