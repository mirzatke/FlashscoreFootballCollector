unit Collector.Profiles;

interface

uses
  System.Classes;

type
  TSeasonKind = (
    skCurrent,
    skArchive
  );

  TSeasonProfile = record
    Caption: string;
    SeasonKey: string;
    Kind: TSeasonKind;
    UrlSeasonSlug: string;
    SupportsPlayerStats: Boolean;
  end;

  TCompetitionProfile = record
    CompetitionKey: string;
    CompetitionName: string;
    SeasonCaption: string;
    SeasonKey: string;
    SeasonKind: TSeasonKind;
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
  System.SysUtils,
  System.StrUtils;

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
    Exit;
  end;

  { League season captions are presentation only. URL behaviour is defined by
    TSeasonProfile.Kind, not by comparing the selected caption later. }
  AItems.Add('2026/2027');
  AItems.Add('2025/2026');
  AItems.Add('2024/2025');
  AItems.Add('2023/2024');
end;

function TryGetLeagueSeasonProfile(const ASeasonCaption: string;
  out ASeason: TSeasonProfile): Boolean;
var
  SeasonIndex: Integer;
begin
  ASeason := Default(TSeasonProfile);

  SeasonIndex := IndexText(ASeasonCaption, [
    '2026/2027',
    '2025/2026',
    '2024/2025',
    '2023/2024'
  ]);

  Result := SeasonIndex >= 0;
  if not Result then
    Exit;

  ASeason.Caption := ASeasonCaption;

  case SeasonIndex of
    0:
      begin
        ASeason.SeasonKey := '2026_2027';
        ASeason.Kind := skCurrent;
        ASeason.UrlSeasonSlug := '';
        ASeason.SupportsPlayerStats := True;
      end;
    1:
      begin
        ASeason.SeasonKey := '2025_2026';
        ASeason.Kind := skArchive;
        ASeason.UrlSeasonSlug := '2025-2026';
        ASeason.SupportsPlayerStats := True;
      end;
    2:
      begin
        ASeason.SeasonKey := '2024_2025';
        ASeason.Kind := skArchive;
        ASeason.UrlSeasonSlug := '2024-2025';
        ASeason.SupportsPlayerStats := True;
      end;
    3:
      begin
        ASeason.SeasonKey := '2023_2024';
        ASeason.Kind := skArchive;
        ASeason.UrlSeasonSlug := '2023-2024';
        ASeason.SupportsPlayerStats := False;
      end;
  else
    Result := False;
  end;
end;

procedure BuildLeagueUrls(const ASeason: TSeasonProfile;
  const ACountrySlug, ALeagueSlug: string; out AResultsUrl,
  AFixturesUrl: string);
begin
  case ASeason.Kind of
    skCurrent:
      begin
        AResultsUrl := Format(
          'https://www.flashscore.com/football/%s/%s/results/',
          [ACountrySlug, ALeagueSlug]);
        AFixturesUrl := Format(
          'https://www.flashscore.com/football/%s/%s/fixtures/',
          [ACountrySlug, ALeagueSlug]);
      end;

    skArchive:
      begin
        if ASeason.UrlSeasonSlug = '' then
          raise EArgumentException.Create(
            'Archive season profile requires UrlSeasonSlug.');

        AResultsUrl := Format(
          'https://www.flashscore.com/football/%s/%s-%s/results/',
          [ACountrySlug, ALeagueSlug, ASeason.UrlSeasonSlug]);
        AFixturesUrl := Format(
          'https://www.flashscore.com/football/%s/%s-%s/fixtures/',
          [ACountrySlug, ALeagueSlug, ASeason.UrlSeasonSlug]);
      end;
  else
    raise EArgumentOutOfRangeException.Create('Unknown season kind.');
  end;
end;

procedure ConfigureLeagueProfile(var AProfile: TCompetitionProfile;
  const ACompetitionKey, ACompetitionName, ACountrySlug, ALeagueSlug,
  AOutputFolder: string; const AExpectedMatchCount: Integer;
  const ASeason: TSeasonProfile);
begin
  AProfile.CompetitionKey := ACompetitionKey;
  AProfile.CompetitionName := ACompetitionName;
  AProfile.SeasonCaption := ASeason.Caption;
  AProfile.SeasonKey := ASeason.SeasonKey;
  AProfile.SeasonKind := ASeason.Kind;

  AProfile.OutputDirectory := Format('Data\Matches\%s\%s',
    [AOutputFolder, AProfile.SeasonKey]);
  AProfile.ProcessedFile := Format('Data\processed_matches_%s_%s.json',
    [ACompetitionKey, AProfile.SeasonKey]);
  AProfile.QueueFile := Format('Data\%s_%s_matches.json',
    [ACompetitionKey, AProfile.SeasonKey]);
  AProfile.LogFile := Format('Data\Logs\%s\%s\collector.log',
    [AOutputFolder, AProfile.SeasonKey]);

  BuildLeagueUrls(ASeason, ACountrySlug, ALeagueSlug,
    AProfile.ResultsUrl, AProfile.FixturesUrl);

  AProfile.ExpectedMatchCount := AExpectedMatchCount;
  AProfile.IsArchive2022 := False;
  AProfile.SupportsPlayerStats := ASeason.SupportsPlayerStats;
  AProfile.RegularSeasonRoundsOnly := True;
end;

function TryGetCompetitionProfile(const ACompetitionName,
  ASeasonCaption: string; out AProfile: TCompetitionProfile): Boolean;
var
  Season: TSeasonProfile;
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
      AProfile.SeasonKind := skArchive;
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
      AProfile.SeasonKind := skCurrent;
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

  if not TryGetLeagueSeasonProfile(ASeasonCaption, Season) then
    Exit(False);

  if SameText(ACompetitionName, PremierLeagueName) then
    ConfigureLeagueProfile(AProfile, 'premier_league', PremierLeagueName,
      'england', 'premier-league', 'PremierLeague', 380, Season)
  else if SameText(ACompetitionName, LaLigaName) then
    ConfigureLeagueProfile(AProfile, 'la_liga', LaLigaName,
      'spain', 'laliga', 'LaLiga', 380, Season)
  else if SameText(ACompetitionName, BundesligaName) then
    ConfigureLeagueProfile(AProfile, 'bundesliga', BundesligaName,
      'germany', 'bundesliga', 'Bundesliga', 306, Season)
  else if SameText(ACompetitionName, SerieAName) then
    ConfigureLeagueProfile(AProfile, 'serie_a', SerieAName,
      'italy', 'serie-a', 'SerieA', 380, Season)
  else if SameText(ACompetitionName, Ligue1Name) then
    ConfigureLeagueProfile(AProfile, 'ligue_1', Ligue1Name,
      'france', 'ligue-1', 'Ligue1', 306, Season)
  else
    Result := False;
end;

end.
