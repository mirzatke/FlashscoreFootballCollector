unit Collector.Json;

interface

uses
  System.SysUtils,
  System.JSON;

function DecodeExecuteScriptResult(const AResultObjectAsJson: string): string;
function ParseJsonObject(const AJson: string): TJSONObject;
function JsonStringValue(const AObject: TJSONObject; const AName: string;
  const ADefault: string = ''): string;
function JsonIntegerValue(const AObject: TJSONObject; const AName: string;
  const ADefault: Integer = 0): Integer;
function JsonBooleanValue(const AObject: TJSONObject; const AName: string;
  const ADefault: Boolean = False): Boolean;

implementation

function DecodeExecuteScriptResult(const AResultObjectAsJson: string): string;
var
  Value: TJSONValue;
  Current: string;
  Pass: Integer;
begin
  Current := Trim(AResultObjectAsJson);

  // WebView2 normally returns a JSON-encoded value. Older/runtime-specific
  // combinations may wrap a returned JSON string more than once.
  for Pass := 1 to 3 do
  begin
    Value := TJSONObject.ParseJSONValue(Current);
    if Value = nil then
      Break;

    try
      if Value is TJSONString then
        Current := TJSONString(Value).Value
      else
        Exit(Current);
    finally
      Value.Free;
    end;
  end;

  Result := Current;
end;

function ParseJsonObject(const AJson: string): TJSONObject;
var
  Value: TJSONValue;
begin
  Value := TJSONObject.ParseJSONValue(AJson);
  if not (Value is TJSONObject) then
  begin
    Value.Free;
    raise EJSONException.Create('JSON root must be an object.');
  end;
  Result := TJSONObject(Value);
end;

function JsonStringValue(const AObject: TJSONObject; const AName,
  ADefault: string): string;
var
  Value: TJSONValue;
begin
  Value := AObject.GetValue(AName);
  if (Value = nil) or (Value is TJSONNull) then
    Exit(ADefault);
  Result := Value.Value;
end;

function JsonIntegerValue(const AObject: TJSONObject; const AName: string;
  const ADefault: Integer): Integer;
var
  Text: string;
begin
  Text := JsonStringValue(AObject, AName, '');
  if not TryStrToInt(Text, Result) then
    Result := ADefault;
end;

function JsonBooleanValue(const AObject: TJSONObject; const AName: string;
  const ADefault: Boolean): Boolean;
var
  Text: string;
begin
  Text := JsonStringValue(AObject, AName, '');
  if SameText(Text, 'true') then
    Exit(True);
  if SameText(Text, 'false') then
    Exit(False);
  Result := ADefault;
end;

end.
