unit Collector.State;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  System.RegularExpressions,
  System.Generics.Collections,
  Collector.Types;

type
  TProcessedMatchStore = class
  private
    FFileName: string;
    FOutputDirectory: string;
    FIds: TDictionary<string, Boolean>;
    procedure Load;
    procedure LoadFromExistingOutputs;
  public
    constructor Create(const AFileName, AOutputDirectory: string);
    destructor Destroy; override;
    function Contains(const AMatchId: string): Boolean;
    procedure MarkProcessed(const AMatchId, AOutputFile: string);
    function Count: Integer;
  end;

  TMatchQueue = class
  private
    FFileName: string;
    FItems: TObjectList<TMatchQueueItem>;
    procedure Load;
    procedure Save;
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    function FirstUnprocessed(const AStore: TProcessedMatchStore): TMatchQueueItem;
    function NextUnprocessedAfter(const AAfterMatchId: string;
      const AStore: TProcessedMatchStore): TMatchQueueItem;
    function HasUnprocessed(const AStore: TProcessedMatchStore): Boolean;
    function AddIfMissing(const AMatchId, AUrl: string): Boolean;
    procedure Clear;
    property Items: TObjectList<TMatchQueueItem> read FItems;
  end;

implementation

uses
  Collector.Utils,
  Collector.Json;

constructor TProcessedMatchStore.Create(
  const AFileName, AOutputDirectory: string);
begin
  inherited Create;
  FFileName := AppPath(AFileName);
  FOutputDirectory := AppPath(AOutputDirectory);
  FIds := TDictionary<string, Boolean>.Create;
  Load;
  LoadFromExistingOutputs;
end;

destructor TProcessedMatchStore.Destroy;
begin
  FIds.Free;
  inherited;
end;

procedure TProcessedMatchStore.Load;
var
  Root: TJSONObject;
  ArrayValue: TJSONArray;
  Item: TJSONValue;
begin
  if not TFile.Exists(FFileName) then
    Exit;

  Root := ParseJsonObject(TFile.ReadAllText(FFileName, TEncoding.UTF8));
  try
    ArrayValue := Root.GetValue<TJSONArray>('processed');
    if ArrayValue = nil then
      Exit;

    for Item in ArrayValue do
      if Item is TJSONObject then
        FIds.AddOrSetValue(JsonStringValue(TJSONObject(Item), 'match_id'), True);
  finally
    Root.Free;
  end;
end;

procedure TProcessedMatchStore.LoadFromExistingOutputs;
var
  FileName: string;
  BaseName: string;
  Match: TMatch;
begin
  if not TDirectory.Exists(FOutputDirectory) then
    Exit;

  for FileName in TDirectory.GetFiles(
    FOutputDirectory,
    '*.json',
    TSearchOption.soTopDirectoryOnly
  ) do
  begin
    BaseName := TPath.GetFileNameWithoutExtension(FileName);
    Match := TRegEx.Match(BaseName, '_([A-Za-z0-9]{8})$');
    if Match.Success then
      FIds.AddOrSetValue(Match.Groups[1].Value, True);
  end;
end;

function TProcessedMatchStore.Contains(const AMatchId: string): Boolean;
begin
  Result := (AMatchId <> '') and FIds.ContainsKey(AMatchId);
end;


function TProcessedMatchStore.Count: Integer;
begin
  Result := FIds.Count;
end;

procedure TProcessedMatchStore.MarkProcessed(const AMatchId, AOutputFile: string);
var
  Root: TJSONObject;
  ArrayValue: TJSONArray;
  Item: TJSONObject;
begin
  if AMatchId = '' then
    raise EArgumentException.Create('Match ID must not be empty.');

  if FIds.ContainsKey(AMatchId) then
    Exit;

  if TFile.Exists(FFileName) then
    Root := ParseJsonObject(TFile.ReadAllText(FFileName, TEncoding.UTF8))
  else
  begin
    Root := TJSONObject.Create;
    Root.AddPair('schema_version', '1.0');
    Root.AddPair('processed', TJSONArray.Create);
  end;

  try
    ArrayValue := Root.GetValue<TJSONArray>('processed');
    if ArrayValue = nil then
    begin
      ArrayValue := TJSONArray.Create;
      Root.AddPair('processed', ArrayValue);
    end;

    Item := TJSONObject.Create;
    Item.AddPair('match_id', AMatchId);
    Item.AddPair('processed_at_utc', IsoNowUtc);
    Item.AddPair('output_file', ExtractFileName(AOutputFile));
    ArrayValue.AddElement(Item);

    Root.RemovePair('last_updated_utc').Free;
    Root.AddPair('last_updated_utc', IsoNowUtc);

    EnsureDirectoryForFile(FFileName);
    TFile.WriteAllText(FFileName, Root.Format(2), TEncoding.UTF8);
    FIds.AddOrSetValue(AMatchId, True);
  finally
    Root.Free;
  end;
