unit MainFormUnit;

interface

uses
  Winapi.Windows,
  Winapi.ActiveX,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  System.DateUtils,
  System.Math,
  System.Character,
  System.Generics.Collections,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Graphics,
  Vcl.Edge,
  WebView2,
  Collector.Types,
  Collector.State;

type
  TCollectionPhase = (
    cpStatistics,
    cpStatisticsFirstHalf,
    cpStatisticsSecondHalf,
    cpStatisticsExtraTime,
    cpLineups,
    cpPlayerStatsTopStats,
    cpPlayerStatsShots,
    cpPlayerStatsAttack,
    cpPlayerStatsPasses,
    cpPlayerStatsDefense,
    cpPlayerStatsGoalkeeping,
    cpPlayerStatsGeneral,
    cpCommentary,
    cpComplete
  );

  TMainForm = class(TForm)
  private
    FHeaderPanel: TPanel;
    FTitleLabel: TLabel;
    FSubtitleLabel: TLabel;
    FSetupPanel: TPanel;
    FBrowserPanel: TPanel;
    FBottomPanel: TPanel;
    FCompetitionLabel: TLabel;
    FCompetitionCombo: TComboBox;
    FSeasonLabel: TLabel;
    FSeasonCombo: TComboBox;
    FModeLabel: TLabel;
    FModeCombo: TComboBox;
    FUrlLabel: TLabel;
    FUrlEdit: TEdit;
    FDiscoverButton: TButton;
    FCollectButton: TButton;
    FStopButton: TButton;
    FNextMatchButton: TButton;
    FOpenOutputButton: TButton;
    FViewJsonButton: TButton;
    FStatusLabel: TLabel;
    FProgressLabel: TLabel;
    FProgressBar: TProgressBar;
    FLogMemo: TMemo;
    FEdgeBrowser: TEdgeBrowser;
    FPollTimer: TTimer;
    FTimeoutTimer: TTimer;

    FConfig: TCollectorConfig;
    FStore: TProcessedMatchStore;
    FQueue: TMatchQueue;
    FCurrentItem: TMatchQueueItem;
    FStage: TCollectorStage;
    FMode: TCollectorMode;
    FPendingScript: string;
    FOutputFile: string;
    FPhase: TCollectionPhase;
    FAggregate: TJSONObject;
    FDiscoveringMatches: Boolean;
    FDiscoveryPageIndex: Integer;
    FDiscoveredMatchCount: Integer;
    FDiscoveryLastRenderedMatchCount: Integer;
    FDiscoveryStablePollCount: Integer;
    FDiscoveryAwaitingExpansion: Boolean;
    FLastCompletedMatchId: string;
    FDiscoveryAnchorMatchId: string;
    FCoverageSections: TJSONObject;
    FArchiveBatchStartedAtUtc: string;
    FArchiveSavedCount: Integer;
    FArchivePartialCount: Integer;
    FArchiveFailedCount: Integer;
    FFullSeasonMode: Boolean;
    FDiscoveryOnly: Boolean;
    FStopRequested: Boolean;
    FCompetitionKey: string;
    FSeasonKey: string;
    FCompetitionDisplayName: string;
    FExpectedMatchCount: Integer;
    FSelectedArchive2022: Boolean;
    FSupportsPlayerStats: Boolean;
    FRegularSeasonRoundsOnly: Boolean;

    procedure BuildUi;
    procedure PopulateCompetitionUi;
    procedure ApplySelectedProfile;
    procedure MigrateLegacyWorldCupOutputs;
    procedure UpdateSeasonItems;
    procedure UpdateUiState;
    function IsBatchMode: Boolean;
    function IsArchive2022Mode: Boolean;
    procedure LoadConfiguration;
    procedure DetectMode;
    procedure StartCollectOne;
    procedure StartNextMatch;
    procedure StartMatchDiscovery;
    procedure NavigateDiscoveryPage;
    procedure ExecuteMatchDiscovery;
    procedure ProcessDiscoveredMatches(const AJson: string);
    procedure BeginCollection(const AItem: TMatchQueueItem);
    procedure PollDom;
    procedure ExecuteExtraction;
    procedure ProcessExtractedSection(const AJson: string);
    procedure NavigatePhase;
    procedure AdvancePhase;
    function PhaseUrl(const APhase: TCollectionPhase): string;
    procedure MergeSection(const ASection: TJSONObject);
    procedure EnrichPlayerStats;
    procedure SaveAggregateJson;
    procedure ResetCoverage;
    procedure SetPhaseCoverage(const APhase: TCollectionPhase;
      const ACoverage: Integer; const AStatus: string;
      const ARowCount: Integer; const AError: string = '');
    procedure MarkRemainingPlayerStatsUnavailable(const AReason: string);
    procedure SaveCoverageReport(const APartial: Boolean);
    procedure SaveArchiveBatchReport;
    procedure HandlePhaseFailure(const AMessage: string);
    procedure ContinueBatch;
    function FindLatestOutputJson: string;
    procedure FinishSuccess;
    procedure Fail(const AMessage: string);
    procedure SetStage(const AStage: TCollectorStage; const AText: string);
    procedure Log(const AMessage: string);
    function BuildOutputFileName(const ARoot: TJSONObject): string;

    procedure CompetitionComboChange(Sender: TObject);
    procedure SeasonComboChange(Sender: TObject);
    procedure DiscoverButtonClick(Sender: TObject);
    procedure CollectButtonClick(Sender: TObject);
    procedure StopButtonClick(Sender: TObject);
    procedure NextMatchButtonClick(Sender: TObject);
    procedure OpenOutputButtonClick(Sender: TObject);
    procedure ViewJsonButtonClick(Sender: TObject);
    procedure PollTimerTimer(Sender: TObject);
    procedure TimeoutTimerTimer(Sender: TObject);

    procedure EdgeCreateWebViewCompleted(Sender: TCustomEdgeBrowser;
      AResult: HRESULT);
    procedure EdgeNavigationCompleted(Sender: TCustomEdgeBrowser;
      IsSuccess: Boolean; WebErrorStatus: COREWEBVIEW2_WEB_ERROR_STATUS);
    procedure EdgeExecuteScript(Sender: TCustomEdgeBrowser; AResult: HRESULT;
      const AResultObjectAsJson: string);
  protected
    procedure DoShow; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation

uses
  Winapi.ShellAPI,
  Collector.Utils,
  Collector.Json,
  Collector.Scripts,
  Collector.Profiles,
  Collector.StructuredEvents,
  JsonViewerUnit;

const
  CBrowserZoomFactor = 0.60;

function IsPlayerStatsPhase(
  const APhase: TCollectionPhase): Boolean;
begin
  Result := APhase in [
    cpPlayerStatsTopStats,
    cpPlayerStatsShots,
    cpPlayerStatsAttack,
    cpPlayerStatsPasses,
    cpPlayerStatsDefense,
    cpPlayerStatsGoalkeeping,
    cpPlayerStatsGeneral
  ];
end;

function PlayerStatsCategoryKey(
  const APhase: TCollectionPhase): string;
begin
  case APhase of
    cpPlayerStatsTopStats:
      Result := 'top_stats';
    cpPlayerStatsShots:
      Result := 'shots';
    cpPlayerStatsAttack:
      Result := 'attack';
    cpPlayerStatsPasses:
      Result := 'passes';
    cpPlayerStatsDefense:
      Result := 'defense';
    cpPlayerStatsGoalkeeping:
      Result := 'goalkeeping';
    cpPlayerStatsGeneral:
      Result := 'general';
  else
    Result := '';
  end;
end;

function MatchHasExtraTime(const ARoot: TJSONObject): Boolean;
var
  StatusText: string;
  ScoreValue: TJSONValue;
  ScoreObject: TJSONObject;
  ScoreDisplay: string;
begin
  Result := False;
  if ARoot = nil then
    Exit;

  StatusText := UpperCase(JsonStringValue(ARoot, 'status', ''));
  if (Pos('EXTRA TIME', StatusText) > 0) or
     (Pos('AFTER EXTRA TIME', StatusText) > 0) or
     SameText(StatusText, 'AET') then
    Exit(True);

  ScoreValue := ARoot.GetValue('score');
  if ScoreValue is TJSONObject then
  begin
    ScoreObject := TJSONObject(ScoreValue);
    ScoreDisplay := UpperCase(JsonStringValue(ScoreObject, 'display', ''));
    Result := (Pos('PEN', ScoreDisplay) > 0) or
      (ScoreObject.GetValue('penalties') <> nil);
  end;
end;

constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'Flashscore Football Collector v45.9 - Discovery Stability Fix';
  Width := 1280;
  Height := 820;
  Position := poScreenCenter;

  FConfig := TCollectorConfig.Create;
  BuildUi;
  PopulateCompetitionUi;
  DetectMode;
end;

destructor TMainForm.Destroy;
begin
  FCoverageSections.Free;
  FAggregate.Free;
  FQueue.Free;
  FStore.Free;
  FConfig.Free;
  inherited;
end;

procedure TMainForm.BuildUi;
begin
  Color := RGB(242, 245, 249);
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  Constraints.MinWidth := 1100;
  Constraints.MinHeight := 700;

  FHeaderPanel := TPanel.Create(Self);
  FHeaderPanel.Parent := Self;
  FHeaderPanel.Align := alTop;
  FHeaderPanel.Height := 82;
  FHeaderPanel.BevelOuter := bvNone;
  FHeaderPanel.Color := RGB(28, 43, 67);
  FHeaderPanel.ParentBackground := False;

  FTitleLabel := TLabel.Create(Self);
  FTitleLabel.Parent := FHeaderPanel;
  FTitleLabel.Left := 24;
  FTitleLabel.Top := 15;
  FTitleLabel.Caption := 'Flashscore Football Collector';
  FTitleLabel.Font.Name := 'Segoe UI Semibold';
  FTitleLabel.Font.Size := 18;
  FTitleLabel.Font.Color := clWhite;

  FSubtitleLabel := TLabel.Create(Self);
  FSubtitleLabel.Parent := FHeaderPanel;
  FSubtitleLabel.Left := 26;
  FSubtitleLabel.Top := 51;
  FSubtitleLabel.Caption := 'Multi-competition discovery, collection and validation';
  FSubtitleLabel.Font.Color := RGB(190, 204, 224);

  FSetupPanel := TPanel.Create(Self);
  FSetupPanel.Parent := Self;
  FSetupPanel.Align := alLeft;
  FSetupPanel.Width := 310;
  FSetupPanel.BevelOuter := bvNone;
  FSetupPanel.Color := clWhite;
  FSetupPanel.ParentBackground := False;
  FSetupPanel.Padding.SetBounds(18, 18, 18, 18);

  FCompetitionLabel := TLabel.Create(Self);
  FCompetitionLabel.Parent := FSetupPanel;
  FCompetitionLabel.Left := 20;
  FCompetitionLabel.Top := 22;
  FCompetitionLabel.Caption := 'Competition';
  FCompetitionLabel.Font.Style := [fsBold];

  FCompetitionCombo := TComboBox.Create(Self);
  FCompetitionCombo.Parent := FSetupPanel;
  FCompetitionCombo.Left := 20;
  FCompetitionCombo.Top := 45;
  FCompetitionCombo.Width := 270;
  FCompetitionCombo.Style := csDropDownList;
  FCompetitionCombo.OnChange := CompetitionComboChange;

  FSeasonLabel := TLabel.Create(Self);
  FSeasonLabel.Parent := FSetupPanel;
  FSeasonLabel.Left := 20;
  FSeasonLabel.Top := 88;
  FSeasonLabel.Caption := 'Season / tournament';
  FSeasonLabel.Font.Style := [fsBold];

  FSeasonCombo := TComboBox.Create(Self);
  FSeasonCombo.Parent := FSetupPanel;
  FSeasonCombo.Left := 20;
  FSeasonCombo.Top := 111;
  FSeasonCombo.Width := 270;
  FSeasonCombo.Style := csDropDownList;
  FSeasonCombo.OnChange := SeasonComboChange;

  FModeLabel := TLabel.Create(Self);
  FModeLabel.Parent := FSetupPanel;
  FModeLabel.Left := 20;
  FModeLabel.Top := 154;
  FModeLabel.Caption := 'Collection mode';
  FModeLabel.Font.Style := [fsBold];

  FModeCombo := TComboBox.Create(Self);
  FModeCombo.Parent := FSetupPanel;
  FModeCombo.Left := 20;
  FModeCombo.Top := 177;
  FModeCombo.Width := 270;
  FModeCombo.Style := csDropDownList;
  FModeCombo.Items.Add('Full season / tournament');
  FModeCombo.Items.Add('Resume previous run');
  FModeCombo.Items.Add('Discovery only');
  FModeCombo.Items.Add('Collect single match');
  FModeCombo.ItemIndex := 0;

  FUrlLabel := TLabel.Create(Self);
  FUrlLabel.Parent := FSetupPanel;
  FUrlLabel.Left := 20;
  FUrlLabel.Top := 220;
  FUrlLabel.Caption := 'Single match URL';
  FUrlLabel.Font.Style := [fsBold];

  FUrlEdit := TEdit.Create(Self);
  FUrlEdit.Parent := FSetupPanel;
  FUrlEdit.Left := 20;
  FUrlEdit.Top := 243;
  FUrlEdit.Width := 270;
  FUrlEdit.TextHint := 'Paste Flashscore match URL';

  FDiscoverButton := TButton.Create(Self);
  FDiscoverButton.Parent := FSetupPanel;
  FDiscoverButton.Left := 20;
  FDiscoverButton.Top := 292;
  FDiscoverButton.Width := 130;
  FDiscoverButton.Height := 36;
  FDiscoverButton.Caption := 'Discover';
  FDiscoverButton.OnClick := DiscoverButtonClick;

  FCollectButton := TButton.Create(Self);
  FCollectButton.Parent := FSetupPanel;
  FCollectButton.Left := 160;
  FCollectButton.Top := 292;
  FCollectButton.Width := 130;
  FCollectButton.Height := 36;
  FCollectButton.Caption := 'Start';
  FCollectButton.Default := True;
  FCollectButton.OnClick := CollectButtonClick;

  FStopButton := TButton.Create(Self);
  FStopButton.Parent := FSetupPanel;
  FStopButton.Left := 20;
  FStopButton.Top := 338;
  FStopButton.Width := 130;
  FStopButton.Height := 34;
  FStopButton.Caption := 'Stop safely';
  FStopButton.Enabled := False;
  FStopButton.OnClick := StopButtonClick;

  FNextMatchButton := TButton.Create(Self);
  FNextMatchButton.Parent := FSetupPanel;
  FNextMatchButton.Left := 160;
  FNextMatchButton.Top := 338;
  FNextMatchButton.Width := 130;
  FNextMatchButton.Height := 34;
  FNextMatchButton.Caption := 'Next match';
  FNextMatchButton.Enabled := False;
  FNextMatchButton.OnClick := NextMatchButtonClick;

  FOpenOutputButton := TButton.Create(Self);
  FOpenOutputButton.Parent := FSetupPanel;
  FOpenOutputButton.Left := 20;
  FOpenOutputButton.Top := 382;
  FOpenOutputButton.Width := 130;
  FOpenOutputButton.Height := 34;
  FOpenOutputButton.Caption := 'Open output';
  FOpenOutputButton.OnClick := OpenOutputButtonClick;

  FViewJsonButton := TButton.Create(Self);
  FViewJsonButton.Parent := FSetupPanel;
  FViewJsonButton.Left := 160;
  FViewJsonButton.Top := 382;
  FViewJsonButton.Width := 130;
  FViewJsonButton.Height := 34;
  FViewJsonButton.Caption := 'View latest JSON';
  FViewJsonButton.Enabled := False;
  FViewJsonButton.OnClick := ViewJsonButtonClick;

  FProgressLabel := TLabel.Create(Self);
  FProgressLabel.Parent := FSetupPanel;
  FProgressLabel.Left := 20;
  FProgressLabel.Top := 448;
  FProgressLabel.Caption := 'Progress: idle';

  FProgressBar := TProgressBar.Create(Self);
  FProgressBar.Parent := FSetupPanel;
  FProgressBar.Left := 20;
  FProgressBar.Top := 474;
  FProgressBar.Width := 270;
  FProgressBar.Height := 18;
  FProgressBar.Min := 0;
  FProgressBar.Max := 100;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := FSetupPanel;
  FStatusLabel.Left := 20;
  FStatusLabel.Top := 518;
  FStatusLabel.Width := 270;
  FStatusLabel.AutoSize := False;
  FStatusLabel.WordWrap := True;
  FStatusLabel.Caption := 'Idle';
  FStatusLabel.Font.Color := RGB(67, 83, 107);

  FBottomPanel := TPanel.Create(Self);
  FBottomPanel.Parent := Self;
  FBottomPanel.Align := alBottom;
  FBottomPanel.Height := 190;
  FBottomPanel.BevelOuter := bvNone;
  FBottomPanel.Color := RGB(248, 250, 252);
  FBottomPanel.ParentBackground := False;
  FBottomPanel.Padding.SetBounds(12, 10, 12, 12);

  FLogMemo := TMemo.Create(Self);
  FLogMemo.Parent := FBottomPanel;
  FLogMemo.Align := alClient;
  FLogMemo.ReadOnly := True;
  FLogMemo.ScrollBars := ssVertical;
  FLogMemo.BorderStyle := bsSingle;
  FLogMemo.Font.Name := 'Consolas';
  FLogMemo.Font.Size := 9;
  FLogMemo.Color := clWhite;

  FBrowserPanel := TPanel.Create(Self);
  FBrowserPanel.Parent := Self;
  FBrowserPanel.Align := alClient;
  FBrowserPanel.BevelOuter := bvNone;
  FBrowserPanel.Padding.SetBounds(10, 10, 10, 10);
  FBrowserPanel.Color := RGB(242, 245, 249);
  FBrowserPanel.ParentBackground := False;

  FEdgeBrowser := TEdgeBrowser.Create(Self);
  FEdgeBrowser.Parent := FBrowserPanel;
  FEdgeBrowser.Align := alClient;
  FEdgeBrowser.UserDataFolder := AppPath('Data\WebView2');
  FEdgeBrowser.OnCreateWebViewCompleted := EdgeCreateWebViewCompleted;
  FEdgeBrowser.OnNavigationCompleted := EdgeNavigationCompleted;
  FEdgeBrowser.OnExecuteScript := EdgeExecuteScript;

  FPollTimer := TTimer.Create(Self);
  FPollTimer.Enabled := False;
  FPollTimer.Interval := 1500;
  FPollTimer.OnTimer := PollTimerTimer;

  FTimeoutTimer := TTimer.Create(Self);
  FTimeoutTimer.Enabled := False;
  FTimeoutTimer.Interval := 45000;
  FTimeoutTimer.OnTimer := TimeoutTimerTimer;
