unit Exec;

interface

uses
{$IF CompilerVersion >= 23} // Delphi XE2+
  Winapi.Windows;
{$ELSE}
  Windows;
{$IFEND}

function ShellExecute2(const AWnd: HWND; const AOperation, AFileName: String; const AParameters: String = ''; const ADirectory: String = ''; const AShowCmd: Integer = SW_SHOWNORMAL): Boolean;
function WinExec2(const ACmdLine: String; const ACmdShow: UINT = SW_SHOWNORMAL): Boolean;

implementation

uses
{$IF CompilerVersion >= 23} // Delphi XE2+
  System.SysUtils, Winapi.ActiveX, Winapi.ShellAPI;
{$ELSE}
  SysUtils, ActiveX, ShellAPI;
{$IFEND}

function ShellExecute2(const AWnd: HWND; const AOperation, AFileName: String; const AParameters: String = ''; const ADirectory: String = ''; const AShowCmd: Integer = SW_SHOWNORMAL): Boolean;
var
  ExecInfo: TShellExecuteInfo;
  NeedUnitialize: Boolean;
begin
  NeedUnitialize := Succeeded(CoInitializeEx(nil, COINIT_APARTMENTTHREADED or COINIT_DISABLE_OLE1DDE));
  FillChar(ExecInfo, SizeOf(ExecInfo), 0);
  ExecInfo.cbSize := SizeOf(ExecInfo);

  ExecInfo.Wnd := AWnd;
  ExecInfo.lpVerb := Pointer(AOperation);
  ExecInfo.lpFile := PChar(AFileName);
  ExecInfo.lpParameters := Pointer(AParameters);
  ExecInfo.lpDirectory := Pointer(ADirectory);
  ExecInfo.nShow := AShowCmd;
  ExecInfo.fMask := SEE_MASK_FLAG_DDEWAIT
                 or SEE_MASK_FLAG_NO_UI;
  {$IFDEF UNICODE}
  // Необязательно, см. http://www.transl-gunsmoker.ru/2015/01/what-does-SEEMASKUNICODE-flag-in-ShellExecuteEx-actually-do.html
  ExecInfo.fMask := ExecInfo.fMask or SEE_MASK_UNICODE;
  {$ENDIF}

  Result := ShellExecuteEx(@ExecInfo);
  if NeedUnitialize then
    CoUninitialize;
end;

function WinExec2(const ACmdLine: String; const ACmdShow: UINT = SW_SHOWNORMAL): Boolean;
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  CmdLine: String;
begin
  CmdLine := ACmdLine;
  UniqueString(CmdLine);
 
  FillChar(SI, SizeOf(SI), 0);
  FillChar(PI, SizeOf(PI), 0);
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESHOWWINDOW;
  SI.wShowWindow := ACmdShow;
 
  SetLastError(ERROR_INVALID_PARAMETER);
  Result := CreateProcess(nil, PChar(CmdLine), nil, nil, False, CREATE_DEFAULT_ERROR_MODE {$IFDEF UNICODE}or CREATE_UNICODE_ENVIRONMENT{$ENDIF}, nil, nil, SI, PI);
  if not Result then Exit;
  CloseHandle(PI.hThread);
  CloseHandle(PI.hProcess);
end;

end.
