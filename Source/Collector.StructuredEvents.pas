unit Collector.StructuredEvents;

interface

uses
  System.JSON;

procedure EnrichStructuredEvents(const AAggregate: TJSONObject);

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.Math,
  System.Character,
  System.Generics.Collections,
  Collector.Json;

type
  TRosterPlayer = record
    TeamSide: string;
    TeamName: string;
    PlayerName: string;
    ShirtNumber: Integer;
  end;

  TResolvedPlayer = record
    Found: Boolean;
    Ambiguous: Boolean;
    MatchScore: Integer;
    Player: TRosterPlayer;
  end;

function FoldLatinCharacter(const ACharacter: Char): Char;
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

function NormalizeWords(const AValue: string): string;
var
  CharacterValue: Char;
  LastWasSpace: Boolean;
begin
  Result := '';
  LastWasSpace := True;

  for CharacterValue in LowerCase(AValue) do
  begin
    if CharacterValue.IsLetterOrDigit then
    begin
      Result := Result + FoldLatinCharacter(CharacterValue);
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

function NormalizeKey(const AValue: string): string;
var
  CharacterValue: Char;
begin
  Result := '';

  for CharacterValue in LowerCase(AValue) do
    if CharacterValue.IsLetterOrDigit then
      Result := Result + FoldLatinCharacter(CharacterValue);
end;

function SplitWords(const AValue: string): TArray<string>;
var
  Normalized: string;
begin
  Normalized := NormalizeWords(AValue);

  if Normalized = '' then
    Exit(nil);

  Result := Normalized.Split(
    [' '],
    TStringSplitOptions.ExcludeEmpty
  );
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

procedure SetNullableStringMember(const AObject: TJSONObject;
  const AName: string; const AValue: string);
begin
  if AValue = '' then
    SetNullMember(AObject, AName)
  else
    SetStringMember(AObject, AName, AValue);
end;

function CloneJsonValue(const AValue: TJSONValue): TJSONValue;
begin
  Result := nil;

  if AValue <> nil then
    Result := TJSONObject.ParseJSONValue(AValue.ToJSON);
end;

function LastTextPosition(const ASubText: string;
  const AText: string): Integer;
var
  SearchFrom: Integer;
  FoundAt: Integer;
begin
  Result := 0;
  SearchFrom := 1;

  repeat
    FoundAt := PosEx(
      LowerCase(ASubText),
      LowerCase(AText),
      SearchFrom
    );

    if FoundAt > 0 then
    begin
      Result := FoundAt;
      SearchFrom := FoundAt + 1;
    end;
  until FoundAt = 0;
end;

function TokenSequencePosition(
  const AEventWords: TArray<string>;
  const ASequence: TArray<string>): Integer;
var
  EventIndex: Integer;
  SequenceIndex: Integer;
  Matches: Boolean;
begin
  Result := -1;

  if (Length(AEventWords) = 0) or
     (Length(ASequence) = 0) or
     (Length(ASequence) > Length(AEventWords)) then
    Exit;

  for EventIndex := 0 to
    Length(AEventWords) - Length(ASequence) do
  begin
    Matches := True;

    for SequenceIndex := 0 to
      Length(ASequence) - 1 do
      if not SameText(
        AEventWords[EventIndex + SequenceIndex],
        ASequence[SequenceIndex]
      ) then
      begin
        Matches := False;
        Break;
      end;

    if Matches then
      Result := EventIndex;
  end;
end;

function NameMatchScore(const APlayerName: string;
  const AEventText: string;
  const APreferLastOccurrence: Boolean): Integer;
var
  RosterWords: TArray<string>;
  EventWords: TArray<string>;
  SurnameWords: TArray<string>;
  InitialWords: TArray<string>;
  InitialIndex: Integer;
  WordIndex: Integer;
  SequencePosition: Integer;
  InitialCount: Integer;
  EventInitialIndex: Integer;
  Score: Integer;
  MaxPosition: Integer;
  FoundPosition: Integer;
begin
  Result := 0;
  RosterWords := SplitWords(APlayerName);
  EventWords := SplitWords(AEventText);

  if (Length(RosterWords) = 0) or
     (Length(EventWords) = 0) then
    Exit;

  InitialIndex := Length(RosterWords);

  for WordIndex := 0 to Length(RosterWords) - 1 do
    if Length(RosterWords[WordIndex]) = 1 then
    begin
      InitialIndex := WordIndex;
      Break;
    end;

  if InitialIndex < Length(RosterWords) then
  begin
    SetLength(SurnameWords, InitialIndex);

    for WordIndex := 0 to InitialIndex - 1 do
      SurnameWords[WordIndex] := RosterWords[WordIndex];

    InitialCount := Length(RosterWords) - InitialIndex;
    SetLength(InitialWords, InitialCount);

    for WordIndex := 0 to InitialCount - 1 do
      InitialWords[WordIndex] :=
        RosterWords[InitialIndex + WordIndex];

    SequencePosition := TokenSequencePosition(
      EventWords,
      SurnameWords
    );

    if SequencePosition < 0 then
      Exit;

    Score := 100 + Length(SurnameWords) * 10;

    for WordIndex := 0 to InitialCount - 1 do
    begin
      EventInitialIndex :=
        SequencePosition - InitialCount + WordIndex;

      if (EventInitialIndex >= 0) and
         (EventInitialIndex < Length(EventWords)) and
         (EventWords[EventInitialIndex] <> '') and
         SameText(
           Copy(EventWords[EventInitialIndex], 1, 1),
           InitialWords[WordIndex]
         ) then
        Inc(Score, 20);
    end;

    if APreferLastOccurrence then
      Inc(Score, SequencePosition);

    Exit(Score);
  end;

  MaxPosition := -1;

  for WordIndex := 0 to Length(RosterWords) - 1 do
  begin
    FoundPosition := -1;

    for EventInitialIndex := 0 to
      Length(EventWords) - 1 do
      if SameText(
        EventWords[EventInitialIndex],
        RosterWords[WordIndex]
      ) then
        FoundPosition := EventInitialIndex;

    if FoundPosition < 0 then
      Exit;

    MaxPosition := Max(MaxPosition, FoundPosition);
  end;

  Score := 120 + Length(RosterWords) * 15;

  if APreferLastOccurrence then
    Inc(Score, MaxPosition);

  Result := Score;