end;

procedure TMainForm.PopulateCompetitionUi;
begin
  FCompetitionCombo.Items.BeginUpdate;
  try
    PopulateCompetitionNames(FCompetitionCombo.Items);
    FCompetitionCombo.ItemIndex := 0;
  finally
    FCompetitionCombo.Items.EndUpdate;
  end;
  UpdateSeasonItems;
end;

procedure TMainForm.UpdateSeasonItems;
begin
  FSeasonCombo.Items.BeginUpdate;
  try
    PopulateSeasonNames(FCompetitionCombo.Text, FSeasonCombo.Items);
    FSeasonCombo.ItemIndex := 0;
  finally
    FSeasonCombo.Items.EndUpdate;
  end;
end;

procedure TMainForm.ApplySelectedProfile;
var
  Profile: TCompetitionProfile;
begin
  if not TryGetCompetitionProfile(FCompetitionCombo.Text,
    FSeasonCombo.Text, Profile) then
    raise EArgumentException.CreateFmt(
      'Unsupported competition/season profile: %s %s.',
      [FCompetitionCombo.Text, FSeasonCombo.Text]);

  FCompetitionKey := Profile.CompetitionKey;
  FCompetitionDisplayName := Profile.CompetitionName;
  FSeasonKey := Profile.SeasonKey;
  FExpectedMatchCount := Profile.ExpectedMatchCount;
  FSelectedArchive2022 := Profile.IsArchive2022;
  FSupportsPlayerStats := Profile.SupportsPlayerStats;
  FRegularSeasonRoundsOnly := Profile.RegularSeasonRoundsOnly;
  FConfig.OutputDirectory := Profile.OutputDirectory;
  FConfig.ProcessedFile := Profile.ProcessedFile;
  FConfig.QueueFile := Profile.QueueFile;
  FConfig.LogFile := Profile.LogFile;
  FConfig.CompetitionResultsUrl := Profile.ResultsUrl;
  FConfig.CompetitionFixturesUrl := Profile.FixturesUrl;
  MigrateLegacyWorldCupOutputs;
end;

procedure TMainForm.MigrateLegacyWorldCupOutputs;
var
  LegacyDirectory: string;
  TargetDirectory: string;
  SearchPattern: string;
  SourceFile: string;
  TargetFile: string;
  MovedCount: Integer;
begin
  if not SameText(FCompetitionKey, 'world_cup') then
    Exit;

  if SameText(FSeasonKey, '2022') then
  begin
    LegacyDirectory := AppPath('Data\Matches\Archive2022');
    SearchPattern := '*.json';
  end
  else if SameText(FSeasonKey, '2026') then
  begin
    LegacyDirectory := AppPath('Data\Matches');
    SearchPattern := '2026-*.json';
  end
  else
    Exit;

  TargetDirectory := AppPath(FConfig.OutputDirectory);
  if SameText(ExcludeTrailingPathDelimiter(LegacyDirectory),
    ExcludeTrailingPathDelimiter(TargetDirectory)) or
     not TDirectory.Exists(LegacyDirectory) then
    Exit;

  TDirectory.CreateDirectory(TargetDirectory);
  MovedCount := 0;
  for SourceFile in TDirectory.GetFiles(LegacyDirectory, SearchPattern,
    TSearchOption.soTopDirectoryOnly) do
  begin
    TargetFile := TPath.Combine(TargetDirectory,
      TPath.GetFileName(SourceFile));
    if TFile.Exists(TargetFile) then
      Continue;
    try
      TFile.Move(SourceFile, TargetFile);
      Inc(MovedCount);
    except
      on E: Exception do
        Log(Format('WARNING: Could not move legacy World Cup file %s: %s',
          [TPath.GetFileName(SourceFile), E.Message]));
    end;
  end;

  if MovedCount > 0 then
    Log(Format('Moved %d legacy World Cup %s match file(s) to %s.',
      [MovedCount, FSeasonKey, FConfig.OutputDirectory]));
end;

function TMainForm.IsBatchMode: Boolean;
begin
  Result := FFullSeasonMode or FDiscoveryOnly or IsArchive2022Mode or
    (FMode = cmPremierLeague2526);
end;

function TMainForm.IsArchive2022Mode: Boolean;
begin
  Result := FSelectedArchive2022 or (FMode = cmArchive2022);
end;

procedure TMainForm.UpdateUiState;
begin
  if FProgressBar <> nil then
  begin
    if (FQueue <> nil) and (FQueue.Items.Count > 0) then
    begin
      FProgressBar.Max := FQueue.Items.Count;
      FProgressBar.Position := Min(FStore.Count, FQueue.Items.Count);
      FProgressLabel.Caption := Format('Progress: %d / %d',
        [FProgressBar.Position, FProgressBar.Max]);
    end
    else
    begin
      FProgressBar.Max := 100;
      FProgressBar.Position := 0;
      FProgressLabel.Caption := 'Progress: idle';
    end;
  end;
end;

procedure TMainForm.CompetitionComboChange(Sender: TObject);
begin
  UpdateSeasonItems;
  ApplySelectedProfile;
end;

procedure TMainForm.SeasonComboChange(Sender: TObject);
begin
  ApplySelectedProfile;
end;

procedure TMainForm.DiscoverButtonClick(Sender: TObject);
begin
  ApplySelectedProfile;
  FDiscoveryOnly := True;
  FFullSeasonMode := False;
  FStopRequested := False;
  FreeAndNil(FStore);
  FreeAndNil(FQueue);
  FStore := TProcessedMatchStore.Create(FConfig.ProcessedFile, FConfig.OutputDirectory);
  FQueue := TMatchQueue.Create(FConfig.QueueFile);
  StartMatchDiscovery;
end;

procedure TMainForm.StopButtonClick(Sender: TObject);
begin
  FStopRequested := True;
  Log('Safe stop requested. The collector will stop after the current phase or match.');
  FStopButton.Enabled := False;
end;

procedure TMainForm.LoadConfiguration;
var
  ConfigFile: string;
  Root: TJSONObject;
begin
  ConfigFile := AppPath('config.json');
  if not TFile.Exists(ConfigFile) then
    Exit;

  Root := ParseJsonObject(TFile.ReadAllText(ConfigFile, TEncoding.UTF8));
  try
    FConfig.OutputDirectory := JsonStringValue(Root, 'output_directory',
      FConfig.OutputDirectory);
    FConfig.ProcessedFile := JsonStringValue(Root, 'processed_file',
      FConfig.ProcessedFile);
    FConfig.QueueFile := JsonStringValue(Root, 'queue_file',
      FConfig.QueueFile);
    FConfig.LogFile := JsonStringValue(Root, 'log_file', FConfig.LogFile);
    FConfig.PageTimeoutSeconds := JsonIntegerValue(Root,
      'page_timeout_seconds', FConfig.PageTimeoutSeconds);
    FConfig.VisibleBrowser := JsonBooleanValue(Root, 'visible_browser', True);
    FConfig.CompetitionResultsUrl := JsonStringValue(
      Root, 'competition_results_url', FConfig.CompetitionResultsUrl);
    FConfig.CompetitionFixturesUrl := JsonStringValue(
      Root, 'competition_fixtures_url', FConfig.CompetitionFixturesUrl);
    FConfig.ArchiveQueueFile := JsonStringValue(
      Root, 'archive_2022_queue_file', FConfig.ArchiveQueueFile);
    FConfig.ArchiveCoverageDirectory := JsonStringValue(
      Root, 'archive_coverage_directory', FConfig.ArchiveCoverageDirectory);
  finally
    Root.Free;
  end;

  FTimeoutTimer.Interval := FConfig.PageTimeoutSeconds * 1000;
  FEdgeBrowser.Visible := FConfig.VisibleBrowser;
end;

procedure TMainForm.DetectMode;
begin
  FMode := cmInteractive;
  if FindCmdLineSwitch('archive-2022', ['-', '/'], True) then
    FMode := cmArchive2022
  else if FindCmdLineSwitch('premier-league-2025-2026', ['-', '/'], True) then
  begin
    FMode := cmPremierLeague2526;
    FFullSeasonMode := True;
  end
  else if FindCmdLineSwitch('collect-one', ['-', '/'], True) then
    FMode := cmCollectOne;
end;

procedure TMainForm.DoShow;
begin
  inherited;
  try
    LoadConfiguration;
    if FMode = cmPremierLeague2526 then
    begin
      FCompetitionCombo.ItemIndex := 1;
      UpdateSeasonItems;
    end;
    if FMode = cmArchive2022 then
    begin
      FCompetitionCombo.ItemIndex := 0;
      UpdateSeasonItems;
      FSeasonCombo.ItemIndex := 1;
    end;
    ApplySelectedProfile;
    FStore := TProcessedMatchStore.Create(
      FConfig.ProcessedFile,
      FConfig.OutputDirectory
    );
    if IsArchive2022Mode then
    begin
      FConfig.OutputDirectory := 'Data\Matches\WC\WC_2022';
      FConfig.ProcessedFile := 'Data\processed_matches_archive_2022.json';
      FConfig.CompetitionResultsUrl :=
        'https://www.flashscore.com/football/world/world-championship-2022/results/';
      FConfig.ArchiveQueueFile := 'Data\archive_2022_matches.json';
      FConfig.QueueFile := FConfig.ArchiveQueueFile;
      FStore.Free;
      FStore := TProcessedMatchStore.Create(
        FConfig.ProcessedFile, FConfig.OutputDirectory);

      var ArchiveQueuePath := AppPath(FConfig.ArchiveQueueFile);
      if not TFile.Exists(ArchiveQueuePath) then
      begin
        EnsureDirectoryForFile(ArchiveQueuePath);
        TFile.WriteAllText(ArchiveQueuePath,
          '{' + sLineBreak +
          '  "schema_version": "1.1",' + sLineBreak +
          '  "matches": []' + sLineBreak +
          '}', TEncoding.UTF8);
      end;

      FQueue := TMatchQueue.Create(FConfig.QueueFile);
      FArchiveBatchStartedAtUtc := IsoNowUtc;
      Log('Archive 2022 full-auto mode enabled.');
      Log('Tournament results source: ' + FConfig.CompetitionResultsUrl);
      Log('Discovered queue: ' + FConfig.ArchiveQueueFile);
    end
    else
    begin
      FQueue := TMatchQueue.Create(FConfig.QueueFile);
      if FMode = cmPremierLeague2526 then
      begin
        Log('Premier League 2025/2026 full-season command-line mode enabled.');
        Log('Season results source: ' + FConfig.CompetitionResultsUrl);
      end;
    end;

    if FQueue.Items.Count > 0 then
      FUrlEdit.Text := FQueue.Items[0].Url;

    SetStage(csCreatingBrowser, 'Creating WebView2...');
    FEdgeBrowser.CreateWebView;
  except
    on E: Exception do
      Fail(E.Message);
  end;
end;

procedure TMainForm.EdgeCreateWebViewCompleted(Sender: TCustomEdgeBrowser;
  AResult: HRESULT);
begin
  if AResult < 0 then
  begin
    Fail(Format('WebView2 creation failed: 0x%.8x', [Cardinal(AResult)]));
    Exit;
  end;

  FEdgeBrowser.ZoomFactor := CBrowserZoomFactor;
  Log('WebView2 zoom set to 60%.');
  SetStage(csIdle, 'WebView2 ready.');

  if IsArchive2022Mode or (FMode = cmPremierLeague2526) then
    StartMatchDiscovery
  else if FMode = cmCollectOne then
    StartCollectOne;
end;

procedure TMainForm.StartCollectOne;
var
  ManualItem: TMatchQueueItem;
  MatchId: string;
begin
  if FStage in [csNavigating, csWaitingForDom, csReadingMatch, csSaving] then
    Exit;

  FCurrentItem := FQueue.FirstUnprocessed(FStore);

  if (FCurrentItem = nil) and (Trim(FUrlEdit.Text) <> '') then
  begin
    if not TryExtractMatchId(FUrlEdit.Text, MatchId) then
    begin
      Fail('Cannot extract match ID from URL.');
      Exit;
    end;

    if FStore.Contains(MatchId) then
    begin
      Fail('This match is already processed: ' + MatchId);
      Exit;
    end;

    ManualItem := TMatchQueueItem.Create;
    ManualItem.Url := Trim(FUrlEdit.Text);
    ManualItem.MatchId := MatchId;
    FQueue.Items.Add(ManualItem);
    FCurrentItem := ManualItem;
  end;

  if FCurrentItem = nil then
  begin
    SetStage(csFinished, 'No unprocessed matches remain.');
    if FMode = cmCollectOne then
      Close;
    Exit;
  end;

  BeginCollection(FCurrentItem);
