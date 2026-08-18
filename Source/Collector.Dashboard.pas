unit Collector.Dashboard;

interface

uses
  System.Classes,
  System.SysUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Graphics,
  Vcl.Edge;

procedure ApplyCollectorDashboard(const AForm: TForm);

implementation

type
  TDashboardController = class(TComponent)
  private
    FForm: TForm;
    FSetupPanel: TPanel;
    FHeaderPanel: TPanel;
    FBottomPanel: TPanel;
    FBrowserPanel: TPanel;
    FBrowser: TEdgeBrowser;
    FLogMemo: TMemo;
    FProgressLabel: TLabel;
    FStatusLabel: TLabel;
    FProgressBar: TProgressBar;
    FActivityLabel: TLabel;
    FMatchesValue: TLabel;
    FCollectedValue: TLabel;
    FPendingValue: TLabel;
    FStateValue: TLabel;
    FTimer: TTimer;
    procedure BuildDashboard;
    procedure TimerTick(Sender: TObject);
    function FindTopPanel(const AAlign: TAlign): TPanel;
    function FindControlRecursive(const AParent: TWinControl;
      const AClass: TClass): TControl;
    function FindLabelContaining(const AParent: TWinControl;
      const AText: string): TLabel;
    function NewCard(const AParent: TWinControl; const ALeft, ATop,
      AWidth, AHeight: Integer; const ACaption: string): TLabel;
  public
    constructor CreateDashboard(const AForm: TForm);
  end;

function TDashboardController.FindTopPanel(const AAlign: TAlign): TPanel;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FForm.ControlCount - 1 do
    if (FForm.Controls[I] is TPanel) and
       (TPanel(FForm.Controls[I]).Align = AAlign) then
      Exit(TPanel(FForm.Controls[I]));
end;

function TDashboardController.FindControlRecursive(const AParent: TWinControl;
  const AClass: TClass): TControl;
var
  I: Integer;
  Child: TControl;
begin
  Result := nil;
  if AParent = nil then
    Exit;

  for I := 0 to AParent.ControlCount - 1 do
  begin
    Child := AParent.Controls[I];
    if Child.InheritsFrom(AClass) then
      Exit(Child);
    if Child is TWinControl then
    begin
      Result := FindControlRecursive(TWinControl(Child), AClass);
      if Result <> nil then
        Exit;
    end;
  end;
end;

function TDashboardController.FindLabelContaining(const AParent: TWinControl;
  const AText: string): TLabel;
var
  I: Integer;
  Child: TControl;
begin
  Result := nil;
  if AParent = nil then
    Exit;

  for I := 0 to AParent.ControlCount - 1 do
  begin
    Child := AParent.Controls[I];
    if (Child is TLabel) and
       (Pos(LowerCase(AText), LowerCase(TLabel(Child).Caption)) > 0) then
      Exit(TLabel(Child));
  end;
end;

function TDashboardController.NewCard(const AParent: TWinControl;
  const ALeft, ATop, AWidth, AHeight: Integer;
  const ACaption: string): TLabel;
var
  Card: TPanel;
  CaptionLabel: TLabel;
begin
  Card := TPanel.Create(Self);
  Card.Parent := AParent;
  Card.SetBounds(ALeft, ATop, AWidth, AHeight);
  Card.BevelOuter := bvNone;
  Card.Color := clWhite;
  Card.ParentBackground := False;

  CaptionLabel := TLabel.Create(Self);
  CaptionLabel.Parent := Card;
  CaptionLabel.SetBounds(16, 12, AWidth - 32, 18);
  CaptionLabel.Caption := ACaption;
  CaptionLabel.Font.Name := 'Segoe UI Semibold';
  CaptionLabel.Font.Size := 8;
  CaptionLabel.Font.Color := RGB(100, 116, 139);

  Result := TLabel.Create(Self);
  Result.Parent := Card;
  Result.SetBounds(16, 38, AWidth - 32, 34);
  Result.Caption := '0';
  Result.Font.Name := 'Segoe UI Semibold';
  Result.Font.Size := 18;
  Result.Font.Color := RGB(15, 23, 42);
end;

constructor TDashboardController.CreateDashboard(const AForm: TForm);
begin
  inherited Create(AForm);
  FForm := AForm;
  BuildDashboard;
end;

procedure TDashboardController.BuildDashboard;
var
  Pages: TPageControl;
  OverviewTab: TTabSheet;
  BrowserTab: TTabSheet;
  LogTab: TTabSheet;
  OutputTab: TTabSheet;
  OverviewBody: TPanel;
  TitleLabel: TLabel;
  CurrentCard: TPanel;
  InfoLabel: TLabel;
  ModeCombo: TComboBox;
  I: Integer;
