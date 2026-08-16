unit Collector.Utils;

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.RegularExpressions,
  System.DateUtils;

function AppPath(const ARelativePath: string): string;
function EnsureDirectoryForFile(const AFileName: string): string;
function SafeFileName(const AValue: string): string;
function TryExtractMatchId(const AUrl: string; out AMatchId: string): Boolean;
function IsoNowUtc: string;
procedure AppendLog(const AFileName, AMessage: string);

implementation

function AppPath(const ARelativePath: string): string;
begin
  if TPath.IsPathRooted(ARelativePath) then
    Exit(ARelativePath);

  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), ARelativePath);
end;

function EnsureDirectoryForFile(const AFileName: string): string;
var
  Dir: string;
begin
  Result := AFileName;
  Dir := ExtractFileDir(AFileName);
  if (Dir <> '') and not TDirectory.Exists(Dir) then
    TDirectory.CreateDirectory(Dir);
end;

function SafeFileName(const AValue: string): string;
const
  InvalidChars: array[0..8] of Char = ('<', '>', ':', '"', '/', '\', '|', '?', '*');
var
  C: Char;
begin
  Result := Trim(AValue);
  for C in InvalidChars do
    Result := Result.Replace(C, '_');

  Result := TRegEx.Replace(Result, '\s+', '_');
  Result := TRegEx.Replace(Result, '_+', '_');
  Result := Result.Trim(['_', '.']);

  if Result = '' then
    Result := 'unknown';
end;

function TryExtractMatchId(const AUrl: string; out AMatchId: string): Boolean;
var
  Match: TMatch;
begin
  Match := TRegEx.Match(AUrl, '(?:[?&]mid=|/match/[^/]+/[^/]+/[^?]*\?mid=)([A-Za-z0-9]+)',
    [roIgnoreCase]);

  if not Match.Success then
    Match := TRegEx.Match(AUrl, '[?&]mid=([A-Za-z0-9]+)', [roIgnoreCase]);

  Result := Match.Success;
  if Result then
    AMatchId := Match.Groups[1].Value
  else
    AMatchId := '';
end;

function IsoNowUtc: string;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', TTimeZone.Local.ToUniversalTime(Now));
end;

procedure AppendLog(const AFileName, AMessage: string);
var
  FullName: string;
  Line: string;
begin
  FullName := EnsureDirectoryForFile(AppPath(AFileName));
  Line := Format('[%s] %s%s', [IsoNowUtc, AMessage, sLineBreak]);
  TFile.AppendAllText(FullName, Line, TEncoding.UTF8);
end;

end.