end;

procedure TMainForm.BeginCollection(const AItem: TMatchQueueItem);
begin
  if AItem = nil then
    raise EArgumentNilException.Create('Match queue item is nil.');

  FCurrentItem := AItem;
  FUrlEdit.Text := FCurrentItem.Url;
  FreeAndNil(FAggregate);
  ResetCoverage;
  FPhase := cpStatistics;
  NavigatePhase;
end;

procedure TMainForm.StartNextMatch;
var
  NextItem: TMatchQueueItem;
begin
  if FStage in [csNavigating, csWaitingForDom, csReadingMatch, csSaving] then
    Exit;

  var AfterMatchId := FLastCompletedMatchId;
  if (AfterMatchId = '') and (FCurrentItem <> nil) then
    AfterMatchId := FCurrentItem.MatchId;

  if (AfterMatchId = '') and (Trim(FUrlEdit.Text) <> '') then
    TryExtractMatchId(Trim(FUrlEdit.Text), AfterMatchId);

  NextItem := FQueue.NextUnprocessedAfter(AfterMatchId, FStore);
  if NextItem <> nil then
  begin
    Log(Format('Next queued match selected after %s: %s',
      [AfterMatchId, NextItem.MatchId]));
    BeginCollection(NextItem);
    Exit;
  end;

  StartMatchDiscovery;
end;

procedure TMainForm.StartMatchDiscovery;
begin
  if FDiscoveringMatches then
    Exit;

  if IsArchive2022Mode or FFullSeasonMode or FDiscoveryOnly then
  begin
    FDiscoveryAnchorMatchId := '';
    if IsArchive2022Mode then
    begin
      Log('Discovering FIFA World Cup 2022 final-tournament matches from Round 1 through the final...');
      Log('Qualification matches before Round 1 are excluded.');
      Log('Expected final-tournament match count: 64.');
    end
    else
      Log('Discovering complete competition season from the selected results page...');
  end
  else
  begin
    FDiscoveryAnchorMatchId := FLastCompletedMatchId;

    if (FDiscoveryAnchorMatchId = '') and (FCurrentItem <> nil) then
      FDiscoveryAnchorMatchId := FCurrentItem.MatchId;

    if (FDiscoveryAnchorMatchId = '') and (Trim(FUrlEdit.Text) <> '') then
      TryExtractMatchId(Trim(FUrlEdit.Text), FDiscoveryAnchorMatchId);

    if FDiscoveryAnchorMatchId = '' then
    begin
      Fail('Cannot determine the current match ID for tournament discovery.');
      Exit;
    end;

    Log('Discovery anchor match: ' + FDiscoveryAnchorMatchId);
    Log('Rebuilding tournament queue from the anchor match onward...');
  end;

  FQueue.Clear;
  FDiscoveringMatches := True;
  FDiscoveryPageIndex := 0;
  FDiscoveredMatchCount := 0;
  FDiscoveryLastRenderedMatchCount := 0;
  FDiscoveryStablePollCount := 0;
  FDiscoveryAwaitingExpansion := False;
  NavigateDiscoveryPage;
end;

procedure TMainForm.NavigateDiscoveryPage;
var
  Url: string;
begin
  if IsArchive2022Mode or FFullSeasonMode or FDiscoveryOnly then
  begin
    if FDiscoveryPageIndex = 0 then
      Url := FConfig.CompetitionResultsUrl
    else
    begin
      FDiscoveringMatches := False;
      Log(Format('Season discovery finished. Discovered %d matches.',
        [FDiscoveredMatchCount]));

      if IsArchive2022Mode and (FDiscoveredMatchCount <> 64) then
        Log(Format('WARNING: Expected 64 World Cup 2022 matches, but discovered %d.',
          [FDiscoveredMatchCount]));

      if not SameText(FCompetitionKey, 'world_cup') and
         (FExpectedMatchCount > 0) and
         (FDiscoveredMatchCount <> FExpectedMatchCount) then
      begin
        SetStage(csFailed, Format(
          '%s %s discovery is incomplete: expected %d matches, discovered %d. Collection was not started.',
          [FCompetitionDisplayName, FSeasonCombo.Text,
           FExpectedMatchCount, FDiscoveredMatchCount]));
        Exit;
      end;

      UpdateUiState;
      if FDiscoveryOnly then
      begin
        SetStage(csFinished, Format('Discovery finished: %d matches.', [FDiscoveredMatchCount]));
        Exit;
      end;

      FCurrentItem := FQueue.FirstUnprocessed(FStore);
      if FCurrentItem = nil then
      begin
        SetStage(csFinished, 'All discovered matches are already processed.');
        if IsArchive2022Mode then
          SaveArchiveBatchReport;
        Exit;
      end;

      Log('Starting collection from the earliest unprocessed match: ' +
        FCurrentItem.MatchId);
      BeginCollection(FCurrentItem);
      Exit;
    end;
  end
  else
  begin
    case FDiscoveryPageIndex of
      0: Url := FConfig.CompetitionResultsUrl;
      1: Url := FConfig.CompetitionFixturesUrl;
    else
      begin
        FDiscoveringMatches := False;
        Log(Format('Discovery finished. Added %d new matches.',
          [FDiscoveredMatchCount]));

        var AfterMatchId := FDiscoveryAnchorMatchId;
        var NextItem := FQueue.NextUnprocessedAfter(AfterMatchId, FStore);
        if NextItem = nil then
        begin
          SetStage(csFinished,
            'No new unprocessed match was discovered after ' + AfterMatchId + '.');
          Exit;
        end;

        Log(Format('Discovered next match after %s: %s',
          [AfterMatchId, NextItem.MatchId]));
        BeginCollection(NextItem);
        Exit;
      end;
    end;
  end;

  FPollTimer.Enabled := False;
  FTimeoutTimer.Enabled := True;
  SetStage(csNavigating, 'Discovering tournament matches...');
  Log('Discovery navigate: ' + Url);
  FEdgeBrowser.Navigate(Url);
end;

procedure TMainForm.ExecuteMatchDiscovery;
begin
  FPollTimer.Enabled := False;
  FPendingScript := 'discover_matches';
  SetStage(csReadingMatch, 'Reading tournament match list...');
  FEdgeBrowser.ExecuteScript(BuildMatchDiscoveryScript(IsArchive2022Mode));
end;

procedure TMainForm.ProcessDiscoveredMatches(const AJson: string);
var
  Root: TJSONObject;
  MatchesValue: TJSONValue;
  Matches: TJSONArray;
  Value: TJSONValue;
  Obj: TJSONObject;
  MatchId: string;
  Index: Integer;
  Added: Integer;
  SkippedFinalStage: Integer;
  SkippedBeyondRegularSeason: Integer;
  LoadMoreClicked: Boolean;
  MatchCount: Integer;
  MatchCountValue: TJSONValue;

  function AddDiscoveredMatch(const AObject: TJSONObject): Boolean;
  var
    StageText: string;
    MatchUrl: string;
  begin
    Result := False;
    MatchId := JsonStringValue(AObject, 'match_id');
    MatchUrl := JsonStringValue(AObject, 'url');
    StageText := JsonStringValue(AObject, 'stage');

    if FRegularSeasonRoundsOnly and
       (Pos('final', LowerCase(StageText)) > 0) then
    begin
      Inc(SkippedFinalStage);
      Exit;
    end;

    // Flashscore occasionally appends relegation/play-off finals after the
    // regular league rounds without a stable stage label. Full-season league
    // profiles have a known exact size, so never let those extra matches enter
    // the rebuilt queue even when the DOM stage heading is unavailable.
    if FRegularSeasonRoundsOnly and IsBatchMode and
       (FDiscoveryPageIndex = 0) and (FExpectedMatchCount > 0) and
       (FQueue.Items.Count >= FExpectedMatchCount) then
    begin
      Inc(SkippedBeyondRegularSeason);
      Exit;
    end;

    Result := FQueue.AddIfMissing(MatchId, MatchUrl);
  end;
begin
  Root := ParseJsonObject(AJson);
  try
    if Root.GetValue('extraction_error') <> nil then
      raise EJSONException.Create(
        'Match discovery JavaScript failed: ' +
        JsonStringValue(Root, 'extraction_error'));

    Matches := nil;
    MatchesValue := Root.GetValue('matches');

    if MatchesValue is TJSONArray then
      Matches := TJSONArray(MatchesValue)
    else
      Log('Discovery response does not contain a matches array. Response: ' +
        Copy(Root.ToJSON, 1, 1000));

    LoadMoreClicked := JsonBooleanValue(Root, 'load_more_clicked', False);

    MatchCount := 0;
    MatchCountValue := Root.GetValue('match_count');
    if MatchCountValue is TJSONNumber then
      MatchCount := TJSONNumber(MatchCountValue).AsInt
    else if Matches <> nil then
      MatchCount := Matches.Count;

    // In full-season discovery Flashscore initially renders only the newest
    // result rounds. Do not persist that partial newest-first snapshot: older
    // rounds loaded by each "Show more" click would otherwise be appended
    // after it, so the queue would incorrectly begin around Round 28.
    // Wait for the final fully rendered snapshot, then reverse it once into
    // true chronological order (Round 1 through the last round).
    if IsBatchMode and (FDiscoveryPageIndex = 0) and LoadMoreClicked then
    begin
      FDiscoveryAwaitingExpansion := True;
      FDiscoveryLastRenderedMatchCount := MatchCount;
      FDiscoveryStablePollCount := 0;
      Log(Format(
        'Discovery snapshot is partial (%d matches rendered). Flashscore Show more clicked; waiting for earlier rounds...',
        [MatchCount]));
      FTimeoutTimer.Enabled := False;
      FTimeoutTimer.Enabled := True;
      FPollTimer.Enabled := True;
      Exit;
    end;

    // Immediately after Show more is clicked, Flashscore temporarily hides
    // the button before appending the next result rows. Do not mistake that
    // loading interval for the final season snapshot. Require several
    // unchanged polls before accepting the rendered list as complete.
    if IsBatchMode and (FDiscoveryPageIndex = 0) and
       FDiscoveryAwaitingExpansion then
    begin
      if MatchCount <> FDiscoveryLastRenderedMatchCount then
      begin
        Log(Format('Discovery expanded from %d to %d rendered matches; ' +
          'waiting for the next Show more state...',
          [FDiscoveryLastRenderedMatchCount, MatchCount]));
        FDiscoveryLastRenderedMatchCount := MatchCount;
        FDiscoveryStablePollCount := 0;
        FTimeoutTimer.Enabled := False;
        FTimeoutTimer.Enabled := True;
      end
      else
        Inc(FDiscoveryStablePollCount);

      if FDiscoveryStablePollCount < 6 then
      begin
        FTimeoutTimer.Enabled := True;
        FPollTimer.Enabled := True;
        Exit;
      end;

      FDiscoveryAwaitingExpansion := False;
      Log(Format(
        'Discovery list stabilized at %d rendered matches; processing the final snapshot.',
        [MatchCount]));
    end;

    Added := 0;
    SkippedFinalStage := 0;
    SkippedBeyondRegularSeason := 0;

    if Matches <> nil then
    begin
      // Flashscore results are rendered newest-first. Reverse them into
      // chronological order, from the opening match through the final.
      if IsBatchMode and (FDiscoveryPageIndex = 0) then
      begin
        for Index := Matches.Count - 1 downto 0 do
        begin
          Value := Matches.Items[Index];
          if not (Value is TJSONObject) then
            Continue;

          Obj := TJSONObject(Value);
          if AddDiscoveredMatch(Obj) then
            Inc(Added);
        end;
      end
      else if FDiscoveryPageIndex = 0 then
      begin
        var AnchorFound := False;

        for Index := Matches.Count - 1 downto 0 do
        begin
          Value := Matches.Items[Index];
          if not (Value is TJSONObject) then
            Continue;

          Obj := TJSONObject(Value);
          MatchId := JsonStringValue(Obj, 'match_id');
          if not AnchorFound then
          begin
            AnchorFound := SameText(MatchId, FDiscoveryAnchorMatchId);
            if not AnchorFound then
              Continue;
          end;

          if AddDiscoveredMatch(Obj) then
            Inc(Added);
        end;

        if not AnchorFound then
          Log('WARNING: Discovery anchor was not found on the results page: ' +
            FDiscoveryAnchorMatchId);
      end
      else
      begin
        for Value in Matches do
        begin
          if not (Value is TJSONObject) then
            Continue;

          Obj := TJSONObject(Value);
          if AddDiscoveredMatch(Obj) then
            Inc(Added);
        end;
      end;
    end;

    Inc(FDiscoveredMatchCount, Added);

    if SkippedFinalStage > 0 then
      Log(Format('Ignored %d Final-stage match(es); regular season rounds only.',
        [SkippedFinalStage]));
    if SkippedBeyondRegularSeason > 0 then
      Log(Format(
        'Ignored %d match(es) beyond the regular-season limit of %d.',
        [SkippedBeyondRegularSeason, FExpectedMatchCount]));

    Log(Format(
      'Discovery page returned %d matches; %d added. Event nodes: %d; anchors: %d; body text: %d.',
      [
        MatchCount,
        Added,
        JsonIntegerValue(Root, 'event_node_count', 0),
        JsonIntegerValue(Root, 'anchor_count', 0),
        JsonIntegerValue(Root, 'body_text_length', 0)
      ]));

    if LoadMoreClicked then
    begin
      Log('Flashscore Show more clicked; waiting for additional matches...');
      FTimeoutTimer.Enabled := True;
      FPollTimer.Enabled := True;
      Exit;
    end;
  finally
    Root.Free;
  end;

  Inc(FDiscoveryPageIndex);
  NavigateDiscoveryPage;
end;

function TMainForm.PhaseUrl(const APhase: TCollectionPhase): string;
var
  BaseUrl: string;
  SummaryPos: Integer;
  QueryPos: Integer;
  QueryText: string;
begin
  BaseUrl := FCurrentItem.Url;
  QueryPos := Pos('?', BaseUrl);
  if QueryPos > 0 then
    QueryText := Copy(BaseUrl, QueryPos, MaxInt)
  else
    QueryText := '';

  SummaryPos := Pos('/summary/', BaseUrl);
  if SummaryPos = 0 then
    raise EArgumentException.Create('Unexpected Flashscore match URL.');

  BaseUrl := Copy(BaseUrl, 1, SummaryPos - 1);

  case APhase of
    cpStatistics:
      Result := BaseUrl + '/summary/stats/overall/' + QueryText;
    cpStatisticsFirstHalf:
      Result := BaseUrl + '/summary/stats/1st-half/' + QueryText;
    cpStatisticsSecondHalf:
      Result := BaseUrl + '/summary/stats/2nd-half/' + QueryText;
    cpStatisticsExtraTime:
      Result := BaseUrl + '/summary/stats/extra-time/' + QueryText;
    cpLineups:
      Result := BaseUrl + '/summary/lineups/' + QueryText;
    cpPlayerStatsTopStats:
      Result := BaseUrl + '/summary/player-stats/top/' + QueryText;
    cpPlayerStatsShots:
      Result := BaseUrl + '/summary/player-stats/shots/' + QueryText;
    cpPlayerStatsAttack:
      Result := BaseUrl + '/summary/player-stats/attack/' + QueryText;
    cpPlayerStatsPasses:
      Result := BaseUrl + '/summary/player-stats/passes/' + QueryText;
    cpPlayerStatsDefense:
      Result := BaseUrl + '/summary/player-stats/defense/' + QueryText;
    cpPlayerStatsGoalkeeping:
      Result := BaseUrl + '/summary/player-stats/goalkeeping/' + QueryText;
    cpPlayerStatsGeneral:
      Result := BaseUrl + '/summary/player-stats/general/' + QueryText;
    cpCommentary:
      Result := BaseUrl + '/summary/live-commentary/' + QueryText;
  else
    Result := FCurrentItem.Url;
  end;
