unit JsonViewerUnit;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Clipbrd,
  Vcl.Dialogs;

type
  TJsonViewerForm = class(TForm)
  private
    FTopPanel: TPanel;
    FFileLabel: TLabel;
    FCopyButton: TButton;
    FCloseButton: TButton;
    FMemo: TMemo;
    procedure CopyButtonClick(Sender: TObject);
    procedure CloseButtonClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    procedure LoadJsonFile(const AFileName: string);
  end;

procedure ShowJsonViewer(const AOwner: TComponent; const AFileName: string);

implementation

constructor TJsonViewerForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);

  Caption := 'JSON Viewer';
  Width := 980;
  Height := 720;
  Position := poOwnerFormCenter;

  FTopPanel := TPanel.Create(Self);
  FTopPanel.Parent := Self;
  FTopPanel.Align := alTop;
  FTopPanel.Height := 48;
  FTopPanel.BevelOuter := bvNone;

  FFileLabel := TLabel.Create(Self);
  FFileLabel.Parent := FTopPanel;
  FFileLabel.Left := 12;
  FFileLabel.Top := 17;
  FFileLabel.AutoSize := False;
  FFileLabel.Width := 690;
  FFileLabel.Caption := '';

  FCopyButton := TButton.Create(Self);
  FCopyButton.Parent := FTopPanel;
  FCopyButton.Left := 712;
  FCopyButton.Top := 10;
  FCopyButton.Width := 110;
  FCopyButton.Height := 28;
  FCopyButton.Caption := 'Copy JSON';
  FCopyButton.OnClick := CopyButtonClick;

  FCloseButton := TButton.Create(Self);
  FCloseButton.Parent := FTopPanel;
  FCloseButton.Left := 832;
  FCloseButton.Top := 10;
  FCloseButton.Width := 110;
  FCloseButton.Height := 28;
  FCloseButton.Caption := 'Close';
  FCloseButton.OnClick := CloseButtonClick;

  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := alClient;
  FMemo.ReadOnly := True;
  FMemo.ScrollBars := ssBoth;
  FMemo.WordWrap := False;
  FMemo.Font.Name := 'Consolas';
  FMemo.Font.Size := 10;
end;

procedure TJsonViewerForm.LoadJsonFile(const AFileName: string);
var
  RawText: string;
  JsonValue: TJSONValue;
begin
  if not TFile.Exists(AFileName) then
    raise EFileNotFoundException.CreateFmt('JSON file not found: %s',
      [AFileName]);

  FFileLabel.Caption := AFileName;
  FFileLabel.Hint := AFileName;
  FFileLabel.ShowHint := True;

  RawText := TFile.ReadAllText(AFileName, TEncoding.UTF8);
  JsonValue := TJSONObject.ParseJSONValue(RawText);
  try
    if JsonValue <> nil then
      FMemo.Text := JsonValue.Format(2)
    else
      FMemo.Text := RawText;
  finally
    JsonValue.Free;
  end;

  FMemo.SelStart := 0;
  FMemo.SelLength := 0;
end;

procedure TJsonViewerForm.CopyButtonClick(Sender: TObject);
begin
  Clipboard.AsText := FMemo.Text;
end;

procedure TJsonViewerForm.CloseButtonClick(Sender: TObject);
begin
  Close;
end;

procedure ShowJsonViewer(const AOwner: TComponent; const AFileName: string);
var
  Viewer: TJsonViewerForm;
begin
  Viewer := TJsonViewerForm.Create(AOwner);
  try
    Viewer.LoadJsonFile(AFileName);
    Viewer.ShowModal;
  finally
    Viewer.Free;
  end;
end;

end.