end;

constructor TMatchQueue.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AppPath(AFileName);
  FItems := TObjectList<TMatchQueueItem>.Create(True);
  Load;
end;

destructor TMatchQueue.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TMatchQueue.Load;
var
  Root: TJSONObject;
  ArrayValue: TJSONArray;
  Value: TJSONValue;
  Obj: TJSONObject;
  Item: TMatchQueueItem;
begin
  if not TFile.Exists(FFileName) then
  begin
    EnsureDirectoryForFile(FFileName);
    TFile.WriteAllText(FFileName,
      '{' + sLineBreak +
      '  "schema_version": "1.1",' + sLineBreak +
      '  "matches": []' + sLineBreak +
      '}', TEncoding.UTF8);
  end;

  Root := ParseJsonObject(TFile.ReadAllText(FFileName, TEncoding.UTF8));
  try
    ArrayValue := Root.GetValue<TJSONArray>('matches');
    if ArrayValue = nil then
      raise EJSONException.Create('Queue JSON does not contain "matches".');

    for Value in ArrayValue do
    begin
      if not (Value is TJSONObject) then
        Continue;

      Obj := TJSONObject(Value);
      Item := TMatchQueueItem.Create;
      Item.Url := JsonStringValue(Obj, 'url');
      Item.MatchId := JsonStringValue(Obj, 'match_id');
      if Item.MatchId = '' then
      begin
        var ExtractedMatchId := '';
        if TryExtractMatchId(Item.Url, ExtractedMatchId) then
          Item.MatchId := ExtractedMatchId;
      end;

      if (Item.Url <> '') and (Item.MatchId <> '') then
        FItems.Add(Item)
      else
        Item.Free;
    end;
  finally
    Root.Free;
  end;
end;

function TMatchQueue.FirstUnprocessed(
  const AStore: TProcessedMatchStore): TMatchQueueItem;
var
  Item: TMatchQueueItem;
begin
  Result := nil;
  for Item in FItems do
    if not AStore.Contains(Item.MatchId) then
      Exit(Item);
end;

function TMatchQueue.NextUnprocessedAfter(
  const AAfterMatchId: string;
  const AStore: TProcessedMatchStore): TMatchQueueItem;
var
  Item: TMatchQueueItem;
  PassedCurrent: Boolean;
begin
  Result := nil;
  PassedCurrent := AAfterMatchId = '';

  for Item in FItems do
  begin
    if not PassedCurrent then
    begin
      if SameText(Item.MatchId, AAfterMatchId) then
        PassedCurrent := True;
      Continue;
    end;

    if not SameText(Item.MatchId, AAfterMatchId) and
       not AStore.Contains(Item.MatchId) then
      Exit(Item);
  end;

  // If the current ID was not found in the queue, return the first other
  // unprocessed item. Never return the same match again.
  for Item in FItems do
    if not SameText(Item.MatchId, AAfterMatchId) and
       not AStore.Contains(Item.MatchId) then
      Exit(Item);
end;

function TMatchQueue.HasUnprocessed(
  const AStore: TProcessedMatchStore): Boolean;
begin
  Result := FirstUnprocessed(AStore) <> nil;
end;

function TMatchQueue.AddIfMissing(
  const AMatchId, AUrl: string): Boolean;
var
  Existing: TMatchQueueItem;
  Item: TMatchQueueItem;
begin
  Result := False;

  if (Trim(AMatchId) = '') or (Trim(AUrl) = '') then
    Exit;

  for Existing in FItems do
    if SameText(Existing.MatchId, AMatchId) then
      Exit;

  Item := TMatchQueueItem.Create;
  Item.MatchId := AMatchId;
  Item.Url := AUrl;
  FItems.Add(Item);
  Save;
  Result := True;
end;

procedure TMatchQueue.Clear;
begin
  FItems.Clear;
  Save;
end;

procedure TMatchQueue.Save;
var
  Root: TJSONObject;
  ArrayValue: TJSONArray;
  Item: TMatchQueueItem;
  Obj: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('schema_version', '1.1');
    ArrayValue := TJSONArray.Create;
    Root.AddPair('matches', ArrayValue);

    for Item in FItems do
    begin
      Obj := TJSONObject.Create;
      Obj.AddPair('match_id', Item.MatchId);
      Obj.AddPair('url', Item.Url);
      ArrayValue.AddElement(Obj);
    end;

    EnsureDirectoryForFile(FFileName);
    TFile.WriteAllText(FFileName, Root.Format(2), TEncoding.UTF8);
  finally
    Root.Free;
  end;
end;

end.