begin
  if FForm = nil then
    Exit;

  FForm.Caption := 'Flashscore Football Collector v46';
  FForm.Color := RGB(241, 245, 249);
  FForm.Font.Name := 'Segoe UI';
  FForm.Font.Size := 10;
  FForm.Constraints.MinWidth := 1180;
  FForm.Constraints.MinHeight := 720;

  FHeaderPanel := FindTopPanel(alTop);
  FSetupPanel := FindTopPanel(alLeft);
  FBottomPanel := FindTopPanel(alBottom);
  FBrowserPanel := FindTopPanel(alClient);

  if FHeaderPanel <> nil then
  begin
    FHeaderPanel.Height := 68;
    FHeaderPanel.Color := RGB(15, 23, 42);
    FHeaderPanel.ParentBackground := False;
    for I := 0 to FHeaderPanel.ControlCount - 1 do
      if FHeaderPanel.Controls[I] is TLabel then
      begin
        TLabel(FHeaderPanel.Controls[I]).Font.Name := 'Segoe UI';
        if I = 0 then
        begin
          TLabel(FHeaderPanel.Controls[I]).Caption := 'Flashscore Collector';
          TLabel(FHeaderPanel.Controls[I]).Font.Name := 'Segoe UI Semibold';
        end;
      end;
  end;

  if FSetupPanel <> nil then
  begin
    FSetupPanel.Width := 320;
    FSetupPanel.Color := clWhite;
    FSetupPanel.ParentBackground := False;
    FProgressLabel := FindLabelContaining(FSetupPanel, 'Progress');
    FStatusLabel := FindLabelContaining(FSetupPanel, 'Idle');
    FProgressBar := TProgressBar(FindControlRecursive(FSetupPanel, TProgressBar));

    ModeCombo := nil;
    for I := 0 to FSetupPanel.ControlCount - 1 do
      if FSetupPanel.Controls[I] is TComboBox then
        if TComboBox(FSetupPanel.Controls[I]).Items.IndexOf('Full season / tournament') >= 0 then
        begin
          ModeCombo := TComboBox(FSetupPanel.Controls[I]);
          Break;
        end;
    if ModeCombo <> nil then
      ModeCombo.Items[ModeCombo.Items.IndexOf('Full season / tournament')] :=
        'Current season update / full season';
  end;

  if FBottomPanel <> nil then
  begin
    FLogMemo := TMemo(FindControlRecursive(FBottomPanel, TMemo));
    FBottomPanel.Height := 34;
    FBottomPanel.Padding.SetBounds(0, 0, 0, 0);
    FBottomPanel.Color := RGB(226, 232, 240);
    FBottomPanel.ParentBackground := False;

    FActivityLabel := TLabel.Create(Self);
    FActivityLabel.Parent := FBottomPanel;
    FActivityLabel.Align := alClient;
    FActivityLabel.Layout := tlCenter;
    FActivityLabel.Caption := '  Ready';
    FActivityLabel.Font.Size := 9;
    FActivityLabel.Font.Color := RGB(71, 85, 105);
  end;

  if FBrowserPanel = nil then
    Exit;

  FBrowser := TEdgeBrowser(FindControlRecursive(FBrowserPanel, TEdgeBrowser));

  Pages := TPageControl.Create(Self);
  Pages.Parent := FBrowserPanel;
  Pages.Align := alClient;
  Pages.TabHeight := 30;

  OverviewTab := TTabSheet.Create(Self);
  OverviewTab.PageControl := Pages;
  OverviewTab.Caption := 'Overview';

  BrowserTab := TTabSheet.Create(Self);
  BrowserTab.PageControl := Pages;
  BrowserTab.Caption := 'Browser';

  LogTab := TTabSheet.Create(Self);
  LogTab.PageControl := Pages;
  LogTab.Caption := 'Log';

  OutputTab := TTabSheet.Create(Self);
  OutputTab.PageControl := Pages;
  OutputTab.Caption := 'Output';

  if FBrowser <> nil then
  begin
    FBrowser.Parent := BrowserTab;
    FBrowser.Align := alClient;
  end;

  if FLogMemo <> nil then
  begin
    FLogMemo.Parent := LogTab;
    FLogMemo.Align := alClient;
    FLogMemo.BorderStyle := bsNone;
    FLogMemo.ScrollBars := ssBoth;
    FLogMemo.WordWrap := False;
    FLogMemo.Font.Name := 'Consolas';
    FLogMemo.Font.Size := 9;
    FLogMemo.Color := RGB(248, 250, 252);
  end;

  OverviewBody := TPanel.Create(Self);
  OverviewBody.Parent := OverviewTab;
  OverviewBody.Align := alClient;
  OverviewBody.BevelOuter := bvNone;
  OverviewBody.Color := RGB(241, 245, 249);
  OverviewBody.ParentBackground := False;

  TitleLabel := TLabel.Create(Self);
  TitleLabel.Parent := OverviewBody;
  TitleLabel.SetBounds(22, 20, 650, 30);
  TitleLabel.Caption := 'Collection overview';
  TitleLabel.Font.Name := 'Segoe UI Semibold';
  TitleLabel.Font.Size := 16;
  TitleLabel.Font.Color := RGB(15, 23, 42);

  FMatchesValue := NewCard(OverviewBody, 22, 68, 150, 86, 'MATCHES');
  FCollectedValue := NewCard(OverviewBody, 184, 68, 150, 86, 'COLLECTED');
  FPendingValue := NewCard(OverviewBody, 346, 68, 150, 86, 'PENDING');
  FStateValue := NewCard(OverviewBody, 508, 68, 150, 86, 'STATE');
  FStateValue.Caption := 'READY';
  FStateValue.Font.Size := 13;

  CurrentCard := TPanel.Create(Self);
  CurrentCard.Parent := OverviewBody;
  CurrentCard.SetBounds(22, 176, 636, 230);
  CurrentCard.BevelOuter := bvNone;
  CurrentCard.Color := clWhite;
  CurrentCard.ParentBackground := False;

  InfoLabel := TLabel.Create(Self);
  InfoLabel.Parent := CurrentCard;
  InfoLabel.SetBounds(18, 18, 596, 185);
  InfoLabel.AutoSize := False;
  InfoLabel.WordWrap := True;
  InfoLabel.Caption :=
    'Collector status' + sLineBreak + sLineBreak +
    'Statistics  •  Half statistics  •  Extra time' + sLineBreak +
    'Lineups  •  Player stats  •  Commentary  •  JSON' + sLineBreak + sLineBreak +
    'Use Browser for Flashscore, Log for full diagnostics, and Output for file information.';
  InfoLabel.Font.Size := 10;
  InfoLabel.Font.Color := RGB(71, 85, 105);

  InfoLabel := TLabel.Create(Self);
  InfoLabel.Parent := OutputTab;
  InfoLabel.SetBounds(24, 24, 680, 120);
  InfoLabel.AutoSize := False;
  InfoLabel.WordWrap := True;
  InfoLabel.Caption :=
    'Collected JSON files are stored in the selected competition/season output folder.' +
    sLineBreak + sLineBreak +
    'Use Open output to open the folder or View latest JSON to inspect the newest file.';
  InfoLabel.Font.Size := 11;
  InfoLabel.Font.Color := RGB(51, 65, 85);

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 500;
  FTimer.OnTimer := TimerTick;
  FTimer.Enabled := True;

  Pages.ActivePage := OverviewTab;