end;

procedure BuildRoster(const AAggregate: TJSONObject;
  const ARoster: TList<TRosterPlayer>);
var
  Lineups: TJSONObject;

  procedure AddArray(const ASide: string;
    const ATeamName: string;
    const AArrayName: string);
  var
    TeamLineup: TJSONObject;
    RosterArray: TJSONArray;
    RosterIndex: Integer;
    RosterValue: TJSONValue;
    RosterObject: TJSONObject;
    Player: TRosterPlayer;
  begin
    TeamLineup := JsonObjectMember(Lineups, ASide);

    if TeamLineup = nil then
      Exit;

    RosterArray := JsonArrayMember(
      TeamLineup,
      AArrayName
    );

    if RosterArray = nil then
      Exit;

    for RosterIndex := 0 to RosterArray.Count - 1 do
    begin
      RosterValue := RosterArray.Items[RosterIndex];

      if not (RosterValue is TJSONObject) then
        Continue;

      RosterObject := TJSONObject(RosterValue);
      Player.TeamSide := ASide;
      Player.TeamName := ATeamName;
      Player.PlayerName := JsonStringValue(
        RosterObject,
        'name'
      );
      Player.ShirtNumber := JsonIntegerValue(
        RosterObject,
        'number',
        0
      );

      if Player.PlayerName <> '' then
        ARoster.Add(Player);
    end;
  end;

var
  HomeTeam: string;
  AwayTeam: string;
begin
  Lineups := JsonObjectMember(AAggregate, 'lineups');

  if Lineups = nil then
    raise EJSONException.Create(
      'Lineups are required for structured event enrichment.'
    );

  HomeTeam := JsonStringValue(
    AAggregate,
    'home_team'
  );
  AwayTeam := JsonStringValue(
    AAggregate,
    'away_team'
  );

  AddArray('home', HomeTeam, 'starting');
  AddArray('home', HomeTeam, 'substitutes');
  AddArray('away', AwayTeam, 'starting');
  AddArray('away', AwayTeam, 'substitutes');
end;

function DetectEventTeamSide(const AAggregate: TJSONObject;
  const AEventText: string;
  out ATeamSide: string;
  out ATeamName: string;
  out ATeamMarkerPosition: Integer): Boolean;
var
  HomeTeam: string;
  AwayTeam: string;
  Marker: string;
begin
  Result := False;
  ATeamSide := '';
  ATeamName := '';
  ATeamMarkerPosition := 0;

  HomeTeam := JsonStringValue(
    AAggregate,
    'home_team'
  );
  AwayTeam := JsonStringValue(
    AAggregate,
    'away_team'
  );

  Marker := '(' + HomeTeam + ')';
  ATeamMarkerPosition := LastTextPosition(
    Marker,
    AEventText
  );

  if ATeamMarkerPosition > 0 then
  begin
    ATeamSide := 'home';
    ATeamName := HomeTeam;
    Exit(True);
  end;

  Marker := '(' + AwayTeam + ')';
  ATeamMarkerPosition := LastTextPosition(
    Marker,
    AEventText
  );

  if ATeamMarkerPosition > 0 then
  begin
    ATeamSide := 'away';
    ATeamName := AwayTeam;
    Exit(True);
  end;

  if ContainsText(AEventText, HomeTeam) then
  begin
    ATeamSide := 'home';
    ATeamName := HomeTeam;
    ATeamMarkerPosition := Length(AEventText) + 1;
    Exit(True);
  end;

  if ContainsText(AEventText, AwayTeam) then
  begin
    ATeamSide := 'away';
    ATeamName := AwayTeam;
    ATeamMarkerPosition := Length(AEventText) + 1;
    Exit(True);
  end;
end;

function ResolveActor(const AAggregate: TJSONObject;
  const ARoster: TList<TRosterPlayer>;
  const AEventText: string;
  const AExcludePlayerKey: string = '';
  const AForcedTeamSide: string = ''): TResolvedPlayer;
var
  TeamSide: string;
  TeamName: string;
  MarkerPosition: Integer;
  SearchText: string;
  RosterIndex: Integer;
  Candidate: TRosterPlayer;
  CandidateScore: Integer;
  BestScore: Integer;
  BestCount: Integer;