end;

function CoveragePhaseKey(const APhase: TCollectionPhase): string;
begin
  case APhase of
    cpStatistics: Result := 'statistics_match';
    cpStatisticsFirstHalf: Result := 'statistics_first_half';
    cpStatisticsSecondHalf: Result := 'statistics_second_half';
    cpStatisticsExtraTime: Result := 'statistics_extra_time';
    cpLineups: Result := 'lineups';
    cpPlayerStatsTopStats: Result := 'player_stats_top_stats';
    cpPlayerStatsShots: Result := 'player_stats_shots';
    cpPlayerStatsAttack: Result := 'player_stats_attack';
    cpPlayerStatsPasses: Result := 'player_stats_passes';
    cpPlayerStatsDefense: Result := 'player_stats_defense';
    cpPlayerStatsGoalkeeping: Result := 'player_stats_goalkeeping';
    cpPlayerStatsGeneral: Result := 'player_stats_general';
    cpCommentary: Result := 'commentary';
  else
    Result := 'unknown';
  end;
end;

procedure TMainForm.ResetCoverage;
var
  Phase: TCollectionPhase;
begin
  FreeAndNil(FCoverageSections);
  FCoverageSections := TJSONObject.Create;
  for Phase := cpStatistics to cpCommentary do
    SetPhaseCoverage(Phase, 0, 'pending', 0);
end;

procedure TMainForm.SetPhaseCoverage(const APhase: TCollectionPhase;
  const ACoverage: Integer; const AStatus: string;
  const ARowCount: Integer; const AError: string);
var
  Key: string;
  Item: TJSONObject;
  Pair: TJSONPair;
begin
  if FCoverageSections = nil then
    FCoverageSections := TJSONObject.Create;
  Key := CoveragePhaseKey(APhase);
  Pair := FCoverageSections.RemovePair(Key);
  Pair.Free;
  Item := TJSONObject.Create;
  Item.AddPair('coverage', TJSONNumber.Create(ACoverage));
  Item.AddPair('status', AStatus);
  Item.AddPair('row_count', TJSONNumber.Create(ARowCount));
  if AError = '' then
    Item.AddPair('error', TJSONNull.Create)
  else
    Item.AddPair('error', AError);
  FCoverageSections.AddPair(Key, Item);
end;

procedure TMainForm.MarkRemainingPlayerStatsUnavailable(
  const AReason: string);
var
  Phase: TCollectionPhase;
  CoverageValue: TJSONValue;
  CoverageStatus: string;
begin
  if FCoverageSections = nil then
    FCoverageSections := TJSONObject.Create;

  for Phase := cpPlayerStatsTopStats to cpPlayerStatsGeneral do
  begin
    CoverageValue := FCoverageSections.GetValue(CoveragePhaseKey(Phase));
    if CoverageValue is TJSONObject then
      CoverageStatus := JsonStringValue(TJSONObject(CoverageValue),
        'status', '')
    else
      CoverageStatus := '';

    if SameText(CoverageStatus, 'pending') or (CoverageStatus = '') then
      SetPhaseCoverage(Phase, 0, 'not_available', 0);
  end;

  Log('Player Stats are not available for this match: ' + AReason);
  Log('Marked the remaining Player Stats categories as not_available; ' +
    'collection continues with commentary.');
end;

procedure TMainForm.HandlePhaseFailure(const AMessage: string);
begin
  FPollTimer.Enabled := False;
  FTimeoutTimer.Enabled := False;
  FPendingScript := '';
  if IsPlayerStatsPhase(FPhase) then
  begin
    if FPhase = cpPlayerStatsTopStats then
    begin
      MarkRemainingPlayerStatsUnavailable(AMessage);
      FPhase := cpPlayerStatsGeneral;
    end
    else
    begin
      SetPhaseCoverage(FPhase, 0, 'not_available', 0);
      Log(Format(
        'Player Stats category unavailable [%s]: %s. Continuing.',
        [CoveragePhaseKey(FPhase), AMessage]));
    end;
    AdvancePhase;
    Exit;
  end;

  if not IsArchive2022Mode then
  begin
    Fail(AMessage);
    Exit;
  end;
  SetPhaseCoverage(FPhase, 0, 'failed', 0, AMessage);
  Log(Format('Archive section failed [%s]: %s. Continuing.',
    [CoveragePhaseKey(FPhase), AMessage]));
  AdvancePhase;
end;

procedure TMainForm.NavigatePhase;
const
  PhaseNames: array[TCollectionPhase] of string = (
    'overall statistics',
    '1st half statistics',
    '2nd half statistics',
    'extra-time statistics',
    'lineups',
    'player stats: Top Stats',
    'player stats: Shots',
    'player stats: Attack',
    'player stats: Passes',
    'player stats: Defense',
    'player stats: Goalkeeping',
    'player stats: General',
    'commentary',
    'complete'
  );
var
  Url: string;
begin
  if FPhase = cpComplete then
  begin
    try
      SaveAggregateJson;
    except
      on E: Exception do
      begin
        if not IsArchive2022Mode then
          raise;
        Inc(FArchiveFailedCount);
        Log('Archive match failed during save: ' + E.Message);
        SaveCoverageReport(True);
        var FailureMarker := TPath.Combine(
          AppPath(FConfig.ArchiveCoverageDirectory),
          SafeFileName(FCurrentItem.MatchId) + '.failed.json');
        EnsureDirectoryForFile(FailureMarker);
        TFile.WriteAllText(FailureMarker,
          Format('{"match_id":"%s","error":"%s"}', [
            FCurrentItem.MatchId,
            StringReplace(E.Message, '"', '\"', [rfReplaceAll])
          ]), TEncoding.UTF8);
        FStore.MarkProcessed(FCurrentItem.MatchId, FailureMarker);
        ContinueBatch;
      end;
    end;
    Exit;
  end;

  Url := PhaseUrl(FPhase);
  FPollTimer.Enabled := False;
  FTimeoutTimer.Enabled := True;
  SetStage(csNavigating, 'Opening ' + PhaseNames[FPhase] + '...');
  Log('Navigate: ' + Url);
  FEdgeBrowser.Navigate(Url);
end;

procedure TMainForm.AdvancePhase;
begin
  if FStopRequested then
  begin
    SetStage(csFinished, 'Stopped safely after current phase.');
    Exit;
  end;
  case FPhase of
    cpStatistics: FPhase := cpStatisticsFirstHalf;
    cpStatisticsFirstHalf: FPhase := cpStatisticsSecondHalf;
    cpStatisticsSecondHalf:
      begin
        if MatchHasExtraTime(FAggregate) then
          FPhase := cpStatisticsExtraTime
        else
        begin
          SetPhaseCoverage(cpStatisticsExtraTime, 0, 'not_applicable', 0);
          FPhase := cpLineups;
        end;
      end;
    cpStatisticsExtraTime: FPhase := cpLineups;
    cpLineups:
      begin
        if not FSupportsPlayerStats then
        begin
          SetPhaseCoverage(cpPlayerStatsTopStats, 0, 'not_available', 0);
          SetPhaseCoverage(cpPlayerStatsShots, 0, 'not_available', 0);
          SetPhaseCoverage(cpPlayerStatsAttack, 0, 'not_available', 0);
          SetPhaseCoverage(cpPlayerStatsPasses, 0, 'not_available', 0);
          SetPhaseCoverage(cpPlayerStatsDefense, 0, 'not_available', 0);
          SetPhaseCoverage(cpPlayerStatsGoalkeeping, 0, 'not_available', 0);
          SetPhaseCoverage(cpPlayerStatsGeneral, 0, 'not_available', 0);
          Log(Format(
            '%s %s: Player Stats are unavailable in the source profile.',
            [FCompetitionDisplayName, FSeasonCombo.Text]));
          Log('Marked all Player Stats categories as not_available; collection continues.');
          FPhase := cpCommentary;
        end
        else
          FPhase := cpPlayerStatsTopStats;
      end;
    cpPlayerStatsTopStats: FPhase := cpPlayerStatsShots;
    cpPlayerStatsShots: FPhase := cpPlayerStatsAttack;
    cpPlayerStatsAttack: FPhase := cpPlayerStatsPasses;
    cpPlayerStatsPasses: FPhase := cpPlayerStatsDefense;
    cpPlayerStatsDefense: FPhase := cpPlayerStatsGoalkeeping;
    cpPlayerStatsGoalkeeping: FPhase := cpPlayerStatsGeneral;
    cpPlayerStatsGeneral: FPhase := cpCommentary;
    cpCommentary: FPhase := cpComplete;
  else
    FPhase := cpComplete;
  end;

  NavigatePhase;
end;

procedure TMainForm.MergeSection(const ASection: TJSONObject);
var
  Pair: TJSONPair;
  ValueCopy: TJSONValue;
  ExistingPair: TJSONPair;
  SectionName: string;
  PeriodName: string;
  CategoryName: string;
  DiagnosticsKey: string;
  StatisticsByPeriod: TJSONObject;
  PlayerStatsByCategory: TJSONObject;
  StatisticsValue: TJSONValue;

  procedure SetPeriodStatistics(const APeriodName: string;
    const AStatisticsValue: TJSONValue);
  var
    ExistingValue: TJSONValue;
    PeriodPair: TJSONPair;
    PeriodValueCopy: TJSONValue;
  begin
    ExistingValue := FAggregate.GetValue('statistics_by_period');

    if ExistingValue = nil then
    begin
      StatisticsByPeriod := TJSONObject.Create;
      FAggregate.AddPair('statistics_by_period', StatisticsByPeriod);
    end
    else if ExistingValue is TJSONObject then
      StatisticsByPeriod := TJSONObject(ExistingValue)
    else
      raise EJSONException.Create(
        'JSON member statistics_by_period must be an object.');

    PeriodPair := StatisticsByPeriod.RemovePair(APeriodName);
    PeriodPair.Free;

    PeriodValueCopy :=
      TJSONObject.ParseJSONValue(AStatisticsValue.ToJSON);

    if PeriodValueCopy = nil then
      raise EJSONException.Create(
        'Unable to copy statistics for period ' + APeriodName + '.');

    StatisticsByPeriod.AddPair(APeriodName, PeriodValueCopy);
  end;


  procedure SetPlayerStatsCategory(const ACategoryName: string;
    const APlayerStatsValue: TJSONValue);
  var
    ExistingValue: TJSONValue;
    CategoryPair: TJSONPair;
    CategoryValueCopy: TJSONValue;
  begin
    ExistingValue := FAggregate.GetValue('player_stats_by_category');

    if ExistingValue = nil then
    begin
      PlayerStatsByCategory := TJSONObject.Create;
      FAggregate.AddPair(
        'player_stats_by_category',
        PlayerStatsByCategory
      );
    end
    else if ExistingValue is TJSONObject then
      PlayerStatsByCategory := TJSONObject(ExistingValue)
    else
      raise EJSONException.Create(
        'JSON member player_stats_by_category must be an object.');

    CategoryPair :=
      PlayerStatsByCategory.RemovePair(ACategoryName);
    CategoryPair.Free;

    CategoryValueCopy :=
      TJSONObject.ParseJSONValue(APlayerStatsValue.ToJSON);

    if CategoryValueCopy = nil then
      raise EJSONException.Create(
        'Unable to copy player stats category ' +
        ACategoryName + '.'
      );

    PlayerStatsByCategory.AddPair(
      ACategoryName,
      CategoryValueCopy
    );
  end;

begin
  SectionName := JsonStringValue(ASection, 'section');
  PeriodName := JsonStringValue(ASection, 'statistic_period');
  CategoryName :=
    JsonStringValue(ASection, 'player_stats_category');

  if FAggregate = nil then
  begin
    FAggregate := ParseJsonObject(ASection.ToJSON);
    FAggregate.RemovePair('statistic_period').Free;

    ExistingPair := FAggregate.RemovePair('extraction_diagnostics');
    if ExistingPair <> nil then
    begin
      ValueCopy :=
        TJSONObject.ParseJSONValue(ExistingPair.JsonValue.ToJSON);
      ExistingPair.Free;
      FAggregate.AddPair(
        'diagnostics_statistics_overall', ValueCopy);
    end;

    if SameText(PeriodName, 'overall') then
    begin
      StatisticsValue := FAggregate.GetValue('statistics');

      if StatisticsValue is TJSONArray then
      begin
        SetPeriodStatistics('overall', StatisticsValue);
        Log(Format(
          'Stored overall statistics: %d rows.',
          [TJSONArray(StatisticsValue).Count]
        ));
      end;
    end;

    Exit;
  end;

  for Pair in ASection do
  begin
    if SameText(Pair.JsonString.Value, 'section') or
       SameText(Pair.JsonString.Value, 'statistic_period') or
       SameText(Pair.JsonString.Value, 'player_stats_category') then
      Continue;

    if SameText(Pair.JsonString.Value, 'statistics') and
       (PeriodName <> '') then
    begin
      SetPeriodStatistics(PeriodName, Pair.JsonValue);
      Log(Format(
        'Stored %s statistics: %d rows.',
        [PeriodName, TJSONArray(Pair.JsonValue).Count]
      ));

      if SameText(PeriodName, 'overall') then
      begin
        ExistingPair := FAggregate.RemovePair('statistics');
        ExistingPair.Free;
        ValueCopy := TJSONObject.ParseJSONValue(Pair.JsonValue.ToJSON);
        FAggregate.AddPair('statistics', ValueCopy);
      end;

      Continue;
    end;


    if SameText(Pair.JsonString.Value, 'player_stats') and
       (CategoryName <> '') then
    begin
      SetPlayerStatsCategory(CategoryName, Pair.JsonValue);

      Log(Format(
        'Stored player stats category %s.',
        [CategoryName]
      ));

      Continue;
    end;

    if SameText(Pair.JsonString.Value, 'lineups') or
       SameText(Pair.JsonString.Value, 'commentary') or
       SameText(Pair.JsonString.Value, 'events') or
       SameText(Pair.JsonString.Value, 'lineup_validation') or
       SameText(Pair.JsonString.Value, 'commentary_validation') then
    begin
      ExistingPair := FAggregate.RemovePair(Pair.JsonString.Value);
      ExistingPair.Free;
      ValueCopy := TJSONObject.ParseJSONValue(Pair.JsonValue.ToJSON);
      FAggregate.AddPair(Pair.JsonString.Value, ValueCopy);
      Continue;
    end;

    if SameText(Pair.JsonString.Value, 'extraction_diagnostics') then
    begin
      if CategoryName <> '' then
        DiagnosticsKey :=
          'diagnostics_player_stats_' + CategoryName
      else
        DiagnosticsKey :=
          'diagnostics_' + StringReplace(
            SectionName,
            ' ',
            '_',
            [rfReplaceAll]
          );

      ValueCopy :=
        TJSONObject.ParseJSONValue(Pair.JsonValue.ToJSON);
      ExistingPair := FAggregate.RemovePair(DiagnosticsKey);
      ExistingPair.Free;
      FAggregate.AddPair(DiagnosticsKey, ValueCopy);
      Continue;
    end;

    if FAggregate.GetValue(Pair.JsonString.Value) = nil then
    begin
      ValueCopy := TJSONObject.ParseJSONValue(Pair.JsonValue.ToJSON);
      FAggregate.AddPair(Pair.JsonString.Value, ValueCopy);
    end;
  end;
end;