end;

procedure TDashboardController.TimerTick(Sender: TObject);
var
  ProgressText: string;
  P: Integer;
  TotalText: string;
  CollectedText: string;
begin
  if FActivityLabel <> nil then
  begin
    if FStatusLabel <> nil then
      FActivityLabel.Caption := '  ' + FormatDateTime('hh:nn:ss', Now) +
        '  ' + FStatusLabel.Caption
    else
      FActivityLabel.Caption := '  ' + FormatDateTime('hh:nn:ss', Now) +
        '  Ready';
  end;

  TotalText := '0';
  CollectedText := '0';
  if FProgressLabel <> nil then
  begin
    ProgressText := FProgressLabel.Caption;
    P := Pos(':', ProgressText);
    if P > 0 then
      ProgressText := Trim(Copy(ProgressText, P + 1, MaxInt));
    P := Pos('/', ProgressText);
    if P > 0 then
    begin
      CollectedText := Trim(Copy(ProgressText, 1, P - 1));
      TotalText := Trim(Copy(ProgressText, P + 1, MaxInt));
    end;
  end;

  if FMatchesValue <> nil then
    FMatchesValue.Caption := TotalText;
  if FCollectedValue <> nil then
    FCollectedValue.Caption := CollectedText;

  if (FPendingValue <> nil) and (FProgressBar <> nil) then
    FPendingValue.Caption := IntToStr(
      System.Math.Max(0, FProgressBar.Max - FProgressBar.Position));

  if FStateValue <> nil then
  begin
    if (FProgressBar <> nil) and (FProgressBar.Position > 0) and
       (FProgressBar.Position < FProgressBar.Max) then
      FStateValue.Caption := 'RUNNING'
    else if (FStatusLabel <> nil) and
      (Pos('error', LowerCase(FStatusLabel.Caption)) > 0) then
      FStateValue.Caption := 'ERROR'
    else
      FStateValue.Caption := 'READY';
  end;
end;

procedure ApplyCollectorDashboard(const AForm: TForm);
begin
  if AForm = nil then
    Exit;
  TDashboardController.CreateDashboard(AForm);
end;

end.