begin
  Result.Found := False;
  Result.Ambiguous := False;
  Result.MatchScore := 0;
  BestScore := 0;
  BestCount := 0;

  DetectEventTeamSide(
    AAggregate,
    AEventText,
    TeamSide,
    TeamName,
    MarkerPosition
  );

  if AForcedTeamSide <> '' then
  begin
    TeamSide := AForcedTeamSide;

    if SameText(TeamSide, 'home') then
      TeamName := JsonStringValue(
        AAggregate,
        'home_team'
      )
    else
      TeamName := JsonStringValue(
        AAggregate,
        'away_team'
      );

    MarkerPosition := LastTextPosition(
      '(' + TeamName + ')',
      AEventText
    );

    if MarkerPosition = 0 then
      MarkerPosition := Length(AEventText) + 1;
  end;

  if MarkerPosition > 1 then
    SearchText := Copy(
      AEventText,
      1,
      MarkerPosition - 1
    )
  else
    SearchText := AEventText;

  for RosterIndex := 0 to ARoster.Count - 1 do
  begin
    Candidate := ARoster[RosterIndex];

    if (TeamSide <> '') and
       not SameText(Candidate.TeamSide, TeamSide) then
      Continue;

    if (AExcludePlayerKey <> '') and
       SameText(
         NormalizeKey(Candidate.PlayerName),
         AExcludePlayerKey
       ) then
      Continue;

    CandidateScore := NameMatchScore(
      Candidate.PlayerName,
      SearchText,
      True
    );

    if CandidateScore <= 0 then
      Continue;

    if CandidateScore > BestScore then
    begin
      BestScore := CandidateScore;
      BestCount := 1;
      Result.Player := Candidate;
    end
    else if CandidateScore = BestScore then
      Inc(BestCount);
  end;

  Result.MatchScore := BestScore;
  Result.Ambiguous := BestCount > 1;
  Result.Found := (BestScore > 0) and not Result.Ambiguous;
end;

function ResolveAssist(const ARoster: TList<TRosterPlayer>;
  const AEventText: string;
  const AScorer: TRosterPlayer): TResolvedPlayer;
var
  RosterIndex: Integer;
  Candidate: TRosterPlayer;
  CandidateScore: Integer;
  BestScore: Integer;
  BestCount: Integer;
  ScorerKey: string;
begin
  Result.Found := False;
  Result.Ambiguous := False;
  Result.MatchScore := 0;
  BestScore := 0;
  BestCount := 0;
  ScorerKey := NormalizeKey(AScorer.PlayerName);

  for RosterIndex := 0 to ARoster.Count - 1 do
  begin
    Candidate := ARoster[RosterIndex];

    if not SameText(
      Candidate.TeamSide,
      AScorer.TeamSide
    ) then
      Continue;

    if SameText(
      NormalizeKey(Candidate.PlayerName),
      ScorerKey
    ) then
      Continue;

    CandidateScore := NameMatchScore(
      Candidate.PlayerName,
      AEventText,
      False
    );

    if CandidateScore <= 0 then
      Continue;

    if CandidateScore > BestScore then
    begin
      BestScore := CandidateScore;
      BestCount := 1;
      Result.Player := Candidate;
    end
    else if CandidateScore = BestScore then
      Inc(BestCount);
  end;

  Result.MatchScore := BestScore;
  Result.Ambiguous := BestCount > 1;
  Result.Found := (BestScore > 0) and not Result.Ambiguous;
end;

function EventMinute(const AEvent: TJSONObject): Integer;
begin
  Result :=
    JsonIntegerValue(AEvent, 'minute', 0) +
    JsonIntegerValue(AEvent, 'added_time', 0);
end;

function EventMinuteRaw(const AEvent: TJSONObject): string;
var
  MinuteValue: Integer;
  AddedTime: Integer;
begin
  MinuteValue := JsonIntegerValue(
    AEvent,
    'minute',
    0
  );
  AddedTime := JsonIntegerValue(
    AEvent,
    'added_time',
    0
  );

  if AddedTime > 0 then
    Result := Format(
      '%d+%d',
      [MinuteValue, AddedTime]
    )
  else
    Result := IntToStr(MinuteValue);
end;

function OppositeSide(const ASide: string): string;
begin
  if SameText(ASide, 'home') then
    Result := 'away'
  else if SameText(ASide, 'away') then
    Result := 'home'
  else
    Result := '';
end;

function TeamNameForSide(const AAggregate: TJSONObject;
  const ASide: string): string;
begin
  if SameText(ASide, 'home') then
    Result := JsonStringValue(
      AAggregate,
      'home_team'
    )
  else if SameText(ASide, 'away') then
    Result := JsonStringValue(
      AAggregate,
      'away_team'
    )
  else
    Result := '';
end;

function ArrayContainsText(const AArray: TJSONArray;
  const AText: string): Boolean;
var
  Index: Integer;
begin
  Result := False;

  if AArray = nil then
    Exit;

  for Index := 0 to AArray.Count - 1 do
    if SameText(
      AArray.Items[Index].Value,
      AText
    ) then
      Exit(True);
end;

function ContainsVarReference(const AText: string): Boolean;
var
  NormalizedText: string;
begin
  NormalizedText := ' ' + NormalizeWords(AText) + ' ';

  Result :=
    (Pos(' var ', NormalizedText) > 0) or
    ContainsText(AText, 'video assistant referee');
end;

function IsVarEvent(const AEvent: TJSONObject): Boolean;
var
  Tags: TJSONArray;
begin
  Tags := JsonArrayMember(AEvent, 'tags');

  Result :=
    ArrayContainsText(Tags, 'var') or
    ContainsVarReference(
      JsonStringValue(AEvent, 'text')
    );
end;

function DetectGoalType(const AText: string;
  out AIsPenalty: Boolean;
  out AIsOwnGoal: Boolean;
  out AIsHeader: Boolean): string;
var
  LowerText: string;
begin
  LowerText := LowerCase(AText);

  AIsPenalty := Pos('penalty', LowerText) > 0;
  AIsOwnGoal :=
    (Pos('own goal', LowerText) > 0) or
    (Pos('own goalkeeper', LowerText) > 0) or
    (
      (Pos('unintentionally', LowerText) > 0) and
      (Pos('own', LowerText) > 0)
    );
  AIsHeader :=
    (Pos('header', LowerText) > 0) or
    (Pos('heads ', LowerText) > 0) or
    (Pos('headed ', LowerText) > 0);

  if AIsOwnGoal then
    Result := 'own_goal'
  else if AIsPenalty then
    Result := 'penalty'
  else if AIsHeader then
    Result := 'header'
  else
    Result := 'regular';
end;