procedure TMainForm.ProcessExtractedSection(const AJson: string);
var
  Root: TJSONObject;
  SectionName: string;
  ExpectedSectionName: string;
begin
  Root := ParseJsonObject(AJson);
  try
    if Root.GetValue('extraction_error') <> nil then
      raise EJSONException.Create(
        'Page extraction JavaScript failed: ' +
        JsonStringValue(Root, 'extraction_error'));

    SectionName := JsonStringValue(Root, 'section', 'unknown');

    case FPhase of
      cpStatistics:
        if not SameText(SectionName, 'statistics_overall') then
          raise EJSONException.Create(
            'Expected overall statistics but received ' + SectionName);
      cpStatisticsFirstHalf:
        if not SameText(SectionName, 'statistics_first_half') then
          raise EJSONException.Create(
            'Expected 1st-half statistics but received ' + SectionName);
      cpStatisticsSecondHalf:
        if not SameText(SectionName, 'statistics_second_half') then
          raise EJSONException.Create(
            'Expected 2nd-half statistics but received ' + SectionName);
      cpStatisticsExtraTime:
        if not SameText(SectionName, 'statistics_extra_time') then
          raise EJSONException.Create(
            'Expected extra-time statistics but received ' + SectionName);
    end;

    if IsPlayerStatsPhase(FPhase) then
    begin
      ExpectedSectionName :=
        'player_stats_' + PlayerStatsCategoryKey(FPhase);

      if not SameText(SectionName, ExpectedSectionName) then
        raise EJSONException.Create(
          'Expected ' + ExpectedSectionName +
          ' but received ' + SectionName
        );
    end;

    var SectionRowCount := 0;
    var RowsValue: TJSONValue := nil;
    if FPhase in [cpStatistics, cpStatisticsFirstHalf, cpStatisticsSecondHalf,
      cpStatisticsExtraTime] then
      RowsValue := Root.GetValue('statistics')
    else if FPhase = cpLineups then
      RowsValue := Root.GetValue('lineups')
    else if IsPlayerStatsPhase(FPhase) then
      RowsValue := Root.GetValue('player_stats')
    else if FPhase = cpCommentary then
      RowsValue := Root.GetValue('commentary');
    if RowsValue is TJSONArray then
      SectionRowCount := TJSONArray(RowsValue).Count
    else if IsPlayerStatsPhase(FPhase) and
            (RowsValue is TJSONObject) then
    begin
      var PlayerRows := TJSONObject(RowsValue).GetValue('players');
      if PlayerRows is TJSONArray then
        SectionRowCount := TJSONArray(PlayerRows).Count;
      if SectionRowCount = 0 then
      begin
        PlayerRows := TJSONObject(RowsValue).GetValue('raw_rows');
        if PlayerRows is TJSONArray then
          SectionRowCount := TJSONArray(PlayerRows).Count;
      end;
    end
    else if RowsValue is TJSONObject then
      SectionRowCount := TJSONObject(RowsValue).Count;

    if IsPlayerStatsPhase(FPhase) and (SectionRowCount = 0) then
    begin
      HandlePhaseFailure('The Player Stats page contains no player rows.');
      Exit;
    end;

    MergeSection(Root);
    if SectionRowCount > 0 then
      SetPhaseCoverage(FPhase, 1, 'collected', SectionRowCount)
    else if IsArchive2022Mode then
      SetPhaseCoverage(FPhase, 0, 'not_available', 0)
    else
      SetPhaseCoverage(FPhase, 0, 'empty', 0);
    Log('Merged section: ' + SectionName);
  finally
    Root.Free;
  end;

  AdvancePhase;
end;


procedure TMainForm.EnrichPlayerStats;
const
  PlayerStatsCategories: array[0..6] of string = (
    'top_stats',
    'shots',
    'attack',
    'passes',
    'defense',
    'goalkeeping',
    'general'
  );
type
  TRedCardInfo = record
    Minute: Integer;
    RawMinute: string;
    TeamSide: string;
    TeamName: string;
    RosterName: string;
  end;
