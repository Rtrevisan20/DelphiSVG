unit SVGImgLstEditor;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, Math, Graphics, Controls, Forms, Dialogs, ExtCtrls,
  StdCtrls, ComCtrls, ImgList, ExtDlgs, Types,
  PropEdits, ComponentEditors,
  SVG, Painter, PainterLCL, SVGImageList;

procedure Register;

type
  TImageListEditorForm = class(TForm)
  private
    FList: TSVGImageList;
    FOnModify: TNotifyEvent;
    FThumbs: TImageList;
    FOpenDlg: TOpenPictureDialog;
    FSaveDlg: TSavePictureDialog;
    FBottom: TPanel;
    FSide: TPanel;
    FDoc: TPanel;
    FTool: TPanel;
    FLV: TListView;
    FBtnAdd: TButton;
    FBtnDelete: TButton;
    FBtnClear: TButton;
    FBtnReplace: TButton;
    FBtnExport: TButton;
    FNameGroup: TGroupBox;
    FPrevGroup: TGroupBox;
    FPreview: TImage;
    FEName: TEdit;
    FBtnRename: TButton;
    FBtnClose: TButton;
    procedure CreateControls;
    procedure RebuildIcons;
    procedure UpdatePreview;
    procedure NotifyModified;
    procedure DoAdd(Sender: TObject);
    procedure DoDelete(Sender: TObject);
    procedure DoClear(Sender: TObject);
    procedure DoReplace(Sender: TObject);
    procedure DoExport(Sender: TObject);
    procedure DoRename(Sender: TObject);
    procedure LVSelect(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure BtnCloseClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    procedure InitializeEditor(AList: TSVGImageList; AOnModify: TNotifyEvent);
  end;

  TSVGImageListEditor = class(TComponentEditor)
  private
    procedure NotifyModified(Sender: TObject);
  public
    procedure Edit; override;
    function GetVerbCount: Integer; override;
    function GetVerb(Index: Integer): string; override;
    procedure ExecuteVerb(Index: Integer); override;
  end;

  TSVGImageListProperty = class(TPropertyEditor)
  private
    procedure NotifyModified(Sender: TObject);
  public
    function GetAttributes: TPropertyAttributes; override;
    function GetValue: ansistring; override;
    procedure Edit; override;
  end;

implementation

function FitBitmapKeepAspect(const Src: TBitmap; TargetW, TargetH: Integer): TBitmap;
var
  Scale: Double;
  W, H: Integer;
  X, Y: Integer;
begin
  Result := TBitmap.Create;
  Result.Width := TargetW;
  Result.Height := TargetH;
  Result.Canvas.Brush.Color := clWhite;
  Result.Canvas.FillRect(Rect(0, 0, TargetW, TargetH));
  if (Src = nil) or (Src.Width <= 0) or (Src.Height <= 0) then
    Exit;
  Scale := Min(TargetW / Src.Width, TargetH / Src.Height);
  W := Max(1, Round(Src.Width * Scale));
  H := Max(1, Round(Src.Height * Scale));
  X := (TargetW - W) div 2;
  Y := (TargetH - H) div 2;
  Result.Canvas.StretchDraw(Rect(X, Y, X + W, Y + H), Src);
end;

function RenderSVGThumb(const ASVG: TSVG; IconW, IconH: Integer): TBitmap;
const
  MaxCanvas = 1024;
var
  W, H: Double;
  FullW, FullH: Integer;
  Scale: Double;
  Full: TBitmap;
  P: TPainter;
  Gray: Boolean;
begin
  Gray := False;
  if ASVG = nil then
    Gray := True
  else
  begin
    W := ASVG.Width;
    H := ASVG.Height;
    if ((W <= 0) and (H <= 0)) or (W <> W) or (H <> H) then
    begin
      W := 64;
      H := 64;
      Gray := True;
    end
    else
    begin
      if W <= 0 then W := H;
      if H <= 0 then H := W;
      if W = 0 then W := 64;
      if H = 0 then H := 64;
    end;
  end;

  FullW := Round(W);
  FullH := Round(H);
  if FullW < 1 then FullW := 1;
  if FullH < 1 then FullH := 1;
  Scale := 1;
  if FullW > MaxCanvas then Scale := MaxCanvas / FullW;
  if (FullH * Scale) > MaxCanvas then Scale := MaxCanvas / FullH;
  FullW := Max(1, Round(FullW * Scale));
  FullH := Max(1, Round(FullH * Scale));

  Full := TBitmap.Create;
  try
    Full.Width := FullW;
    Full.Height := FullH;
    Full.Canvas.Brush.Color := clWhite;
    Full.Canvas.FillRect(Rect(0, 0, FullW, FullH));
    if Gray then
      Full.Canvas.TextOut(2, 2, '<svg n/a>')
    else
    begin
      try
        P := TPainterLCL.Create(Full.Canvas);
        try
          ASVG.Paint(P, nil, 0);
        finally
          P.Free;
        end;
      except
        Full.Canvas.TextOut(2, 2, '!render');
      end;
    end;
    Result := FitBitmapKeepAspect(Full, IconW, IconH);
  finally
    Full.Free;
  end;
end;

procedure RunSVGImageListEditor(AList: TSVGImageList; AOnModify: TNotifyEvent);
var
  F: TImageListEditorForm;
begin
  if AList = nil then
    Exit;
  F := TImageListEditorForm.Create(nil);
  try
    F.InitializeEditor(AList, AOnModify);
    F.ShowModal;
  finally
    F.Free;
  end;
end;

{ TImageListEditorForm }

constructor TImageListEditorForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  CreateControls;
end;

procedure TImageListEditorForm.CreateControls;
begin
  Caption := 'SVG Image List Editor';
  Width := 720;
  Height := 460;
  Position := poScreenCenter;

  FThumbs := TImageList.Create(Self);
  FThumbs.Width := 24;
  FThumbs.Height := 24;
  FThumbs.AllocBy := 16;

  FOpenDlg := TOpenPictureDialog.Create(Self);
  FOpenDlg.Filter := 'SVG files (*.svg)|*.svg';
  FOpenDlg.Options := FOpenDlg.Options + [ofFileMustExist, ofAllowMultiSelect];

  FSaveDlg := TSavePictureDialog.Create(Self);
  FSaveDlg.Filter := 'SVG files (*.svg)|*.svg';
  FSaveDlg.DefaultExt := '.svg';

  FBottom := TPanel.Create(Self);
  FBottom.Parent := Self;
  FBottom.Align := alBottom;
  FBottom.Height := 44;

  FSide := TPanel.Create(Self);
  FSide.Parent := Self;
  FSide.Align := alRight;
  FSide.Width := 280;

  FDoc := TPanel.Create(Self);
  FDoc.Parent := Self;
  FDoc.Align := alClient;

  FNameGroup := TGroupBox.Create(Self);
  FNameGroup.Parent := FSide;
  FNameGroup.Align := alBottom;
  FNameGroup.Height := 110;
  FNameGroup.Caption := 'Name';

  FEName := TEdit.Create(Self);
  FEName.Parent := FNameGroup;
  FEName.Align := alTop;
  FEName.SetBounds(8, 20, 200, 24);

  FBtnRename := TButton.Create(Self);
  FBtnRename.Parent := FNameGroup;
  FBtnRename.Caption := 'Rename';
  FBtnRename.OnClick := DoRename;
  FBtnRename.SetBounds(8, 52, 120, 26);

  FPrevGroup := TGroupBox.Create(Self);
  FPrevGroup.Parent := FSide;
  FPrevGroup.Align := alClient;
  FPrevGroup.Caption := 'Preview';

  FPreview := TImage.Create(Self);
  FPreview.Parent := FPrevGroup;
  FPreview.Align := alClient;

  FTool := TPanel.Create(Self);
  FTool.Parent := FDoc;
  FTool.Align := alTop;
  FTool.Height := 36;

  FBtnAdd := TButton.Create(Self);
  FBtnAdd.Parent := FTool;
  FBtnAdd.Caption := 'Add...';
  FBtnAdd.Align := alLeft;
  FBtnAdd.Width := 75;
  FBtnAdd.BorderSpacing.Left := 4;
  FBtnAdd.OnClick := DoAdd;

  FBtnDelete := TButton.Create(Self);
  FBtnDelete.Parent := FTool;
  FBtnDelete.Caption := 'Delete';
  FBtnDelete.Align := alLeft;
  FBtnDelete.Width := 75;
  FBtnDelete.BorderSpacing.Left := 4;
  FBtnDelete.OnClick := DoDelete;

  FBtnClear := TButton.Create(Self);
  FBtnClear.Parent := FTool;
  FBtnClear.Caption := 'Clear';
  FBtnClear.Align := alLeft;
  FBtnClear.Width := 75;
  FBtnClear.BorderSpacing.Left := 4;
  FBtnClear.OnClick := DoClear;

  FBtnReplace := TButton.Create(Self);
  FBtnReplace.Parent := FTool;
  FBtnReplace.Caption := 'Replace...';
  FBtnReplace.Align := alLeft;
  FBtnReplace.Width := 85;
  FBtnReplace.BorderSpacing.Left := 4;
  FBtnReplace.OnClick := DoReplace;

  FBtnExport := TButton.Create(Self);
  FBtnExport.Parent := FTool;
  FBtnExport.Caption := 'Export...';
  FBtnExport.Align := alLeft;
  FBtnExport.Width := 85;
  FBtnExport.BorderSpacing.Left := 4;
  FBtnExport.OnClick := DoExport;

  FLV := TListView.Create(Self);
  FLV.Parent := FDoc;
  FLV.Align := alClient;
  FLV.ViewStyle := vsSmallIcon;
  FLV.SmallImages := FThumbs;
  FLV.OnSelectItem := LVSelect;

  FBtnClose := TButton.Create(Self);
  FBtnClose.Parent := FBottom;
  FBtnClose.Caption := 'Close';
  FBtnClose.Align := alRight;
  FBtnClose.Width := 90;
  FBtnClose.BorderSpacing.Right := 8;
  FBtnClose.OnClick := BtnCloseClick;
end;

procedure TImageListEditorForm.InitializeEditor(AList: TSVGImageList;
  AOnModify: TNotifyEvent);
begin
  FList := AList;
  FOnModify := AOnModify;
  if FList = nil then
    Exit;
  RebuildIcons;
end;

procedure TImageListEditorForm.RebuildIcons;
var
  i: Integer;
  Bmp: TBitmap;
  Item: TListItem;
begin
  FThumbs.Clear;
  FLV.Items.Clear;
  if (FList = nil) or (FList.Items.Count = 0) then
  begin
    UpdatePreview;
    Exit;
  end;
  for i := 0 to FList.Items.Count - 1 do
  begin
    Bmp := RenderSVGThumb(FList.Items[i].SVG, FThumbs.Width, FThumbs.Height);
    try
      Item := FLV.Items.Add;
      Item.Caption := FList.Items[i].Name;
      Item.ImageIndex := FThumbs.Add(Bmp, nil);
    finally
      Bmp.Free;
    end;
  end;
  FLV.ItemIndex := 0;
end;

procedure TImageListEditorForm.UpdatePreview;
var
  Bmp: TBitmap;
  W, H: Integer;
begin
  W := Max(1, FPreview.Width);
  H := Max(1, FPreview.Height);
  Bmp := RenderSVGThumb(nil, W, H);
  try
    if (FList <> nil) and (FLV.ItemIndex >= 0) and
       (FLV.ItemIndex < FList.Items.Count) then
    begin
      Bmp.Free;
      Bmp := RenderSVGThumb(FList.Items[FLV.ItemIndex].SVG, W, H);
    end;
    FPreview.Picture.Assign(Bmp);
  finally
    Bmp.Free;
  end;
end;

procedure TImageListEditorForm.NotifyModified;
begin
  if Assigned(FOnModify) then
    FOnModify(Self);
end;

procedure TImageListEditorForm.DoAdd(Sender: TObject);
var
  i: Integer;
  FS: TFileStream;
  Item: TSVGCollectionItem;
  Changed: Boolean;
begin
  if FList = nil then
    Exit;
  if not FOpenDlg.Execute then
    Exit;
  Changed := False;
  for i := 0 to FOpenDlg.Files.Count - 1 do
  begin
    Item := FList.Items.Add;
    try
      FS := TFileStream.Create(FOpenDlg.Files[i], fmOpenRead or fmShareDenyWrite);
      try
        Item.SVG.LoadFromStream(FS);
        Item.Name := ChangeFileExt(ExtractFileName(FOpenDlg.Files[i]), '');
        Changed := True;
      finally
        FS.Free;
      end;
    except
      FList.Items.Delete(Item.Index);
      MessageDlg('Could not load ' + FOpenDlg.Files[i] + '.',
        mtError, [mbOK], 0);
    end;
  end;
  if Changed then
  begin
    RebuildIcons;
    UpdatePreview;
    NotifyModified;
  end;
end;

procedure TImageListEditorForm.DoDelete(Sender: TObject);
begin
  if (FList = nil) or (FLV.ItemIndex < 0) then
    Exit;
  FList.Items.Delete(FLV.ItemIndex);
  RebuildIcons;
  UpdatePreview;
  NotifyModified;
end;

procedure TImageListEditorForm.DoClear(Sender: TObject);
begin
  if FList = nil then
    Exit;
  if FList.Items.Count = 0 then
    Exit;
  if MessageDlg('Remove all images from the list?', mtConfirmation,
    [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FList.Items.Clear;
  RebuildIcons;
  UpdatePreview;
  NotifyModified;
end;

procedure TImageListEditorForm.DoReplace(Sender: TObject);
var
  FS: TFileStream;
begin
  if (FList = nil) or (FLV.ItemIndex < 0) then
    Exit;
  FOpenDlg.Options := FOpenDlg.Options - [ofAllowMultiSelect];
  if not FOpenDlg.Execute then
    Exit;
  try
    FS := TFileStream.Create(FOpenDlg.FileName, fmOpenRead or fmShareDenyWrite);
    try
      FList.Items[FLV.ItemIndex].SVG.LoadFromStream(FS);
    finally
      FS.Free;
    end;
    RebuildIcons;
    UpdatePreview;
    NotifyModified;
  except
    MessageDlg('Could not load ' + FOpenDlg.FileName + '.',
      mtError, [mbOK], 0);
  end;
end;

procedure TImageListEditorForm.DoExport(Sender: TObject);
var
  FS: TFileStream;
begin
  if (FList = nil) or (FLV.ItemIndex < 0) then
    Exit;
  FSaveDlg.FileName := FList.Items[FLV.ItemIndex].Name + '.svg';
  if not FSaveDlg.Execute then
    Exit;
  FS := TFileStream.Create(FSaveDlg.FileName, fmCreate);
  try
    FList.Items[FLV.ItemIndex].SVG.SaveToStream(FS);
  finally
    FS.Free;
  end;
end;

procedure TImageListEditorForm.DoRename(Sender: TObject);
begin
  if (FList = nil) or (FLV.ItemIndex < 0) then
    Exit;
  FList.Items[FLV.ItemIndex].Name := FEName.Text;
  FLV.Items[FLV.ItemIndex].Caption := FEName.Text;
  NotifyModified;
end;

procedure TImageListEditorForm.LVSelect(Sender: TObject; Item: TListItem;
  Selected: Boolean);
begin
  if not Selected then
    Exit;
  if (FList <> nil) and (Item <> nil) and (Item.Index < FList.Items.Count) then
  begin
    FEName.Text := FList.Items[Item.Index].Name;
    UpdatePreview;
  end;
end;

procedure TImageListEditorForm.BtnCloseClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

{ TSVGImageListEditor }

procedure TSVGImageListEditor.NotifyModified(Sender: TObject);
begin
  Modified;
end;

procedure TSVGImageListEditor.Edit;
begin
  RunSVGImageListEditor(Component as TSVGImageList, NotifyModified);
end;

function TSVGImageListEditor.GetVerbCount: Integer;
begin
  Result := 1;
end;

function TSVGImageListEditor.GetVerb(Index: Integer): string;
begin
  if Index = 0 then
    Result := 'Editor...'
  else
    Result := '';
end;

procedure TSVGImageListEditor.ExecuteVerb(Index: Integer);
begin
  if Index = 0 then
    Edit;
end;

{ TSVGImageListProperty }

procedure TSVGImageListProperty.NotifyModified(Sender: TObject);
begin
  Modified;
end;

function TSVGImageListProperty.GetAttributes: TPropertyAttributes;
begin
  Result := [paDialog];
end;

function TSVGImageListProperty.GetValue: ansistring;
var
  AList: TSVGImageList;
begin
  Result := '(0)';
  if (GetComponent(0) <> nil) and (GetComponent(0) is TSVGImageList) then
  begin
    AList := TSVGImageList(GetComponent(0));
    Result := Format('(%d)', [AList.Items.Count]);
  end;
end;

procedure TSVGImageListProperty.Edit;
begin
  if (GetComponent(0) <> nil) and (GetComponent(0) is TSVGImageList) then
    RunSVGImageListEditor(TSVGImageList(GetComponent(0)), NotifyModified);
end;

procedure Register;
begin
  RegisterComponentEditor(TSVGImageList, TSVGImageListEditor);
  RegisterPropertyEditor(TypeInfo(TSVGCollectionItems), TSVGImageList, 'Items',
    TSVGImageListProperty);
end;

end.