function DetectVarReason(const AText: string): string;
var
  LowerText: string;
begin
  LowerText := LowerCase(AText);

  if Pos('red card', LowerText) > 0 then
    Result := 'red_card'
  else if Pos('penalty', LowerText) > 0 then
    Result := 'penalty'
  else if Pos('offside', LowerText) > 0 then
    Result := 'offside'
  else if Pos('yellow card', LowerText) > 0 then
    Result := 'yellow_card'
  else if Pos('goal', LowerText) > 0 then
    Result := 'goal'
  else
    Result := 'unknown';
end;

function DetectVarDecision(const AText: string): string;
var
  LowerText: string;
begin
  LowerText := LowerCase(AText);

  // A review-start message can also contain words such as "penalty" or
  // "red card". Detect the start of the review before final decisions.
  if (Pos('going to review', LowerText) > 0) or
     (Pos('review using var', LowerText) > 0) or
     (Pos('makes the var signal', LowerText) > 0) or
     (Pos('going to review that incident', LowerText) > 0) then
    Exit('review_started');

  if (Pos('no goal', LowerText) > 0) or
     (Pos('won''t count', LowerText) > 0) or
     (Pos('disallowed', LowerText) > 0) then
    Exit('no_goal');

  if Pos('no action', LowerText) > 0 then
    Exit('no_action');

  if (Pos('red card', LowerText) > 0) and
     (
       (Pos('decision', LowerText) > 0) or
       (Pos('produces', LowerText) > 0)
     ) then
    Exit('red_card');

  if (Pos('penalty', LowerText) > 0) and
     (
       (Pos('original decision', LowerText) > 0) or
       (Pos('it''s a penalty', LowerText) > 0) or
       (Pos('it’s a penalty', LowerText) > 0)
     ) then
    Exit('penalty');

  Result := 'review_completed';
end;

procedure AddUnmatchedEvent(const AArray: TJSONArray;
  const AEventType: string;
  const AReason: string;
  const AEvent: TJSONObject);
var
  Item: TJSONObject;
begin
  Item := TJSONObject.Create;
  Item.AddPair('event_type', AEventType);
  Item.AddPair('reason', AReason);
  Item.AddPair(
    'minute',
    TJSONNumber.Create(EventMinute(AEvent))
  );
  Item.AddPair('minute_raw', EventMinuteRaw(AEvent));
  Item.AddPair(
    'text',
    JsonStringValue(AEvent, 'text')
  );
  AArray.AddElement(Item);
end;