var
  PlayerStatsValue: TJSONValue;
  PlayerStatsByCategory: TJSONObject;
  LineupsValue: TJSONValue;
  LineupsObject: TJSONObject;
  EventsValue: TJSONValue;
  EventsObject: TJSONObject;
  GeneralValue: TJSONValue;
  GeneralObject: TJSONObject;
  GeneralPlayersValue: TJSONValue;
  GeneralPlayers: TJSONArray;
  CategoryIndex: Integer;
  CategoryName: string;
  CategoryValue: TJSONValue;
  CategoryObject: TJSONObject;
  PlayersValue: TJSONValue;
  Players: TJSONArray;
  PlayerIndex: Integer;
  PlayerValue: TJSONValue;
  PlayerObject: TJSONObject;
  PlayerName: string;
  PlayerKey: string;
  TeamSide: string;
  TeamName: string;
  ShirtNumber: Integer;
  IsStarter: Boolean;
  TeamLineup: TJSONObject;
  RosterMatchCount: Integer;
  MinuteIn: Integer;
  MinuteOut: Integer;
  MinuteInRaw: string;
  MinuteOutRaw: string;
  HasMinuteIn: Boolean;
  HasMinuteOut: Boolean;
  MinutesPlayed: Integer;
  HasMinutesPlayed: Boolean;
  ExitReason: string;
  TotalPlayerRows: Integer;
  EnrichedPlayerRows: Integer;
  UnmatchedPlayerRows: Integer;
  AmbiguousPlayerRows: Integer;
  GeneralMinutesPlayerCount: Integer;
  RedCardEventCount: Integer;
  RedCardMatchedEventCount: Integer;
  RedCardUnmatchedEventCount: Integer;
  RedCardExitRowCount: Integer;
  RedCardInfo: TRedCardInfo;
  DistinctPlayers: TDictionary<string, Boolean>;
  RedCardsByPlayer: TDictionary<string, TRedCardInfo>;
  RedCardPlayersApplied: TDictionary<string, Boolean>;
  UnmatchedRows: TJSONArray;
  UnmatchedRow: TJSONObject;
  RedCardAssignments: TJSONArray;
  RedCardAssignment: TJSONObject;
  UnmatchedRedCardEvents: TJSONArray;
  UnmatchedRedCardEvent: TJSONObject;
  ValidationObject: TJSONObject;
  ExistingPair: TJSONPair;

  function NormalizePlayerName(const AValue: string): string;
  var
    CharacterValue: Char;
    LowerValue: string;

    function FoldCharacter(const ACharacter: Char): Char;
    begin
      case ACharacter of
        'à', 'á', 'â', 'ã', 'ä', 'å', 'ā', 'ă', 'ą': Result := 'a';
        'ç', 'ć', 'č', 'ĉ', 'ċ': Result := 'c';
        'ď', 'đ': Result := 'd';
        'è', 'é', 'ê', 'ë', 'ē', 'ĕ', 'ė', 'ę', 'ě': Result := 'e';
        'ì', 'í', 'î', 'ï', 'ī', 'ĭ', 'į', 'ı': Result := 'i';
        'ñ', 'ń', 'ň', 'ņ': Result := 'n';
        'ò', 'ó', 'ô', 'õ', 'ö', 'ø', 'ō', 'ŏ', 'ő': Result := 'o';
        'ř', 'ŕ', 'ŗ': Result := 'r';
        'ś', 'š', 'ş', 'ŝ': Result := 's';
        'ť', 'ţ', 'ŧ': Result := 't';
        'ù', 'ú', 'û', 'ü', 'ū', 'ŭ', 'ů', 'ű', 'ų': Result := 'u';
        'ý', 'ÿ', 'ŷ': Result := 'y';
        'ž', 'ź', 'ż': Result := 'z';
        'ł': Result := 'l';
      else
        Result := ACharacter;
      end;
    end;

  begin
    Result := '';
    LowerValue := LowerCase(AValue);

    for CharacterValue in LowerValue do
      if CharacterValue.IsLetterOrDigit then
        Result := Result + FoldCharacter(CharacterValue);
  end;

  function NormalizeWords(const AValue: string): string;
  var
    CharacterValue: Char;
    LowerCharacter: Char;
    LastWasSpace: Boolean;
  begin
    Result := '';
    LastWasSpace := True;

    for CharacterValue in AValue do
    begin
      if CharacterValue.IsLetterOrDigit then
      begin
        LowerCharacter := CharacterValue.ToLower;
        Result := Result + LowerCharacter;
        LastWasSpace := False;
      end
      else if not LastWasSpace then
      begin
        Result := Result + ' ';
        LastWasSpace := True;
      end;
    end;

    Result := Trim(Result);
  end;

  function ContainsWord(const AWords: string;
    const AWord: string): Boolean;
  begin
    Result := Pos(
      ' ' + AWord + ' ',
      ' ' + AWords + ' '
    ) > 0;
  end;

  function JsonObjectMember(const AObject: TJSONObject;
    const AName: string): TJSONObject;
  var
    Value: TJSONValue;
  begin
    Result := nil;

    if AObject = nil then
      Exit;

    Value := AObject.GetValue(AName);

    if Value is TJSONObject then
      Result := TJSONObject(Value);
  end;

  function JsonArrayMember(const AObject: TJSONObject;
    const AName: string): TJSONArray;
  var
    Value: TJSONValue;
  begin
    Result := nil;

    if AObject = nil then
      Exit;

    Value := AObject.GetValue(AName);

    if Value is TJSONArray then
      Result := TJSONArray(Value);
  end;

  procedure RemoveMember(const AObject: TJSONObject;
    const AName: string);
  var
    Pair: TJSONPair;
  begin
    Pair := AObject.RemovePair(AName);
    Pair.Free;
  end;

  procedure SetStringMember(const AObject: TJSONObject;
    const AName: string; const AValue: string);
  begin
    RemoveMember(AObject, AName);
    AObject.AddPair(AName, AValue);
  end;

  procedure SetIntegerMember(const AObject: TJSONObject;
    const AName: string; const AValue: Integer);
  begin
    RemoveMember(AObject, AName);
    AObject.AddPair(AName, TJSONNumber.Create(AValue));
  end;

  procedure SetBooleanMember(const AObject: TJSONObject;
    const AName: string; const AValue: Boolean);
  begin
    RemoveMember(AObject, AName);
    AObject.AddPair(AName, TJSONBool.Create(AValue));
  end;

  procedure SetNullMember(const AObject: TJSONObject;
    const AName: string);
  begin
    RemoveMember(AObject, AName);
    AObject.AddPair(AName, TJSONNull.Create);
  end;

  function ParseMatchMinute(const AMinuteText: string;
    out AMinute: Integer): Boolean;
  var
    CleanText: string;
    PlusPosition: Integer;
    BaseText: string;
    AddedText: string;
    BaseMinute: Integer;
    AddedMinute: Integer;
  begin
    AMinute := 0;
    CleanText := Trim(AMinuteText);
    CleanText := StringReplace(
      CleanText,
      '''',
      '',
      [rfReplaceAll]
    );

    PlusPosition := Pos('+', CleanText);

    if PlusPosition = 0 then
      Exit(TryStrToInt(CleanText, AMinute));

    BaseText := Copy(CleanText, 1, PlusPosition - 1);
    AddedText := Copy(
      CleanText,
      PlusPosition + 1,
      MaxInt
    );

    Result :=
      TryStrToInt(BaseText, BaseMinute) and
      TryStrToInt(AddedText, AddedMinute);

    if Result then
      AMinute := BaseMinute + AddedMinute;
  end;

  function FindRosterPlayer(const APlayerName: string;
    out ATeamSide: string; out ATeamName: string;
    out AShirtNumber: Integer; out AIsStarter: Boolean;
    out ATeamLineup: TJSONObject;
    out AMatchCount: Integer): Boolean;
  var
    TargetName: string;
    SeenRosterKeys: TDictionary<string, Boolean>;

    procedure SearchRosterArray(const ASideName: string;
      const ATeamValue: string; const ALineup: TJSONObject;
      const AArrayName: string; const AStarter: Boolean);
    var
      RosterArray: TJSONArray;
      RosterIndex: Integer;
      RosterValue: TJSONValue;
      RosterPlayer: TJSONObject;
      RosterName: string;
      RosterKey: string;
    begin
      RosterArray := JsonArrayMember(ALineup, AArrayName);

      if RosterArray = nil then
        Exit;

      for RosterIndex := 0 to RosterArray.Count - 1 do
      begin
        RosterValue := RosterArray.Items[RosterIndex];

        if not (RosterValue is TJSONObject) then
          Continue;

        RosterPlayer := TJSONObject(RosterValue);
        RosterName := JsonStringValue(
          RosterPlayer,
          'name'
        );

        if NormalizePlayerName(RosterName) <> TargetName then
          Continue;

        RosterKey := ASideName + '|' + NormalizePlayerName(RosterName) + '|' +
          IntToStr(JsonIntegerValue(RosterPlayer, 'number', 0));
        if SeenRosterKeys.ContainsKey(RosterKey) then
          Continue;
        SeenRosterKeys.Add(RosterKey, True);

        Inc(AMatchCount);

        if AMatchCount = 1 then
        begin
          ATeamSide := ASideName;
          ATeamName := ATeamValue;
          AShirtNumber := JsonIntegerValue(
            RosterPlayer,
            'number',
            0
          );
          AIsStarter := AStarter;
          ATeamLineup := ALineup;
        end;
      end;
    end;

  var
    HomeLineup: TJSONObject;
    AwayLineup: TJSONObject;
    HomeTeamName: string;
    AwayTeamName: string;
  begin
    ATeamSide := '';
    ATeamName := '';
    AShirtNumber := 0;
    AIsStarter := False;
    ATeamLineup := nil;
    AMatchCount := 0;

    TargetName := NormalizePlayerName(APlayerName);

    if TargetName = '' then
      Exit(False);

    SeenRosterKeys := TDictionary<string, Boolean>.Create;
    try
    HomeLineup := JsonObjectMember(LineupsObject, 'home');
    AwayLineup := JsonObjectMember(LineupsObject, 'away');
    HomeTeamName := JsonStringValue(
      FAggregate,
      'home_team'
    );
    AwayTeamName := JsonStringValue(
      FAggregate,
      'away_team'
    );

    SearchRosterArray(
      'home',
      HomeTeamName,
      HomeLineup,
      'starting',
      True
    );
    SearchRosterArray(
      'home',
      HomeTeamName,
      HomeLineup,
      'substitutes',
      False
    );
    SearchRosterArray(
      'away',
      AwayTeamName,
      AwayLineup,
      'starting',
      True
    );
    SearchRosterArray(
      'away',
      AwayTeamName,
      AwayLineup,
      'substitutes',
      False
    );

    Result := AMatchCount = 1;
    finally
      SeenRosterKeys.Free;
    end;
  end;

  function FindSubstitutionMinute(const ATeamLineup: TJSONObject;
    const APlayerName: string; const ANameField: string;
    out ARawMinute: string; out AMinute: Integer): Boolean;
  var
    Substitutions: TJSONArray;
    SubstitutionIndex: Integer;
    SubstitutionValue: TJSONValue;
    SubstitutionObject: TJSONObject;
    CandidateName: string;
  begin
    Result := False;
    ARawMinute := '';
    AMinute := 0;

    Substitutions := JsonArrayMember(
      ATeamLineup,
      'substitutions'
    );

    if Substitutions = nil then
      Exit;

    for SubstitutionIndex := 0 to
      Substitutions.Count - 1 do
    begin
      SubstitutionValue :=
        Substitutions.Items[SubstitutionIndex];

      if not (SubstitutionValue is TJSONObject) then
        Continue;

      SubstitutionObject :=
        TJSONObject(SubstitutionValue);
      CandidateName := JsonStringValue(
        SubstitutionObject,
        ANameField
      );

      if NormalizePlayerName(CandidateName) <>
         NormalizePlayerName(APlayerName) then
        Continue;

      ARawMinute := JsonStringValue(
        SubstitutionObject,
        'minute'
      );

      Result := ParseMatchMinute(
        ARawMinute,
        AMinute
      );
      Exit;
    end;
  end;

  function FindGeneralMinutes(const APlayerName: string;
    out AMinutesPlayed: Integer): Boolean;
  var
    GeneralIndex: Integer;
    GeneralPlayerValue: TJSONValue;
    GeneralPlayer: TJSONObject;
    CandidateName: string;
    MinutesValue: TJSONValue;
  begin
    Result := False;
    AMinutesPlayed := 0;

    if GeneralPlayers = nil then
      Exit;

    for GeneralIndex := 0 to GeneralPlayers.Count - 1 do
    begin
      GeneralPlayerValue := GeneralPlayers.Items[GeneralIndex];

      if not (GeneralPlayerValue is TJSONObject) then
        Continue;

      GeneralPlayer := TJSONObject(GeneralPlayerValue);
      CandidateName := JsonStringValue(
        GeneralPlayer,
        'player'
      );

      if NormalizePlayerName(CandidateName) <>
         NormalizePlayerName(APlayerName) then
        Continue;

      MinutesValue :=
        GeneralPlayer.GetValue('minutes_played');

      if (MinutesValue <> nil) and
         not (MinutesValue is TJSONNull) then
        Result := TryStrToInt(
          MinutesValue.Value,
          AMinutesPlayed
        );

      Exit;
    end;
  end;

  function ExtractEventTeam(const AEventText: string): string;
  var
    OpenPosition: Integer;
    ClosePosition: Integer;
    TailText: string;
  begin
    Result := '';
    OpenPosition := LastDelimiter('(', AEventText);

    if OpenPosition = 0 then
      Exit;

    TailText := Copy(
      AEventText,
      OpenPosition + 1,
      MaxInt
    );
    ClosePosition := Pos(')', TailText);

    if ClosePosition = 0 then
      Exit;

    Result := Copy(TailText, 1, ClosePosition - 1);
  end;

  function RosterEventMatchScore(const ARosterName: string;
    const AEventText: string): Integer;
  var
    RosterWords: TStringList;
    EventWords: TStringList;
    NormalizedRoster: string;
    NormalizedEvent: string;
    InitialIndex: Integer;
    TokenIndex: Integer;
    EventIndex: Integer;
    SurnameToken: string;
    InitialToken: string;
    LastSurnameToken: string;
    InitialMatched: Boolean;
  begin
    Result := 0;
    NormalizedRoster := NormalizeWords(ARosterName);
    NormalizedEvent := NormalizeWords(AEventText);

    if (NormalizedRoster = '') or (NormalizedEvent = '') then
      Exit;

    RosterWords := TStringList.Create;
    EventWords := TStringList.Create;
    try
      RosterWords.StrictDelimiter := True;
      RosterWords.Delimiter := ' ';
      RosterWords.DelimitedText := NormalizedRoster;

      EventWords.StrictDelimiter := True;
      EventWords.Delimiter := ' ';
      EventWords.DelimitedText := NormalizedEvent;

      if RosterWords.Count = 0 then
        Exit;

      InitialIndex := RosterWords.Count;

      for TokenIndex := 0 to RosterWords.Count - 1 do
        if Length(RosterWords[TokenIndex]) = 1 then
        begin
          InitialIndex := TokenIndex;
          Break;
        end;

      if InitialIndex > 0 then
        LastSurnameToken := RosterWords[InitialIndex - 1]
      else
        LastSurnameToken := RosterWords[RosterWords.Count - 1];

      if not ContainsWord(NormalizedEvent, LastSurnameToken) then
        Exit;

      Result := 50;

      for TokenIndex := 0 to InitialIndex - 2 do
      begin
        SurnameToken := RosterWords[TokenIndex];

        if ContainsWord(NormalizedEvent, SurnameToken) then
          Inc(Result, 10);
      end;

      if InitialIndex < RosterWords.Count then
      begin
        InitialToken := RosterWords[InitialIndex];
        InitialMatched := False;

        for EventIndex := 0 to EventWords.Count - 1 do
          if (EventWords[EventIndex] <> '') and
             SameText(
               Copy(EventWords[EventIndex], 1, 1),
               InitialToken
             ) then
          begin
            InitialMatched := True;
            Break;
          end;

        if InitialMatched then
          Inc(Result, 20);
      end;
    finally
      EventWords.Free;
      RosterWords.Free;
    end;
  end;

  function ResolveRedCardEvent(const AEventText: string;
    out ATeamSide: string; out ATeamName: string;
    out ARosterName: string): Boolean;
  var
    HomeLineup: TJSONObject;
    AwayLineup: TJSONObject;
    HomeTeamName: string;
    AwayTeamName: string;
    EventTeam: string;
    EventTeamKey: string;
    HomeTeamKey: string;
    AwayTeamKey: string;
    BestScore: Integer;
    BestPlayerKey: string;
    IsTie: Boolean;
    SeenPlayers: TDictionary<string, Boolean>;

    procedure ConsiderRosterArray(const ASideName: string;
      const ATeamValue: string; const ALineup: TJSONObject;
      const AArrayName: string);
    var
      RosterArray: TJSONArray;
      RosterIndex: Integer;
      RosterValue: TJSONValue;
      RosterPlayer: TJSONObject;
      RosterName: string;
      RosterKey: string;
      Score: Integer;
    begin
      RosterArray := JsonArrayMember(ALineup, AArrayName);

      if RosterArray = nil then
        Exit;

      for RosterIndex := 0 to RosterArray.Count - 1 do
      begin
        RosterValue := RosterArray.Items[RosterIndex];

        if not (RosterValue is TJSONObject) then
          Continue;

        RosterPlayer := TJSONObject(RosterValue);
        RosterName := JsonStringValue(
          RosterPlayer,
          'name'
        );
        RosterKey := NormalizePlayerName(RosterName);

        if (RosterKey = '') or
           SeenPlayers.ContainsKey(RosterKey) then
          Continue;

        SeenPlayers.Add(RosterKey, True);
        Score := RosterEventMatchScore(
          RosterName,
          AEventText
        );

        if Score > BestScore then
        begin
          BestScore := Score;
          BestPlayerKey := RosterKey;
          ATeamSide := ASideName;
          ATeamName := ATeamValue;
          ARosterName := RosterName;
          IsTie := False;
        end
        else if (Score > 0) and
                (Score = BestScore) and
                (RosterKey <> BestPlayerKey) then
          IsTie := True;
      end;
    end;

    procedure ConsiderSide(const ASideName: string;
      const ATeamValue: string;
      const ALineup: TJSONObject);
    begin
      ConsiderRosterArray(
        ASideName,
        ATeamValue,
        ALineup,
        'starting'
      );
      ConsiderRosterArray(
        ASideName,
        ATeamValue,
        ALineup,
        'substitutes'
      );
    end;

  begin
    ATeamSide := '';
    ATeamName := '';
    ARosterName := '';
    BestScore := 0;
    BestPlayerKey := '';
    IsTie := False;

    HomeLineup := JsonObjectMember(LineupsObject, 'home');
    AwayLineup := JsonObjectMember(LineupsObject, 'away');
    HomeTeamName := JsonStringValue(
      FAggregate,
      'home_team'
    );
    AwayTeamName := JsonStringValue(
      FAggregate,
      'away_team'
    );

    EventTeam := ExtractEventTeam(AEventText);
    EventTeamKey := NormalizePlayerName(EventTeam);
    HomeTeamKey := NormalizePlayerName(HomeTeamName);
    AwayTeamKey := NormalizePlayerName(AwayTeamName);

    SeenPlayers := TDictionary<string, Boolean>.Create;
    try
      if (EventTeamKey <> '') and
         (EventTeamKey = HomeTeamKey) then
        ConsiderSide(
          'home',
          HomeTeamName,
          HomeLineup
        )
      else if (EventTeamKey <> '') and
              (EventTeamKey = AwayTeamKey) then
        ConsiderSide(
          'away',
          AwayTeamName,
          AwayLineup
        )
      else
      begin
        ConsiderSide(
          'home',
          HomeTeamName,
          HomeLineup
        );
        ConsiderSide(
          'away',
          AwayTeamName,
          AwayLineup
        );
      end;
    finally
      SeenPlayers.Free;
    end;

    Result := (BestScore >= 50) and not IsTie;
  end;

  procedure BuildRedCardIndex;
  var
    RedCards: TJSONArray;
    RedCardIndex: Integer;
    EventValue: TJSONValue;
    EventObject: TJSONObject;
    EventText: string;
    EventStatus: string;
    EventMinute: Integer;
    AddedTime: Integer;
    NormalizedMinute: Integer;
    RawMinute: string;
    ResolvedSide: string;
    ResolvedTeam: string;
    ResolvedPlayer: string;
    ResolvedPlayerKey: string;
    Info: TRedCardInfo;
  begin
    RedCardEventCount := 0;
    RedCardMatchedEventCount := 0;
    RedCardUnmatchedEventCount := 0;

    if EventsObject = nil then
      Exit;

    RedCards := JsonArrayMember(
      EventsObject,
      'red_cards'
    );

    if RedCards = nil then
      Exit;

    for RedCardIndex := 0 to RedCards.Count - 1 do
    begin
      EventValue := RedCards.Items[RedCardIndex];

      if not (EventValue is TJSONObject) then
        Continue;

      EventObject := TJSONObject(EventValue);
      EventStatus := JsonStringValue(
        EventObject,
        'status'
      );

      if (EventStatus <> '') and
         not SameText(EventStatus, 'confirmed') then
        Continue;

      Inc(RedCardEventCount);
      EventText := JsonStringValue(
        EventObject,
        'text'
      );
      EventMinute := JsonIntegerValue(
        EventObject,
        'minute',
        0
      );
      AddedTime := JsonIntegerValue(
        EventObject,
        'added_time',
        0
      );
      NormalizedMinute := EventMinute + AddedTime;

      if AddedTime > 0 then
        RawMinute := Format(
          '%d+%d',
          [EventMinute, AddedTime]
        )
      else
        RawMinute := IntToStr(EventMinute);

      if ResolveRedCardEvent(
        EventText,
        ResolvedSide,
        ResolvedTeam,
        ResolvedPlayer
      ) then
      begin
        ResolvedPlayerKey :=
          NormalizePlayerName(ResolvedPlayer);

        Info.Minute := NormalizedMinute;
        Info.RawMinute := RawMinute;
        Info.TeamSide := ResolvedSide;
        Info.TeamName := ResolvedTeam;
        Info.RosterName := ResolvedPlayer;

        RedCardsByPlayer.AddOrSetValue(
          ResolvedPlayerKey,
          Info
        );
        Inc(RedCardMatchedEventCount);

        RedCardAssignment := TJSONObject.Create;
        RedCardAssignment.AddPair(
          'player',
          ResolvedPlayer
        );
        RedCardAssignment.AddPair(
          'team_side',
          ResolvedSide
        );
        RedCardAssignment.AddPair(
          'team',
          ResolvedTeam
        );
        RedCardAssignment.AddPair(
          'minute',
          TJSONNumber.Create(NormalizedMinute)
        );
        RedCardAssignment.AddPair(
          'minute_raw',
          RawMinute
        );
        RedCardAssignment.AddPair(
          'event_text',
          EventText
        );
        RedCardAssignments.AddElement(
          RedCardAssignment
        );
      end
      else
      begin
        Inc(RedCardUnmatchedEventCount);

        UnmatchedRedCardEvent :=
          TJSONObject.Create;
        UnmatchedRedCardEvent.AddPair(
          'minute',
          TJSONNumber.Create(NormalizedMinute)
        );
        UnmatchedRedCardEvent.AddPair(
          'minute_raw',
          RawMinute
        );
        UnmatchedRedCardEvent.AddPair(
          'event_text',
          EventText
        );
        UnmatchedRedCardEvents.AddElement(
          UnmatchedRedCardEvent
        );
      end;
    end;
  end;

begin
  PlayerStatsValue :=
    FAggregate.GetValue('player_stats_by_category');

  if not (PlayerStatsValue is TJSONObject) then
    raise EJSONException.Create(
      'Player stats categories are missing.'
    );

  PlayerStatsByCategory :=
    TJSONObject(PlayerStatsValue);

  LineupsValue := FAggregate.GetValue('lineups');

  if not (LineupsValue is TJSONObject) then
    raise EJSONException.Create(
      'Lineups are required for Player Stats enrichment.'
    );

  LineupsObject := TJSONObject(LineupsValue);

  EventsValue := FAggregate.GetValue('events');

  if EventsValue is TJSONObject then
    EventsObject := TJSONObject(EventsValue)
  else
    EventsObject := nil;

  GeneralValue :=
    PlayerStatsByCategory.GetValue('general');

  if not (GeneralValue is TJSONObject) then
    raise EJSONException.Create(
      'General Player Stats are required for minutes played.'
    );

  GeneralObject := TJSONObject(GeneralValue);
  GeneralPlayersValue :=
    GeneralObject.GetValue('players');

  if GeneralPlayersValue is TJSONArray then
    GeneralPlayers := TJSONArray(GeneralPlayersValue)
  else
    GeneralPlayers := nil;

  if GeneralPlayers = nil then
    raise EJSONException.Create(
      'General Player Stats players array is missing.'
    );

  GeneralMinutesPlayerCount := 0;

  for PlayerIndex := 0 to GeneralPlayers.Count - 1 do
  begin
    PlayerValue := GeneralPlayers.Items[PlayerIndex];

    if (PlayerValue is TJSONObject) and
       (TJSONObject(PlayerValue).GetValue(
         'minutes_played'
       ) <> nil) then
      Inc(GeneralMinutesPlayerCount);
  end;

  TotalPlayerRows := 0;
  EnrichedPlayerRows := 0;
  UnmatchedPlayerRows := 0;
  AmbiguousPlayerRows := 0;
  RedCardExitRowCount := 0;
  DistinctPlayers := TDictionary<string, Boolean>.Create;
  RedCardsByPlayer :=
    TDictionary<string, TRedCardInfo>.Create;
  RedCardPlayersApplied :=
    TDictionary<string, Boolean>.Create;
  UnmatchedRows := TJSONArray.Create;
  RedCardAssignments := TJSONArray.Create;
  UnmatchedRedCardEvents := TJSONArray.Create;
  ValidationObject := nil;

  try
    BuildRedCardIndex;

    for CategoryIndex := Low(PlayerStatsCategories) to
      High(PlayerStatsCategories) do
    begin
      CategoryName := PlayerStatsCategories[CategoryIndex];
      CategoryValue :=
        PlayerStatsByCategory.GetValue(CategoryName);

      if not (CategoryValue is TJSONObject) then
        raise EJSONException.Create(
          'Missing Player Stats category object: ' +
          CategoryName
        );

      CategoryObject := TJSONObject(CategoryValue);
      PlayersValue := CategoryObject.GetValue('players');

      if not (PlayersValue is TJSONArray) then
        raise EJSONException.Create(
          'Missing players array for Player Stats category: ' +
          CategoryName
        );

      Players := TJSONArray(PlayersValue);

      for PlayerIndex := 0 to Players.Count - 1 do
      begin
        PlayerValue := Players.Items[PlayerIndex];

        if not (PlayerValue is TJSONObject) then
          Continue;

        PlayerObject := TJSONObject(PlayerValue);
        PlayerName := JsonStringValue(
          PlayerObject,
          'player'
        );
        PlayerKey := NormalizePlayerName(PlayerName);

        Inc(TotalPlayerRows);

        if not DistinctPlayers.ContainsKey(PlayerKey) then
          DistinctPlayers.Add(PlayerKey, True);

        if not FindRosterPlayer(
          PlayerName,
          TeamSide,
          TeamName,
          ShirtNumber,
          IsStarter,
          TeamLineup,
          RosterMatchCount
        ) then
        begin
          UnmatchedRow := TJSONObject.Create;
          UnmatchedRow.AddPair('category', CategoryName);
          UnmatchedRow.AddPair('player', PlayerName);

          if RosterMatchCount > 1 then
          begin
            Inc(AmbiguousPlayerRows);
            UnmatchedRow.AddPair('reason', 'ambiguous_roster_match');
            UnmatchedRow.AddPair(
              'match_count',
              TJSONNumber.Create(RosterMatchCount)
            );
          end
          else
          begin
            Inc(UnmatchedPlayerRows);
            UnmatchedRow.AddPair('reason', 'roster_not_found');
          end;

          UnmatchedRows.AddElement(UnmatchedRow);
          Continue;
        end;

        SetStringMember(
          PlayerObject,
          'team_side',
          TeamSide
        );
        SetStringMember(
          PlayerObject,
          'team',
          TeamName
        );
        SetIntegerMember(
          PlayerObject,
          'shirt_number',
          ShirtNumber
        );
        SetBooleanMember(
          PlayerObject,
          'is_starter',
          IsStarter
        );

        if IsStarter then
        begin
          HasMinuteIn := True;
          MinuteIn := 0;
          MinuteInRaw := '0';
        end
        else
          HasMinuteIn := FindSubstitutionMinute(
            TeamLineup,
            PlayerName,
            'incoming',
            MinuteInRaw,
            MinuteIn
          );

        HasMinuteOut := FindSubstitutionMinute(
          TeamLineup,
          PlayerName,
          'outgoing',
          MinuteOutRaw,
          MinuteOut
        );
        ExitReason := '';

        if RedCardsByPlayer.TryGetValue(
          PlayerKey,
          RedCardInfo
        ) and
           (
             not HasMinuteOut or
             (RedCardInfo.Minute <= MinuteOut)
           ) then
        begin
          HasMinuteOut := True;
          MinuteOut := RedCardInfo.Minute;
          MinuteOutRaw := RedCardInfo.RawMinute;
          ExitReason := 'red_card';
          Inc(RedCardExitRowCount);

          if not RedCardPlayersApplied.ContainsKey(
            PlayerKey
          ) then
            RedCardPlayersApplied.Add(
              PlayerKey,
              True
            );
        end
        else if HasMinuteOut then
          ExitReason := 'substitution';

        if HasMinuteIn then
        begin
          SetIntegerMember(
            PlayerObject,
            'minute_in',
            MinuteIn
          );
          SetStringMember(
            PlayerObject,
            'minute_in_raw',
            MinuteInRaw
          );
        end
        else
        begin
          SetNullMember(PlayerObject, 'minute_in');
          SetNullMember(PlayerObject, 'minute_in_raw');
        end;

        if HasMinuteOut then
        begin
          SetIntegerMember(
            PlayerObject,
            'minute_out',
            MinuteOut
          );
          SetStringMember(
            PlayerObject,
            'minute_out_raw',
            MinuteOutRaw
          );
          SetStringMember(
            PlayerObject,
            'exit_reason',
            ExitReason
          );
        end
        else
        begin
          SetNullMember(PlayerObject, 'minute_out');
          SetNullMember(PlayerObject, 'minute_out_raw');
          SetNullMember(PlayerObject, 'exit_reason');
        end;

        HasMinutesPlayed := FindGeneralMinutes(
          PlayerName,
          MinutesPlayed
        );

        if HasMinutesPlayed then
          SetIntegerMember(
            PlayerObject,
            'minutes_played',
            MinutesPlayed
          )
        else
          SetNullMember(
            PlayerObject,
            'minutes_played'
          );

        Inc(EnrichedPlayerRows);
      end;
    end;

    ValidationObject := TJSONObject.Create;
    ValidationObject.AddPair(
      'category_count',
      TJSONNumber.Create(
        Length(PlayerStatsCategories)
      )
    );
    ValidationObject.AddPair(
      'total_player_rows',
      TJSONNumber.Create(TotalPlayerRows)
    );
    ValidationObject.AddPair(
      'enriched_player_rows',
      TJSONNumber.Create(EnrichedPlayerRows)
    );
    ValidationObject.AddPair(
      'unmatched_player_rows',
      TJSONNumber.Create(UnmatchedPlayerRows)
    );
    ValidationObject.AddPair(
      'ambiguous_player_rows',
      TJSONNumber.Create(AmbiguousPlayerRows)
    );
    ValidationObject.AddPair(
      'distinct_player_count',
      TJSONNumber.Create(DistinctPlayers.Count)
    );
    ValidationObject.AddPair(
      'general_minutes_player_count',
      TJSONNumber.Create(GeneralMinutesPlayerCount)
    );
    ValidationObject.AddPair(
      'red_card_event_count',
      TJSONNumber.Create(RedCardEventCount)
    );
    ValidationObject.AddPair(
      'red_card_matched_event_count',
      TJSONNumber.Create(RedCardMatchedEventCount)
    );
    ValidationObject.AddPair(
      'red_card_matched_player_count',
      TJSONNumber.Create(RedCardsByPlayer.Count)
    );
    ValidationObject.AddPair(
      'red_card_applied_player_count',
      TJSONNumber.Create(RedCardPlayersApplied.Count)
    );
    ValidationObject.AddPair(
      'red_card_exit_row_count',
      TJSONNumber.Create(RedCardExitRowCount)
    );
    ValidationObject.AddPair(
      'red_card_unmatched_event_count',
      TJSONNumber.Create(RedCardUnmatchedEventCount)
    );
    ValidationObject.AddPair(
      'all_rows_enriched',
      TJSONBool.Create(
        (EnrichedPlayerRows = TotalPlayerRows) and
        (UnmatchedPlayerRows = 0) and
        (AmbiguousPlayerRows = 0)
      )
    );
    ValidationObject.AddPair(
      'all_red_cards_resolved',
      TJSONBool.Create(
        (RedCardMatchedEventCount = RedCardEventCount) and
        (RedCardUnmatchedEventCount = 0) and
        (RedCardPlayersApplied.Count = RedCardsByPlayer.Count)
      )
    );
    ValidationObject.AddPair(
      'unmatched_rows',
      UnmatchedRows
    );
    UnmatchedRows := nil;
    ValidationObject.AddPair(
      'red_card_assignments',
      RedCardAssignments
    );
    RedCardAssignments := nil;
    ValidationObject.AddPair(
      'unmatched_red_card_events',
      UnmatchedRedCardEvents
    );
    UnmatchedRedCardEvents := nil;

    ExistingPair :=
      FAggregate.RemovePair(
        'player_stats_enrichment_validation'
      );
    ExistingPair.Free;
    FAggregate.AddPair(
      'player_stats_enrichment_validation',
      ValidationObject
    );
    ValidationObject := nil;

    Log(Format(
      'Player Stats enrichment: %d/%d rows; %d distinct players; ' +
      '%d/%d red cards resolved.',
      [
        EnrichedPlayerRows,
        TotalPlayerRows,
        DistinctPlayers.Count,
        RedCardMatchedEventCount,
        RedCardEventCount
      ]
    ));

    if (UnmatchedPlayerRows > 0) or
       (AmbiguousPlayerRows > 0) then
      Log(Format(
        'WARNING: Player Stats enrichment partial: %d/%d rows enriched; ' +
        '%d unmatched, %d ambiguous rows.',
        [
          EnrichedPlayerRows,
          TotalPlayerRows,
          UnmatchedPlayerRows,
          AmbiguousPlayerRows
        ]
      ));

    if (RedCardUnmatchedEventCount > 0) or
       (RedCardMatchedEventCount <> RedCardEventCount) or
       (RedCardPlayersApplied.Count <> RedCardsByPlayer.Count) then
      Log(Format(
        'WARNING: Red-card enrichment partial: %d/%d events matched, ' +
        '%d players applied.',
        [
          RedCardMatchedEventCount,
          RedCardEventCount,
          RedCardPlayersApplied.Count
        ]
      ));
  finally
    ValidationObject.Free;
    UnmatchedRedCardEvents.Free;
    RedCardAssignments.Free;
    UnmatchedRows.Free;
    RedCardPlayersApplied.Free;
    RedCardsByPlayer.Free;
    DistinctPlayers.Free;
  end;
end;

procedure TMainForm.SaveAggregateJson;
const
  RequiredPlayerStatsCategories: array[0..6] of string = (
    'top_stats',
    'shots',
    'attack',
    'passes',
    'defense',
    'goalkeeping',
    'general'
  );
var
  Statistics: TJSONArray;
  StatisticsValue: TJSONValue;
  PlayerStatsValue: TJSONValue;
  PlayerStatsByCategory: TJSONObject;
  CategoryIndex: Integer;
  CollectedPlayerStatsCategoryCount: Integer;
  MissingPlayerStatsCategories: TJSONArray;
  PlayerStatsAvailability: TJSONObject;
  CoverageCopy: TJSONValue;
  RowCount: Integer;
begin
  if FAggregate = nil then
    raise EJSONException.Create('Aggregate JSON is empty.');

  SetStage(csSaving, 'Saving complete match JSON...');

  StatisticsValue := FAggregate.GetValue('statistics');

  if StatisticsValue is TJSONArray then
    Statistics := TJSONArray(StatisticsValue)
  else
    Statistics := nil;

  if Statistics <> nil then
    RowCount := Statistics.Count
  else
    RowCount := 0;

  if (RowCount = 0) and not IsArchive2022Mode then
    raise EJSONException.Create('No statistics were collected.');

  PlayerStatsValue :=
    FAggregate.GetValue('player_stats_by_category');

  if not (PlayerStatsValue is TJSONObject) then
    PlayerStatsByCategory := nil
  else
    PlayerStatsByCategory := TJSONObject(PlayerStatsValue);

  CollectedPlayerStatsCategoryCount := 0;
  MissingPlayerStatsCategories := TJSONArray.Create;
  for CategoryIndex :=
    Low(RequiredPlayerStatsCategories) to
    High(RequiredPlayerStatsCategories) do
  begin
    if (PlayerStatsByCategory = nil) or
       (PlayerStatsByCategory.GetValue(RequiredPlayerStatsCategories[CategoryIndex]) = nil) then
    begin
      MissingPlayerStatsCategories.Add(
        RequiredPlayerStatsCategories[CategoryIndex]);
      Log('Player Stats category unavailable; status=not_available: ' +
        RequiredPlayerStatsCategories[CategoryIndex]);
    end
    else
      Inc(CollectedPlayerStatsCategoryCount);
  end;

  PlayerStatsAvailability := TJSONObject.Create;
  PlayerStatsAvailability.AddPair('supported_by_profile',
    TJSONBool.Create(FSupportsPlayerStats));
  PlayerStatsAvailability.AddPair('expected_category_count',
    TJSONNumber.Create(Length(RequiredPlayerStatsCategories)));
  PlayerStatsAvailability.AddPair('collected_category_count',
    TJSONNumber.Create(CollectedPlayerStatsCategoryCount));
  if CollectedPlayerStatsCategoryCount = Length(RequiredPlayerStatsCategories) then
    PlayerStatsAvailability.AddPair('status', 'available')
  else if CollectedPlayerStatsCategoryCount > 0 then
    PlayerStatsAvailability.AddPair('status', 'partial')
  else
    PlayerStatsAvailability.AddPair('status', 'not_available');
  if CollectedPlayerStatsCategoryCount = 0 then
  begin
    if not FSupportsPlayerStats then
      PlayerStatsAvailability.AddPair('reason',
        'player_stats_not_available_for_selected_competition_season')
    else
      PlayerStatsAvailability.AddPair('reason',
        'player_stats_not_available_for_match');
  end
  else if CollectedPlayerStatsCategoryCount <
          Length(RequiredPlayerStatsCategories) then
    PlayerStatsAvailability.AddPair('reason',
      'some_player_stats_categories_not_available_for_match')
  else
    PlayerStatsAvailability.AddPair('reason', TJSONNull.Create);
  PlayerStatsAvailability.AddPair('missing_categories',
    MissingPlayerStatsCategories);
  FAggregate.RemovePair('player_stats_availability').Free;
  FAggregate.AddPair('player_stats_availability',
    PlayerStatsAvailability);

  // Keep only the period-aware Player Stats container.
  FAggregate.RemovePair('player_stats').Free;

  if CollectedPlayerStatsCategoryCount =
     Length(RequiredPlayerStatsCategories) then
    EnrichPlayerStats;
  EnrichStructuredEvents(FAggregate);
  Log('Structured goals, cards and VAR events enriched.');

  FAggregate.RemovePair('section').Free;
  FAggregate.RemovePair('schema_version').Free;
  FAggregate.AddPair('schema_version', '3.20');
  FAggregate.RemovePair('source').Free;
  FAggregate.AddPair('source', 'flashscore');
  FAggregate.RemovePair('collected_at_utc').Free;
  FAggregate.AddPair('collected_at_utc', IsoNowUtc);
  FAggregate.RemovePair('collector_profile').Free;
  var CollectorProfile := TJSONObject.Create;
  CollectorProfile.AddPair('competition_key', FCompetitionKey);
  CollectorProfile.AddPair('competition', FCompetitionDisplayName);
  CollectorProfile.AddPair('season', FSeasonCombo.Text);
  CollectorProfile.AddPair('season_key', FSeasonKey);
  CollectorProfile.AddPair('expected_match_count',
    TJSONNumber.Create(FExpectedMatchCount));
  CollectorProfile.AddPair('supports_player_stats',
    TJSONBool.Create(FSupportsPlayerStats));
  FAggregate.AddPair('collector_profile', CollectorProfile);

  if FCoverageSections <> nil then
    for var PendingPair in FCoverageSections do
      if SameText(JsonStringValue(TJSONObject(PendingPair.JsonValue),
        'status', ''), 'pending') then
      begin
        var PendingObject := TJSONObject(PendingPair.JsonValue);
        PendingObject.RemovePair('status').Free;
        PendingObject.AddPair('status', 'not_available');
      end;

  FAggregate.RemovePair('collection_coverage').Free;
  if FCoverageSections <> nil then
  begin
    CoverageCopy := TJSONObject.ParseJSONValue(FCoverageSections.ToJSON);
    if CoverageCopy = nil then
      raise EJSONException.Create('Unable to copy collection coverage.');
    FAggregate.AddPair('collection_coverage', CoverageCopy);
  end;

  FOutputFile := BuildOutputFileName(FAggregate);
  EnsureDirectoryForFile(FOutputFile);
  TFile.WriteAllText(FOutputFile, FAggregate.Format(2), TEncoding.UTF8);
  FViewJsonButton.Enabled := TFile.Exists(FOutputFile);
  FStore.MarkProcessed(FCurrentItem.MatchId, FOutputFile);
  FLastCompletedMatchId := FCurrentItem.MatchId;

  // Expected unavailable optional sections do not make the match partial.
  // Player Stats can be absent by profile, while extra-time statistics are
  // not applicable to normal-time matches.
  var IsPartial := False;
  if FCoverageSections <> nil then
    for var CoveragePair in FCoverageSections do
    begin
      var CoverageObject := TJSONObject(CoveragePair.JsonValue);
      var CoverageStatus := JsonStringValue(CoverageObject, 'status', '');
      var SectionName := CoveragePair.JsonString.Value;

      if SameText(CoverageStatus, 'failed') or
         SameText(CoverageStatus, 'empty') then
      begin
        IsPartial := True;
        Break;
      end;

      if SameText(CoverageStatus, 'not_available') and
         (SameText(SectionName, 'statistics_match') or
          SameText(SectionName, 'statistics_first_half') or
          SameText(SectionName, 'statistics_second_half') or
          SameText(SectionName, 'lineups') or
          SameText(SectionName, 'commentary')) then
      begin
        IsPartial := True;
        Break;
      end;
    end;
  SaveCoverageReport(IsPartial);
  if IsArchive2022Mode then
  begin
    Inc(FArchiveSavedCount);
    if IsPartial then
      Inc(FArchivePartialCount);
  end;
  Log(Format('Saved match JSON with %d statistics: %s',
    [RowCount, FOutputFile]));
  FinishSuccess;
end;

procedure TMainForm.EdgeNavigationCompleted(Sender: TCustomEdgeBrowser;
  IsSuccess: Boolean; WebErrorStatus: COREWEBVIEW2_WEB_ERROR_STATUS);
begin
  if not IsSuccess then
  begin
    HandlePhaseFailure(Format('Navigation failed. Web error: %d', [Ord(WebErrorStatus)]));
    Exit;
  end;

  if FDiscoveringMatches then
  begin
    SetStage(csWaitingForDom, 'Tournament page loaded. Waiting for match list...');
    FPollTimer.Enabled := True;
    Exit;
  end;

  if Pos('/match/', LowerCase(FEdgeBrowser.LocationURL)) = 0 then
  begin
    Log('Ignoring non-match navigation completion: ' +
      FEdgeBrowser.LocationURL);
    Exit;
  end;

  SetStage(csWaitingForDom, 'Page loaded. Waiting for statistics DOM...');
  FPollTimer.Enabled := True;
end;

procedure TMainForm.PollDom;
begin
  if FPendingScript <> '' then
    Exit;

  if FDiscoveringMatches then
  begin
    ExecuteMatchDiscovery;
    Exit;
  end;

  FPendingScript := 'readiness';
  FEdgeBrowser.ExecuteScript(BuildReadinessScript);
end;

procedure TMainForm.ExecuteExtraction;
var
  ScriptText: string;
begin
  FPollTimer.Enabled := False;
  SetStage(csReadingMatch, 'Reading rendered DOM...');
  FPendingScript := 'extract';

  case FPhase of
    cpStatistics,
    cpStatisticsFirstHalf,
    cpStatisticsSecondHalf,
    cpStatisticsExtraTime:
      ScriptText := BuildStatisticsExtractionScript;

    cpLineups:
      ScriptText := BuildLineupsExtractionScript;

    cpPlayerStatsTopStats,
    cpPlayerStatsShots,
    cpPlayerStatsAttack,
    cpPlayerStatsPasses,
    cpPlayerStatsDefense,
    cpPlayerStatsGoalkeeping,
    cpPlayerStatsGeneral:
      ScriptText := BuildPlayerStatsExtractionScript(
        PlayerStatsCategoryKey(FPhase)
      );

    cpCommentary:
      ScriptText := BuildCommentaryExtractionScript;
  else
    raise EInvalidOpException.Create(
      'No extraction script is assigned to the current phase.');
  end;

  Log(Format(
    'Executing extraction script for phase %d; length: %d.',
    [Ord(FPhase), Length(ScriptText)]
  ));

  FEdgeBrowser.ExecuteScript(ScriptText);
end;

procedure TMainForm.EdgeExecuteScript(Sender: TCustomEdgeBrowser;
  AResult: HRESULT; const AResultObjectAsJson: string);
var
  Pending: string;
  Decoded: string;
  Root: TJSONObject;
  Ready: Boolean;
begin
  Pending := FPendingScript;
  FPendingScript := '';

  if (Pending = 'extract') or (Pending = 'discover_matches') then
    FTimeoutTimer.Enabled := False;

  if AResult < 0 then
  begin
    HandlePhaseFailure(Format('JavaScript execution failed: 0x%.8x', [Cardinal(AResult)]));
    Exit;
  end;

  try
    Decoded := DecodeExecuteScriptResult(AResultObjectAsJson);
    Log('Script [' + Pending + '] result prefix: ' +
      Copy(Decoded, 1, 500));

    if SameText(Trim(Decoded), 'null') or (Trim(Decoded) = '') then
      raise EJSONException.Create(
        'JavaScript returned null/empty result. Check the script and page DOM.');
    if Pending = 'readiness' then
    begin
      Root := ParseJsonObject(Decoded);
      try
        Ready := JsonBooleanValue(Root, 'ready', False);
        if Ready then
          ExecuteExtraction
        else
          Log(Format('DOM not ready; statistic rows: %d',
            [JsonIntegerValue(Root, 'row_count', 0)]));
      finally
        Root.Free;
      end;
      Exit;
    end;

    if Pending = 'discover_matches' then
    begin
      if not Decoded.Trim.StartsWith('{') then
      begin
        Log('Unexpected discovery script result: ' + Copy(Decoded, 1, 1000));
        Inc(FDiscoveryPageIndex);
        NavigateDiscoveryPage;
        Exit;
      end;

      ProcessDiscoveredMatches(Decoded);
      Exit;
    end;

    if Pending = 'extract' then
      ProcessExtractedSection(Decoded);
  except
    on E: Exception do
      HandlePhaseFailure('Script result error: ' + E.Message);
  end;
end;

function TMainForm.BuildOutputFileName(const ARoot: TJSONObject): string;
var
  MatchId: string;
  HomeTeam: string;
  AwayTeam: string;
  DateText: string;
begin
  MatchId := JsonStringValue(ARoot, 'match_id', FCurrentItem.MatchId);
  HomeTeam := JsonStringValue(ARoot, 'home_team', 'home');
  AwayTeam := JsonStringValue(ARoot, 'away_team', 'away');
  DateText := JsonStringValue(ARoot, 'date_time',
    FormatDateTime('yyyy-mm-dd', Date));

  DateText := DateText.Substring(0, Min(10, DateText.Length));

  // Flashscore commonly returns dd.mm.yyyy. Normalize file names to yyyy-mm-dd.
  var ParsedDate: TDateTime := 0.0;
  var DateFormat := TFormatSettings.Create;
  DateFormat.DateSeparator := '.';
  DateFormat.ShortDateFormat := 'dd.mm.yyyy';

  if TryStrToDate(DateText, ParsedDate, DateFormat) then
    DateText := FormatDateTime('yyyy-mm-dd', ParsedDate)
  else
    DateText := SafeFileName(DateText);

  Result := Format('%s_%s_vs_%s_%s.json', [
    DateText,
    SafeFileName(HomeTeam),
    SafeFileName(AwayTeam),
    SafeFileName(MatchId)
  ]);
  Result := TPath.Combine(AppPath(FConfig.OutputDirectory), Result);
end;

procedure TMainForm.SaveCoverageReport(const APartial: Boolean);
var
  Root: TJSONObject;
  OutputName: string;
  SectionsCopy: TJSONValue;
begin
  if not IsArchive2022Mode or (FCurrentItem = nil) then
    Exit;
  Root := TJSONObject.Create;
  try
    Root.AddPair('coverage_schema_version', '1.0');
    Root.AddPair('collector_version', '45.4');
    Root.AddPair('mode', 'archive_2022');
    var ReportMatchId := FCurrentItem.MatchId;
    var ReportSourceUrl := FCurrentItem.Url;
    if FAggregate <> nil then
    begin
      ReportMatchId := JsonStringValue(FAggregate, 'match_id', ReportMatchId);
      ReportSourceUrl := JsonStringValue(FAggregate, 'source_url', ReportSourceUrl);
    end;
    Root.AddPair('match_id', ReportMatchId);
    Root.AddPair('source_url', ReportSourceUrl);
    Root.AddPair('completed', TJSONBool.Create(True));
    Root.AddPair('partial', TJSONBool.Create(APartial));
    SectionsCopy := TJSONObject.ParseJSONValue(FCoverageSections.ToJSON);
    Root.AddPair('sections', SectionsCopy);
    OutputName := TPath.Combine(AppPath(FConfig.ArchiveCoverageDirectory),
      SafeFileName(ReportMatchId) + '.coverage.json');
    EnsureDirectoryForFile(OutputName);
    TFile.WriteAllText(OutputName, Root.Format(2), TEncoding.UTF8);
    Log('Saved coverage report: ' + OutputName);
  finally
    Root.Free;
  end;
end;

procedure TMainForm.SaveArchiveBatchReport;
var
  Root: TJSONObject;
  OutputName: string;
begin
  if not IsBatchMode then
    Exit;
  Root := TJSONObject.Create;
  try
    Root.AddPair('coverage_schema_version', '1.0');
    Root.AddPair('collector_version', '45.4');
    Root.AddPair('mode', 'archive_2022');
    Root.AddPair('started_at_utc', FArchiveBatchStartedAtUtc);
    Root.AddPair('finished_at_utc', IsoNowUtc);
    Root.AddPair('requested_match_count', TJSONNumber.Create(FQueue.Items.Count));
    Root.AddPair('saved_match_count', TJSONNumber.Create(FArchiveSavedCount));
    Root.AddPair('partial_match_count', TJSONNumber.Create(FArchivePartialCount));
    Root.AddPair('failed_match_count', TJSONNumber.Create(FArchiveFailedCount));
    OutputName := TPath.Combine(AppPath(FConfig.ArchiveCoverageDirectory),
      'archive_2022_batch.coverage.json');
    EnsureDirectoryForFile(OutputName);
    TFile.WriteAllText(OutputName, Root.Format(2), TEncoding.UTF8);
    Log('Saved archive batch report: ' + OutputName);
  finally
    Root.Free;
  end;
end;

procedure TMainForm.ContinueBatch;
var
  NextItem: TMatchQueueItem;
begin
  if not IsBatchMode then
    Exit;

  NextItem := FQueue.FirstUnprocessed(FStore);
  if NextItem = nil then
  begin
    if IsArchive2022Mode then
    begin
      SaveArchiveBatchReport;
      SetStage(csFinished, Format(
        'Batch finished. Saved=%d, partial=%d, failed=%d.',
        [FArchiveSavedCount, FArchivePartialCount, FArchiveFailedCount]));
    end
    else
      SetStage(csFinished, Format('Batch finished. Processed=%d/%d.',
        [FStore.Count, FQueue.Items.Count]));

    if FMode <> cmInteractive then
      Close;
    Exit;
  end;
  BeginCollection(NextItem);
end;

procedure TMainForm.FinishSuccess;
begin
  FPollTimer.Enabled := False;
  FTimeoutTimer.Enabled := False;
  SetStage(csFinished, 'Finished: ' + ExtractFileName(FOutputFile));

  if FMode = cmCollectOne then
    Close
  else if IsBatchMode then
  begin
    UpdateUiState;
    if FStopRequested then
      SetStage(csFinished, 'Stopped safely after current match.')
    else
      ContinueBatch;
  end;
end;

procedure TMainForm.Fail(const AMessage: string);
begin
  FPollTimer.Enabled := False;
  FTimeoutTimer.Enabled := False;
  SetStage(csFailed, AMessage);
  Log('ERROR: ' + AMessage);

  if FMode = cmCollectOne then
  begin
    Application.ProcessMessages;
    Halt(1);
  end;
end;

procedure TMainForm.SetStage(const AStage: TCollectorStage;
  const AText: string);
begin
  FStage := AStage;
  FStatusLabel.Caption := AText;

  var IsBusy := AStage in [
    csCreatingBrowser,
    csNavigating,
    csWaitingForDom,
    csReadingMatch,
    csSaving
  ];

  if FCollectButton <> nil then
    FCollectButton.Enabled := not IsBusy;
  if FDiscoverButton <> nil then
    FDiscoverButton.Enabled := not IsBusy;
  if FStopButton <> nil then
    FStopButton.Enabled := IsBusy and not FStopRequested;
  if FCompetitionCombo <> nil then
    FCompetitionCombo.Enabled := not IsBusy;
  if FSeasonCombo <> nil then
    FSeasonCombo.Enabled := not IsBusy;
  if FModeCombo <> nil then
    FModeCombo.Enabled := not IsBusy;

  if FNextMatchButton <> nil then
    FNextMatchButton.Enabled :=
      (not IsBusy) and (FQueue <> nil) and (FStore <> nil);

  UpdateUiState;
  Log(AText);
end;

procedure TMainForm.Log(const AMessage: string);
begin
  FLogMemo.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + AMessage);
  AppendLog(FConfig.LogFile, AMessage);
end;

procedure TMainForm.CollectButtonClick(Sender: TObject);
begin
  ApplySelectedProfile;
  FStopRequested := False;
  FDiscoveryOnly := False;
  FFullSeasonMode := FModeCombo.ItemIndex in [0, 1];
  if IsArchive2022Mode then
    FArchiveBatchStartedAtUtc := IsoNowUtc;

  FreeAndNil(FStore);
  FreeAndNil(FQueue);
  FStore := TProcessedMatchStore.Create(FConfig.ProcessedFile, FConfig.OutputDirectory);
  FQueue := TMatchQueue.Create(FConfig.QueueFile);

  if FModeCombo.ItemIndex = 3 then
    StartCollectOne
  else
    StartMatchDiscovery;
end;

procedure TMainForm.NextMatchButtonClick(Sender: TObject);
begin
  StartNextMatch;
end;

procedure TMainForm.OpenOutputButtonClick(Sender: TObject);
var
  DirectoryName: string;
begin
  DirectoryName := AppPath(FConfig.OutputDirectory);
  ForceDirectories(DirectoryName);
  ShellExecute(Handle, 'open', PChar(DirectoryName), nil, nil, SW_SHOWNORMAL);
end;

function TMainForm.FindLatestOutputJson: string;
var
  DirectoryName: string;
  Files: TArray<string>;
  FileName: string;
  LatestTime: TDateTime;
  CurrentTime: TDateTime;
begin
  Result := '';
  DirectoryName := AppPath(FConfig.OutputDirectory);

  if not TDirectory.Exists(DirectoryName) then
    Exit;

  Files := TDirectory.GetFiles(
    DirectoryName,
    '*.json',
    TSearchOption.soTopDirectoryOnly
  );

  LatestTime := 0;

  for FileName in Files do
  begin
    CurrentTime := TFile.GetLastWriteTime(FileName);

    if (Result = '') or (CurrentTime > LatestTime) then
    begin
      Result := FileName;
      LatestTime := CurrentTime;
    end;
  end;
end;

procedure TMainForm.ViewJsonButtonClick(Sender: TObject);
begin
  if (FOutputFile = '') or not TFile.Exists(FOutputFile) then
    FOutputFile := FindLatestOutputJson;

  if (FOutputFile = '') or not TFile.Exists(FOutputFile) then
  begin
    ShowMessage('No collected JSON file is available yet.');
    Exit;
  end;

  ShowJsonViewer(Self, FOutputFile);
end;

procedure TMainForm.PollTimerTimer(Sender: TObject);
begin
  PollDom;
end;

procedure TMainForm.TimeoutTimerTimer(Sender: TObject);
begin
  if FDiscoveringMatches then
  begin
    FPollTimer.Enabled := False;
    FTimeoutTimer.Enabled := False;
    Log(Format(
      'Discovery timed out after %d seconds. Continuing with the next discovery page.',
      [FConfig.PageTimeoutSeconds]));
    Inc(FDiscoveryPageIndex);
    NavigateDiscoveryPage;
    Exit;
  end;

  HandlePhaseFailure(Format(
    'Timed out after %d seconds while waiting for the page.',
    [FConfig.PageTimeoutSeconds]));
end;

end.
