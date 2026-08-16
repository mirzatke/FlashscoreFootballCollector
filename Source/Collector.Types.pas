unit Collector.Types;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TCollectorMode = (cmInteractive, cmCollectOne, cmArchive2022, cmPremierLeague2526);

  TCollectorStage = (
    csIdle,
    csCreatingBrowser,
    csNavigating,
    csWaitingForDom,
    csReadingMatch,
    csSaving,
    csFinished,
    csFailed
  );

  TMatchQueueItem = class
  private
    FUrl: string;
    FMatchId: string;
  public
    property Url: string read FUrl write FUrl;
    property MatchId: string read FMatchId write FMatchId;
  end;

  TCollectorConfig = class
  private
    FStartDate: TDate;
    FOutputDirectory: string;
    FProcessedFile: string;
    FQueueFile: string;
    FLogFile: string;
    FPageTimeoutSeconds: Integer;
    FVisibleBrowser: Boolean;
    FCompetitionResultsUrl: string;
    FCompetitionFixturesUrl: string;
    FArchiveQueueFile: string;
    FArchiveCoverageDirectory: string;
  public
    constructor Create;
    property StartDate: TDate read FStartDate write FStartDate;
    property OutputDirectory: string read FOutputDirectory write FOutputDirectory;
    property ProcessedFile: string read FProcessedFile write FProcessedFile;
    property QueueFile: string read FQueueFile write FQueueFile;
    property LogFile: string read FLogFile write FLogFile;
    property PageTimeoutSeconds: Integer read FPageTimeoutSeconds write FPageTimeoutSeconds;
    property VisibleBrowser: Boolean read FVisibleBrowser write FVisibleBrowser;
    property CompetitionResultsUrl: string read FCompetitionResultsUrl write FCompetitionResultsUrl;
    property CompetitionFixturesUrl: string read FCompetitionFixturesUrl write FCompetitionFixturesUrl;
    property ArchiveQueueFile: string read FArchiveQueueFile write FArchiveQueueFile;
    property ArchiveCoverageDirectory: string read FArchiveCoverageDirectory write FArchiveCoverageDirectory;
  end;

implementation

constructor TCollectorConfig.Create;
begin
  inherited Create;
  FStartDate := EncodeDate(2026, 6, 1);
  FOutputDirectory := 'Data\Matches\WC\WC_2026';
  FProcessedFile := 'Data\processed_matches.json';
  FQueueFile := 'Data\match_queue.json';
  FLogFile := 'Data\Logs\WC\WC_2026\collector.log';
  FPageTimeoutSeconds := 45;
  FVisibleBrowser := True;
  FCompetitionResultsUrl :=
    'https://www.flashscore.com/football/world/world-championship/results/';
  FCompetitionFixturesUrl :=
    'https://www.flashscore.com/football/world/world-championship/fixtures/';
  FArchiveQueueFile := 'Data\archive_2022_matches.json';
  FArchiveCoverageDirectory := 'Data\Coverage\Archive2022';
end;

end.