procedure EnrichStructuredEvents(const AAggregate: TJSONObject);
var
  Events: TJSONObject;
  Roster: TList<TRosterPlayer>;
  UnmatchedEvents: TJSONArray;
  Validation: TJSONObject;
  GoalEvents: TJSONArray;
  YellowCardEvents: TJSONArray;
  RedCardEvents: TJSONArray;
  OverturnedEvents: TJSONArray;
  VarEvents: TJSONArray;
  VarObjects: TList<TJSONObject>;
  EventValue: TJSONValue;
  EventObject: TJSONObject;
  OtherObject: TJSONObject;
  EventText: string;
  ResolvedPlayer: TResolvedPlayer;
  ResolvedAssist: TResolvedPlayer;
  CreditedSide: string;
  CreditedTeam: string;
  GoalType: string;
  IsPenalty: Boolean;
  IsOwnGoal: Boolean;
  IsHeader: Boolean;
  ScoreValue: TJSONValue;
  ScoreCopy: TJSONValue;
  CardType: string;
  VarReason: string;
  VarDecision: string;
  OtherDecision: string;
  EventSide: string;
  EventTeam: string;
  MarkerPosition: Integer;
  BestRelatedMinute: Integer;
  BestRelatedDifference: Integer;
  Difference: Integer;
  RelatedFound: Boolean;
  GoalEventCount: Integer;
  StructuredGoalCount: Integer;
  UnmatchedGoalScorerCount: Integer;
  AssistPlayerCount: Integer;
  OwnGoalCount: Integer;
  PenaltyGoalCount: Integer;
  HeaderGoalCount: Integer;
  YellowCardEventCount: Integer;
  StructuredYellowCardCount: Integer;
  RedCardEventCount: Integer;
  StructuredRedCardCount: Integer;
  OverturnedCardEventCount: Integer;
  StructuredOverturnedCardCount: Integer;
  VarEventCount: Integer;
  StructuredVarEventCount: Integer;
  VarPlayerResolvedCount: Integer;
  VarLinkedEventCount: Integer;
  OverturnedCardLinkedCount: Integer;
  UnlinkedVarEventCount: Integer;
  UnlinkedOverturnedCardCount: Integer;
  InvalidVarDecisionFlagCount: Integer;
  CriticalErrorCount: Integer;
  WarningCount: Integer;
  ExistingPair: TJSONPair;

  procedure EnrichGoalArray;
  var
    EventIndex: Integer;
    EventIsVarDecision: Boolean;
  begin
    if GoalEvents = nil then
      Exit;

    GoalEventCount := GoalEvents.Count;

    for EventIndex := 0 to GoalEvents.Count - 1 do
    begin
      EventValue := GoalEvents.Items[EventIndex];

      if not (EventValue is TJSONObject) then
        Continue;

      EventObject := TJSONObject(EventValue);
      EventText := JsonStringValue(
        EventObject,
        'text'
      );
      ResolvedPlayer := ResolveActor(
        AAggregate,
        Roster,
        EventText
      );

      if not ResolvedPlayer.Found then
      begin
        Inc(UnmatchedGoalScorerCount);

        if ResolvedPlayer.Ambiguous then
          AddUnmatchedEvent(
            UnmatchedEvents,
            'goal',
            'ambiguous_scorer',
            EventObject
          )
        else
          AddUnmatchedEvent(
            UnmatchedEvents,
            'goal',
            'scorer_not_found',
            EventObject
          );

        Continue;
      end;

      GoalType := DetectGoalType(
        EventText,
        IsPenalty,
        IsOwnGoal,
        IsHeader
      );

      if IsOwnGoal then
      begin
        CreditedSide := OppositeSide(
          ResolvedPlayer.Player.TeamSide
        );
        Inc(OwnGoalCount);
      end
      else
        CreditedSide :=
          ResolvedPlayer.Player.TeamSide;

      CreditedTeam := TeamNameForSide(
        AAggregate,
        CreditedSide
      );

      if IsPenalty then
        Inc(PenaltyGoalCount);

      if IsHeader then
        Inc(HeaderGoalCount);

      SetStringMember(
        EventObject,
        'team_side',
        CreditedSide
      );
      SetStringMember(
        EventObject,
        'team',
        CreditedTeam
      );
      SetStringMember(
        EventObject,
        'player_team_side',
        ResolvedPlayer.Player.TeamSide
      );
      SetStringMember(
        EventObject,
        'player_team',
        ResolvedPlayer.Player.TeamName
      );
      SetStringMember(
        EventObject,
        'player',
        ResolvedPlayer.Player.PlayerName
      );
      SetIntegerMember(
        EventObject,
        'shirt_number',
        ResolvedPlayer.Player.ShirtNumber
      );
      SetIntegerMember(
        EventObject,
        'player_match_score',
        ResolvedPlayer.MatchScore
      );
      SetStringMember(
        EventObject,
        'goal_type',
        GoalType
      );
      SetBooleanMember(
        EventObject,
        'is_penalty',
        IsPenalty
      );
      SetBooleanMember(
        EventObject,
        'is_own_goal',
        IsOwnGoal
      );
      SetBooleanMember(
        EventObject,
        'is_header',
        IsHeader
      );
      SetBooleanMember(
        EventObject,
        'is_deflected',
        ContainsText(EventText, 'deflect')
      );
      EventIsVarDecision := IsVarEvent(EventObject);
      SetBooleanMember(
        EventObject,
        'is_var_decision',
        EventIsVarDecision
      );

      if EventIsVarDecision and
         not ArrayContainsText(
           JsonArrayMember(EventObject, 'tags'),
           'var'
         ) then
        Inc(InvalidVarDecisionFlagCount);

      ScoreValue := EventObject.GetValue('score');
      ScoreCopy := CloneJsonValue(ScoreValue);
      RemoveMember(EventObject, 'score_after');

      if ScoreCopy <> nil then
        EventObject.AddPair('score_after', ScoreCopy)
      else
        EventObject.AddPair(
          'score_after',
          TJSONNull.Create
        );

      if not IsOwnGoal and not IsPenalty then
        ResolvedAssist := ResolveAssist(
          Roster,
          EventText,
          ResolvedPlayer.Player
        )
      else
      begin
        ResolvedAssist.Found := False;
        ResolvedAssist.Ambiguous := False;
        ResolvedAssist.MatchScore := 0;
      end;

      if ResolvedAssist.Found then
      begin
        SetStringMember(
          EventObject,
          'assist_player',
          ResolvedAssist.Player.PlayerName
        );
        SetIntegerMember(
          EventObject,
          'assist_shirt_number',
          ResolvedAssist.Player.ShirtNumber
        );
        SetIntegerMember(
          EventObject,
          'assist_match_score',
          ResolvedAssist.MatchScore
        );
        Inc(AssistPlayerCount);
      end
      else
      begin
        SetNullMember(
          EventObject,
          'assist_player'
        );
        SetNullMember(
          EventObject,
          'assist_shirt_number'
        );
        SetNullMember(
          EventObject,
          'assist_match_score'
        );
      end;

      Inc(StructuredGoalCount);
    end;
  end;

  procedure EnrichCardArray(const AArray: TJSONArray;
    const ACardType: string;
    const AIsOverturned: Boolean;
    var AEventCount: Integer;
    var AStructuredCount: Integer);
  var
    EventIndex: Integer;
    EventIsVarDecision: Boolean;
  begin
    if AArray = nil then
      Exit;

    AEventCount := 0;

    for EventIndex := 0 to AArray.Count - 1 do
    begin
      EventValue := AArray.Items[EventIndex];

      if not (EventValue is TJSONObject) then
        Continue;

      EventObject := TJSONObject(EventValue);
      EventText := JsonStringValue(
        EventObject,
        'text'
      );
      CardType := ACardType;

      if CardType = '' then
      begin
        if ContainsText(EventText, 'red card') then
          CardType := 'red'
        else if ContainsText(EventText, 'yellow card') then
          CardType := 'yellow'
        else
          Continue;
      end;

      Inc(AEventCount);

      ResolvedPlayer := ResolveActor(
        AAggregate,
        Roster,
        EventText
      );

      if not ResolvedPlayer.Found then
      begin
        if ResolvedPlayer.Ambiguous then
          AddUnmatchedEvent(
            UnmatchedEvents,
            CardType + '_card',
            'ambiguous_card_player',
            EventObject
          )
        else
          AddUnmatchedEvent(
            UnmatchedEvents,
            CardType + '_card',
            'card_player_not_found',
            EventObject
          );

        Continue;
      end;

      SetStringMember(
        EventObject,
        'team_side',
        ResolvedPlayer.Player.TeamSide
      );
      SetStringMember(
        EventObject,
        'team',
        ResolvedPlayer.Player.TeamName
      );
      SetStringMember(
        EventObject,
        'player',
        ResolvedPlayer.Player.PlayerName
      );
      SetIntegerMember(
        EventObject,
        'shirt_number',
        ResolvedPlayer.Player.ShirtNumber
      );
      SetIntegerMember(
        EventObject,
        'player_match_score',
        ResolvedPlayer.MatchScore
      );
      SetStringMember(
        EventObject,
        'card_type',
        CardType
      );
      EventIsVarDecision := IsVarEvent(EventObject);
      SetBooleanMember(
        EventObject,
        'is_var_decision',
        EventIsVarDecision
      );

      if EventIsVarDecision and
         not ArrayContainsText(
           JsonArrayMember(EventObject, 'tags'),
           'var'
         ) then
        Inc(InvalidVarDecisionFlagCount);
      SetBooleanMember(
        EventObject,
        'is_overturned',
        AIsOverturned or
        SameText(
          JsonStringValue(EventObject, 'status'),
          'overturned'
        )
      );

      Inc(AStructuredCount);
    end;
  end;

  procedure EnrichVarArray;
  var
    EventIndex: Integer;
    OtherIndex: Integer;
    CardIndex: Integer;
    CardValue: TJSONValue;
    CardObject: TJSONObject;
    CardPlayer: string;
    VarPlayer: string;
    BestVarObject: TJSONObject;
    RelatedValue: TJSONValue;
  begin
    if VarEvents = nil then
      Exit;

    VarEventCount := VarEvents.Count;

    for EventIndex := 0 to VarEvents.Count - 1 do
    begin
      EventValue := VarEvents.Items[EventIndex];

      if not (EventValue is TJSONObject) then
        Continue;

      EventObject := TJSONObject(EventValue);
      EventText := JsonStringValue(
        EventObject,
        'text'
      );
      VarReason := DetectVarReason(EventText);
      VarDecision := DetectVarDecision(EventText);

      SetStringMember(
        EventObject,
        'review_reason',
        VarReason
      );
      SetStringMember(
        EventObject,
        'decision',
        VarDecision
      );

      if DetectEventTeamSide(
        AAggregate,
        EventText,
        EventSide,
        EventTeam,
        MarkerPosition
      ) then
      begin
        SetStringMember(
          EventObject,
          'team_side',
          EventSide
        );
        SetStringMember(
          EventObject,
          'team',
          EventTeam
        );
      end
      else
      begin
        SetNullMember(
          EventObject,
          'team_side'
        );
        SetNullMember(
          EventObject,
          'team'
        );
      end;

      ResolvedPlayer := ResolveActor(
        AAggregate,
        Roster,
        EventText
      );

      if ResolvedPlayer.Found then
      begin
        SetStringMember(
          EventObject,
          'player',
          ResolvedPlayer.Player.PlayerName
        );
        SetIntegerMember(
          EventObject,
          'shirt_number',
          ResolvedPlayer.Player.ShirtNumber
        );
        SetIntegerMember(
          EventObject,
          'player_match_score',
          ResolvedPlayer.MatchScore
        );
        Inc(VarPlayerResolvedCount);
      end
      else
      begin
        SetNullMember(
          EventObject,
          'player'
        );
        SetNullMember(
          EventObject,
          'shirt_number'
        );
        SetNullMember(
          EventObject,
          'player_match_score'
        );
      end;

      SetBooleanMember(
        EventObject,
        'is_var_event',
        True
      );
      VarObjects.Add(EventObject);
      Inc(StructuredVarEventCount);
    end;

    for EventIndex := 0 to VarObjects.Count - 1 do
    begin
      EventObject := VarObjects[EventIndex];
      VarDecision := JsonStringValue(
        EventObject,
        'decision'
      );
      EventSide := JsonStringValue(
        EventObject,
        'team_side'
      );
      BestRelatedDifference := MaxInt;
      BestRelatedMinute := 0;
      RelatedFound := False;

      for OtherIndex := 0 to VarObjects.Count - 1 do
      begin
        if OtherIndex = EventIndex then
          Continue;

        OtherObject := VarObjects[OtherIndex];
        OtherDecision := JsonStringValue(
          OtherObject,
          'decision'
        );

        if SameText(VarDecision, 'review_started') then
        begin
          if SameText(
            OtherDecision,
            'review_started'
          ) then
            Continue;
        end
        else if not SameText(
          OtherDecision,
          'review_started'
        ) then
          Continue;

        if (EventSide <> '') and
           (JsonStringValue(
             OtherObject,
             'team_side'
           ) <> '') and
           not SameText(
             EventSide,
             JsonStringValue(
               OtherObject,
               'team_side'
             )
           ) then
          Continue;

        Difference := Abs(
          EventMinute(EventObject) -
          EventMinute(OtherObject)
        );

        if (Difference <= 5) and
           (Difference < BestRelatedDifference) then
        begin
          BestRelatedDifference := Difference;
          BestRelatedMinute := EventMinute(OtherObject);
          RelatedFound := True;
        end;
      end;

      if RelatedFound then
      begin
        SetIntegerMember(
          EventObject,
          'related_event_minute',
          BestRelatedMinute
        );
        Inc(VarLinkedEventCount);
      end
      else
        SetNullMember(
          EventObject,
          'related_event_minute'
        );
    end;

    // Link overturned cards to the nearest final VAR decision for the same
    // player. If the VAR event is not already linked to a review-start
    // event, make the relationship reciprocal.
    if OverturnedEvents <> nil then
      for CardIndex := 0 to OverturnedEvents.Count - 1 do
      begin
        CardValue := OverturnedEvents.Items[CardIndex];

        if not (CardValue is TJSONObject) then
          Continue;

        CardObject := TJSONObject(CardValue);
        CardPlayer := JsonStringValue(CardObject, 'player');
        BestRelatedDifference := MaxInt;
        BestVarObject := nil;

        for EventIndex := 0 to VarObjects.Count - 1 do
        begin
          EventObject := VarObjects[EventIndex];
          VarDecision := JsonStringValue(EventObject, 'decision');

          if SameText(VarDecision, 'review_started') then
            Continue;

          VarPlayer := JsonStringValue(EventObject, 'player');

          if (CardPlayer = '') or
             (VarPlayer = '') or
             not SameText(CardPlayer, VarPlayer) then
            Continue;

          Difference := Abs(
            EventMinute(CardObject) -
            EventMinute(EventObject)
          );

          if (Difference <= 5) and
             (Difference < BestRelatedDifference) then
          begin
            BestRelatedDifference := Difference;
            BestVarObject := EventObject;
          end;
        end;

        if BestVarObject = nil then
        begin
          SetNullMember(
            CardObject,
            'related_event_minute'
          );
          Continue;
        end;

        SetIntegerMember(
          CardObject,
          'related_event_minute',
          EventMinute(BestVarObject)
        );
        Inc(OverturnedCardLinkedCount);

        RelatedValue := BestVarObject.GetValue(
          'related_event_minute'
        );

        if (RelatedValue = nil) or
           (RelatedValue is TJSONNull) then
        begin
          SetIntegerMember(
            BestVarObject,
            'related_event_minute',
            EventMinute(CardObject)
          );
          Inc(VarLinkedEventCount);
        end
        else
          SetIntegerMember(
            BestVarObject,
            'related_overturned_card_minute',
            EventMinute(CardObject)
          );
      end;
  end;

