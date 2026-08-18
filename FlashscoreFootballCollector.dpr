program FlashscoreFootballCollector;

uses
  Vcl.Forms,
  System.SysUtils,
  Winapi.Windows,
  MainFormUnit in 'Source\MainFormUnit.pas',
  JsonViewerUnit in 'Source\JsonViewerUnit.pas',
  Collector.Types in 'Source\Collector.Types.pas',
  Collector.Json in 'Source\Collector.Json.pas',
  Collector.State in 'Source\Collector.State.pas',
  Collector.Scripts in 'Source\Collector.Scripts.pas',
  Collector.Profiles in 'Source\Collector.Profiles.pas',
  Collector.StructuredEvents in 'Source\Collector.StructuredEvents.pas',
  Collector.Utils in 'Source\Collector.Utils.pas',
  Collector.Dashboard in 'Source\Collector.Dashboard.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  ApplyCollectorDashboard(MainForm);
  Application.Run;
end.
