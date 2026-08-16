unit Collector.Profiles;

interface

uses
  System.Classes;

type
  TCompetitionProfile = record
    CompetitionKey: string;
    CompetitionName: string;
    SeasonCaption: string;
    SeasonKey: string;
    OutputDirectory: string;
    ProcessedFile: string;
    QueueFile: string;
    LogFile: string;
    ResultsUrl: string;
    FixturesUrl: string;
    ExpectedMatchCount: Integer;
    IsArchive2022: Boolean;
    SupportsPlayerStats: Boolean;
    RegularSeasonRoundsOnly: Boolean;
  end;

procedure PopulateCompetitionNames(const AItems: TStrings);
procedure PopulateSeasonNames(const ACompetitionName: string;
  const AItems: TStrings);
function TryGetCompetitionProfile(const ACompetitionName,
  ASeasonCaption: string; out AProfile: TCompetitionProfile): Boolean;

implementation

uses
  System.SysUtils;

const
  WorldCupName = 'FIFA World Cup';
  PremierLeagueName = 'English Premier League';
  LaLigaName = 'Spanish LaLiga';
  BundesligaName = 'German Bundesliga';
  SerieAName = 'Italian Serie A';
  Ligue1Name = 'French Ligue 1';

procedure PopulateCompetitionNames(const AItems: TStrings);
begin
  AItems.Clear;
  AItems.Add(WorldCupName);
  AItems.Add(PremierLeagueName);
  AItems.Add(LaLigaName);
  AItems.Add(BundesligaName);
  AItems.Add(SerieAName);
  AItems.Add(Ligue1Name);
end;

procedure PopulateSeasonNames(const ACompetitionName: string;
  const AItems: TStrings);
begin
  AItems.Clear;
  if SameText(ACompetitionName, WorldCupName) then
  begin
    AItems.Add('2026');
    AItems.Add('2022');
  end
  else
  begin
    AItems.Add('2025/2026');
    AItems.Add('2024/2025');
    AItems.Add('2023/2024');
  end;
end;

procedure ConfigureLeagueProfile(var AProfile: TCompetitionProfile;
  const ACompetitionKey, ACompetitionName, ASeasonCaption,
  ACountrySlug, ALeagueSlug, AOutputFolder: string;
  const AExpectedMatchCount: Integer);
var
  UrlSeason: string;
begin
  AProfile.CompetitionKey := ACompetitionKey;
  AProfile.CompetitionName := ACompetitionName;
  AProfile.SeasonCaption := ASeasonCaption;
  AProfile.SeasonKey := StringReplace(ASeasonCaption, '/', '_', [rfReplaceAll]);
  AProfile.OutputDirectory := Format('Data\Matches\%s\%s',
    [AOutputFolder, AProfile.SeasonKey]);
  AProfile.ProcessedFile := Format('Data\processed_matches_%s_%s.json',
    [ACompetitionKey, AProfile.SeasonKey]);
  AProfile.QueueFile := Format('Data\%s_%s_matches.json',
    [ACompetitionKey, AProfile.SeasonKey]);
  AProfile.LogFile := Format('Data\Logs\%s\%s\collector.log',
    [AOutputFolder, AProfile.SeasonKey]);
  UrlSeason := StringReplace(ASeasonCaption, '/', '-', [rfReplaceAll]);
  AProfile.ResultsUrl := Format(
    'https://www.flashscore.com/football/%s/%s-%s/results/',
    [ACountrySlug, ALeagueSlug, UrlSeason]);
  AProfile.FixturesUrl := Format(
    'https://www.flashscore.com/football/%s/%s-%s/fixtures/',
    [ACountrySlug, ALeagueSlug, UrlSeason]);
  AProfile.ExpectedMatchCount := AExpectedMatchCount;
  AProfile.IsArchive2022 := False;
  AProfile.SupportsPlayerStats :=
    not SameText(ASeasonCaption, '2023/2024');
  AProfile.RegularSeasonRoundsOnly := True;
end;

function TryGetCompetitionProfile(const ACompetitionName,
  ASeasonCaption: string; out AProfile: TCompetitionProfile): Boolean;
begin
  AProfile := Default(TCompetitionProfile);
  Result := True;

  if SameText(ACompetitionName, WorldCupName) then
  begin
    AProfile.CompetitionKey := 'world_cup';
    AProfile.CompetitionName := WorldCupName;
    AProfile.SeasonCaption := ASeasonCaption;
    AProfile.SeasonKey := ASeasonCaption;
    AProfile.ExpectedMatchCount := 64;

    if SameText(ASeasonCaption, '2022') then
    begin
      AProfile.OutputDirectory := 'Data\Matches\WC\WC_2022';
      AProfile.ProcessedFile := 'Data\processed_matches_archive_2022.json';
      AProfile.QueueFile := 'Data\archive_2022_matches.json';
      AProfile.LogFile := 'Data\Logs\WC\WC_2022\collector.log';
      AProfile.ResultsUrl :=
        'https://www.flashscore.com/football/world/world-championship-2022/results/';
      AProfile.FixturesUrl := '';
      AProfile.IsArchive2022 := True;
      AProfile.SupportsPlayerStats := False;
      AProfile.RegularSeasonRoundsOnly := False;
    end
    else if SameText(ASeasonCaption, '2026') then
    begin
      AProfile.OutputDirectory := 'Data\Matches\WC\WC_2026';
      AProfile.ProcessedFile := 'Data\processed_matches.json';
      AProfile.QueueFile := 'Data\match_queue.json';
      AProfile.LogFile := 'Data\Logs\WC\WC_2026\collector.log';
      AProfile.ResultsUrl :=
        'https://www.flashscore.com/football/world/world-championship/results/';
      AProfile.FixturesUrl :=
        'https://www.flashscore.com/football/world/world-championship/fixtures/';
      AProfile.SupportsPlayerStats := True;
      AProfile.RegularSeasonRoundsOnly := False;
    end
    else
      Result := False;
    Exit;
  end;

  if not (SameText(ASeasonCaption, '2025/2026') or
          SameText(ASeasonCaption, '2024/2025') or
          SameText(ASeasonCaption, '2023/2024')) then
    Exit(False);

  if SameText(ACompetitionName, PremierLeagueName) then
    ConfigureLeagueProfile(AProfile, 'premier_league', PremierLeagueName,
      ASeasonCaption, 'england', 'premier-league', 'PremierLeague', 380)
  else if SameText(ACompetitionName, LaLigaName) then
    ConfigureLeagueProfile(AProfile, 'la_liga', LaLigaName,
      ASeasonCaption, 'spain', 'laliga', 'LaLiga', 380)
  else if SameText(ACompetitionName, BundesligaName) then
    ConfigureLeagueProfile(AProfile, 'bundesliga', BundesligaName,
      ASeasonCaption, 'germany', 'bundesliga', 'Bundesliga', 306)
  else if SameText(ACompetitionName, SerieAName) then
    ConfigureLeagueProfile(AProfile, 'serie_a', SerieAName,
      ASeasonCaption, 'italy', 'serie-a', 'SerieA', 380)
  else if SameText(ACompetitionName, Ligue1Name) then
    ConfigureLeagueProfile(AProfile, 'ligue_1', Ligue1Name,
      ASeasonCaption, 'france', 'ligue-1', 'Ligue1', 306)
  else
    Result := False;
end;

end.