begin
  if AAggregate = nil then
    raise EJSONException.Create(
      'Aggregate JSON is required for structured events.'
    );

  Events := JsonObjectMember(AAggregate, 'events');

  if Events = nil then
    raise EJSONException.Create(
      'Events object is required for structured event enrichment.'
    );

  Roster := TList<TRosterPlayer>.Create;
  UnmatchedEvents := TJSONArray.Create;
  Validation := nil;
  VarObjects := TList<TJSONObject>.Create;

  GoalEventCount := 0;
  StructuredGoalCount := 0;
  UnmatchedGoalScorerCount := 0;
  AssistPlayerCount := 0;
  OwnGoalCount := 0;
  PenaltyGoalCount := 0;
  HeaderGoalCount := 0;
  YellowCardEventCount := 0;
  StructuredYellowCardCount := 0;
  RedCardEventCount := 0;
  StructuredRedCardCount := 0;
  OverturnedCardEventCount := 0;
  StructuredOverturnedCardCount := 0;
  VarEventCount := 0;
  StructuredVarEventCount := 0;
  VarPlayerResolvedCount := 0;
  VarLinkedEventCount := 0;
  OverturnedCardLinkedCount := 0;
  InvalidVarDecisionFlagCount := 0;
  CriticalErrorCount := 0;
  WarningCount := 0;

  try
    BuildRoster(AAggregate, Roster);

    GoalEvents := JsonArrayMember(Events, 'goals');
    YellowCardEvents := JsonArrayMember(
      Events,
      'yellow_cards'
    );
    RedCardEvents := JsonArrayMember(
      Events,
      'red_cards'
    );
    OverturnedEvents := JsonArrayMember(
      Events,
      'overturned'
    );
    VarEvents := JsonArrayMember(Events, 'var');

    EnrichGoalArray;
    EnrichCardArray(
      YellowCardEvents,
      'yellow',
      False,
      YellowCardEventCount,
      StructuredYellowCardCount
    );
    EnrichCardArray(
      RedCardEvents,
      'red',
      False,
      RedCardEventCount,
      StructuredRedCardCount
    );
    EnrichCardArray(
      OverturnedEvents,
      '',
      True,
      OverturnedCardEventCount,
      StructuredOverturnedCardCount
    );
    EnrichVarArray;

    UnlinkedVarEventCount := Max(
      0,
      VarEventCount - VarLinkedEventCount
    );
    UnlinkedOverturnedCardCount := Max(
      0,
      OverturnedCardEventCount -
      OverturnedCardLinkedCount
    );

    Validation := TJSONObject.Create;
    Validation.AddPair(
      'goal_event_count',
      TJSONNumber.Create(GoalEventCount)
    );
    Validation.AddPair(
      'structured_goal_count',
      TJSONNumber.Create(StructuredGoalCount)
    );
    Validation.AddPair(
      'unmatched_goal_scorer_count',
      TJSONNumber.Create(UnmatchedGoalScorerCount)
    );
    Validation.AddPair(
      'assist_player_count',
      TJSONNumber.Create(AssistPlayerCount)
    );
    Validation.AddPair(
      'own_goal_count',
      TJSONNumber.Create(OwnGoalCount)
    );
    Validation.AddPair(
      'penalty_goal_count',
      TJSONNumber.Create(PenaltyGoalCount)
    );
    Validation.AddPair(
      'header_goal_count',
      TJSONNumber.Create(HeaderGoalCount)
    );
    Validation.AddPair(
      'yellow_card_event_count',
      TJSONNumber.Create(YellowCardEventCount)
    );
    Validation.AddPair(
      'structured_yellow_card_count',
      TJSONNumber.Create(StructuredYellowCardCount)
    );
    Validation.AddPair(
      'red_card_event_count',
      TJSONNumber.Create(RedCardEventCount)
    );
    Validation.AddPair(
      'structured_red_card_count',
      TJSONNumber.Create(StructuredRedCardCount)
    );
    Validation.AddPair(
      'overturned_card_event_count',
      TJSONNumber.Create(OverturnedCardEventCount)
    );
    Validation.AddPair(
      'structured_overturned_card_count',
      TJSONNumber.Create(StructuredOverturnedCardCount)
    );
    Validation.AddPair(
      'var_event_count',
      TJSONNumber.Create(VarEventCount)
    );
    Validation.AddPair(
      'structured_var_event_count',
      TJSONNumber.Create(StructuredVarEventCount)
    );
    Validation.AddPair(
      'var_player_resolved_count',
      TJSONNumber.Create(VarPlayerResolvedCount)
    );
    Validation.AddPair(
      'var_linked_event_count',
      TJSONNumber.Create(VarLinkedEventCount)
    );
    Validation.AddPair(
      'unlinked_var_event_count',
      TJSONNumber.Create(UnlinkedVarEventCount)
    );
    Validation.AddPair(
      'linked_overturned_card_count',
      TJSONNumber.Create(OverturnedCardLinkedCount)
    );
    Validation.AddPair(
      'unlinked_overturned_card_count',
      TJSONNumber.Create(
        UnlinkedOverturnedCardCount
      )
    );
    Validation.AddPair(
      'invalid_var_decision_flag_count',
      TJSONNumber.Create(
        InvalidVarDecisionFlagCount
      )
    );
    Validation.AddPair(
      'all_var_events_linked',
      TJSONBool.Create(UnlinkedVarEventCount = 0)
    );
    Validation.AddPair(
      'all_overturned_cards_linked',
      TJSONBool.Create(
        UnlinkedOverturnedCardCount = 0
      )
    );
    Validation.AddPair(
      'all_goal_scorers_resolved',
      TJSONBool.Create(
        StructuredGoalCount = GoalEventCount
      )
    );
    Validation.AddPair(
      'all_cards_resolved',
      TJSONBool.Create(
        (StructuredYellowCardCount =
          YellowCardEventCount) and
        (StructuredRedCardCount =
          RedCardEventCount) and
        (StructuredOverturnedCardCount =
          OverturnedCardEventCount)
      )
    );
    Validation.AddPair(
      'all_structured_events_resolved',
      TJSONBool.Create(
        (StructuredGoalCount = GoalEventCount) and
        (StructuredYellowCardCount =
          YellowCardEventCount) and
        (StructuredRedCardCount =
          RedCardEventCount) and
        (StructuredOverturnedCardCount =
          OverturnedCardEventCount) and
        (StructuredVarEventCount =
          VarEventCount) and
        (UnlinkedVarEventCount = 0) and
        (UnlinkedOverturnedCardCount = 0) and
        (InvalidVarDecisionFlagCount = 0) and
        (UnmatchedEvents.Count = 0)
      )
    );

    if StructuredGoalCount <> GoalEventCount then
      Inc(CriticalErrorCount);

    if StructuredRedCardCount <> RedCardEventCount then
      Inc(CriticalErrorCount);

    if StructuredOverturnedCardCount <>
       OverturnedCardEventCount then
      Inc(CriticalErrorCount);

    if StructuredYellowCardCount <>
       YellowCardEventCount then
      Inc(WarningCount);

    if StructuredVarEventCount <> VarEventCount then
      Inc(WarningCount);

    if UnlinkedVarEventCount > 0 then
      Inc(WarningCount);

    if UnlinkedOverturnedCardCount > 0 then
      Inc(WarningCount);

    if InvalidVarDecisionFlagCount > 0 then
      Inc(WarningCount);

    if UnmatchedEvents.Count > 0 then
      Inc(WarningCount);

    Validation.AddPair(
      'event_count_mismatch',
      TJSONBool.Create(
        (StructuredGoalCount <> GoalEventCount) or
        (StructuredYellowCardCount <>
          YellowCardEventCount) or
        (StructuredRedCardCount <>
          RedCardEventCount) or
        (StructuredOverturnedCardCount <>
          OverturnedCardEventCount) or
        (StructuredVarEventCount <> VarEventCount)
      )
    );
    Validation.AddPair(
      'has_critical_event_mismatch',
      TJSONBool.Create(CriticalErrorCount > 0)
    );
    Validation.AddPair(
      'critical_error_count',
      TJSONNumber.Create(CriticalErrorCount)
    );
    Validation.AddPair(
      'warning_count',
      TJSONNumber.Create(WarningCount)
    );
    Validation.AddPair(
      'has_event_count_warning',
      TJSONBool.Create(WarningCount > 0)
    );
    Validation.AddPair(
      'has_identity_resolution_error',
      TJSONBool.Create(
        (UnmatchedGoalScorerCount > 0) or
        (StructuredYellowCardCount <> YellowCardEventCount) or
        (StructuredRedCardCount <> RedCardEventCount) or
        (StructuredOverturnedCardCount <> OverturnedCardEventCount)
      )
    );
    Validation.AddPair(
      'has_score_integrity_error',
      TJSONBool.Create(StructuredGoalCount <> GoalEventCount)
    );
    if CriticalErrorCount > 0 then
      Validation.AddPair('validation_severity', 'critical')
    else if WarningCount > 0 then
      Validation.AddPair('validation_severity', 'warning')
    else
      Validation.AddPair('validation_severity', 'ok');
    Validation.AddPair(
      'is_valid',
      TJSONBool.Create(CriticalErrorCount = 0)
    );
    Validation.AddPair(
      'unmatched_events',
      UnmatchedEvents
    );
    UnmatchedEvents := nil;

    ExistingPair :=
      AAggregate.RemovePair(
        'structured_events_validation'
      );
    ExistingPair.Free;
    AAggregate.AddPair(
      'structured_events_validation',
      Validation
    );
    Validation := nil;

    {
      Do not raise here. Partial structured event enrichment is a
      data-quality result, not a collector-stopping condition. The
      mismatch details are persisted in structured_events_validation
      so v42 Validation Engine can mark the match as invalid/warning
      without blocking JSON output or the next queued match.
    }
  finally
    Validation.Free;
    UnmatchedEvents.Free;
    VarObjects.Free;
    Roster.Free;
  end;
end;

end.
