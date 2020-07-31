(******************************************************************************

MIT License

Copyright (c) 2020 Eugene Krasnikov / ≈вгений  расников (aka Jin X)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

******************************************************************************)

unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Buttons, HardDriveInfo, Exec;

type
  TFormMain = class(TForm)
    PanelDisk: TPanel;
    ComboDisk: TComboBox;
    CheckAllowAll: TCheckBox;
    PanelOptions: TPanel;
    CheckBackup: TCheckBox;
    EditBackup: TEdit;
    ButtonBackupBrowse: TBitBtn;
    CheckReplace: TCheckBox;
    EditReplace: TEdit;
    ComboBackupType: TComboBox;
    ButtonReplaceBrowse: TBitBtn;
    ComboReplaceType: TComboBox;
    CheckWarnBoot: TCheckBox;
    ButtonWarnBootHelp: TBitBtn;
    ButtonStart: TBitBtn;
    PanelActions: TPanel;
    PanelLog: TPanel;
    MemoLog: TMemo;
    CheckSaveLog: TCheckBox;
    OpenDialogReplace: TOpenDialog;
    SaveDialogBackup: TSaveDialog;
    TimerDisks: TTimer;
    TextCopyright: TStaticText;
    CheckBackupSaveDest: TCheckBox;
    ButtonBackupSaveDestHelp: TBitBtn;
    bvl1: TBevel;
    CheckBackupClear: TCheckBox;
    CheckReplaceClear: TCheckBox;
    procedure DeviceChange(var Msg: TMessage); message WM_DEVICECHANGE;
    procedure SetEnables;
    procedure UpdateDiskDrives;
    procedure FormShow(Sender: TObject);
    procedure CheckBackupClick(Sender: TObject);
    procedure CheckReplaceClick(Sender: TObject);
    procedure EditBackupChange(Sender: TObject);
    procedure EditReplaceChange(Sender: TObject);
    procedure ButtonBackupBrowseClick(Sender: TObject);
    procedure ButtonReplaceBrowseClick(Sender: TObject);
    procedure ComboDiskChange(Sender: TObject);
    procedure CheckAllowAllClick(Sender: TObject);
    procedure TimerDisksTimer(Sender: TObject);
    procedure TextCopyrightDblClick(Sender: TObject);
    procedure ButtonStartClick(Sender: TObject);
    procedure ButtonBackupSaveDestHelpClick(Sender: TObject);
    procedure ButtonWarnBootHelpClick(Sender: TObject);
    procedure ComboBackupTypeChange(Sender: TObject);
    procedure ComboReplaceTypeChange(Sender: TObject);
    procedure CheckBackupSaveDestClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

const
  MAX_DRIVE_COUNT = 16;
  SECTOR_SIZE = 512;
  PART_TABLE_SIZE = 16*4;
  PART_TABLE_OFFSET = SECTOR_SIZE - PART_TABLE_SIZE - 2;
  DiskClassDeviceInterfaceGuid: TGUID = GUID_DEVINTERFACE_DISK;

var
  FormMain: TFormMain;
  LastDriveNum: DWORD = $FFFFFFFF;
  LastDriveName: String = '';

implementation

{$R *.dfm}

// WM_DEVICECHANGE message handler
procedure TFormMain.DeviceChange(var Msg: TMessage);
const
  DBT_DEVNODES_CHANGED = 7;
begin
  if Msg.WParam = DBT_DEVNODES_CHANGED then UpdateDiskDrives;
end;

// Turn elements and their enablement
procedure TFormMain.SetEnables;
var
  ChkBak, ChkBakFile, ChkRepl, ChkReplFile: Boolean;
  S: String;
begin
  ChkBak := CheckBackup.Checked;
  ChkRepl := CheckReplace.Checked;

  ComboBackupType.Enabled := ChkBak;
  CheckBackupClear.Visible := CheckBackupSaveDest.Checked and (ComboBackupType.ItemIndex <> 0);
  CheckBackupClear.ShowHint := (ComboBackupType.ItemIndex = 2);
  if ComboBackupType.ItemIndex = 1 then CheckBackupClear.Caption := 'clear partition table'
  else CheckBackupClear.Caption := 'clear bootstrap code';
  ButtonBackupBrowse.Enabled := ChkBak;
  EditBackup.Enabled := ChkBak;

  ComboReplaceType.Enabled := ChkRepl;
  CheckReplaceClear.Visible := (ComboReplaceType.ItemIndex <> 0);
  CheckReplaceClear.ShowHint := (ComboReplaceType.ItemIndex = 2);
  if ComboReplaceType.ItemIndex = 1 then CheckReplaceClear.Caption := 'clear partition table'
  else CheckReplaceClear.Caption := 'clear bootstrap code';
  ButtonReplaceBrowse.Enabled := ChkRepl;
  EditReplace.Enabled := ChkRepl;

  ChkBakFile := (EditBackup.Text <> '');
  ChkReplFile := (EditReplace.Text <> '');
  ButtonStart.Enabled := (ComboDisk.ItemIndex <> -1) and
                        ((ChkBak and ChkBakFile and (not ChkRepl or ChkReplFile)) or
                         (ChkRepl and ChkReplFile and (not ChkBak or ChkBakFile)));
  S := 'START';
  if ChkBak then
  begin
    S := S + ' Ч> Backup';
    if not ChkBakFile and (not ChkRepl or ChkReplFile) then S := S + ' (filename is not specified)';
  end;
  if ChkRepl then
  begin
    S := S + ' Ч> Replace';
    if not ChkReplFile then
      if not ChkBak or ChkBakFile then S := S + ' (filename is not specified)'
      else S := S + ' (filenames are not specified)';
  end;
  if not ChkBak and not ChkRepl then S := S + ' (Nothing: no Backup or Replace option is checked)';
  ButtonStart.Caption := S;
end; // SetEnables

function DriveSortCompareFunc(List: TStringList; Index1, Index2: Integer): Integer;
begin
  if DWORD(List.Objects[Index1]) < DWORD(List.Objects[Index2]) then Result := -1
  else if DWORD(List.Objects[Index1]) > DWORD(List.Objects[Index2]) then Result := 1
  else Result := 0;
end;

// Update disk drives list in ComboBox
procedure TFormMain.UpdateDiskDrives;
var
  DriveN, LetMask, Idx: DWORD;
  DriveLet: Char;
  H: THandle;
  S: String;
  AllowAll, DiSuccess: Boolean;
  DriveInfoList: TStringList;
  Ret: DWORD;
  LetInfo: array ['A'..'Z'] of record
    DriveN: DWORD;
    VolName: String;
  end;
  VolName: array [0..MAX_PATH] of Char;
  DiskClassDevices: HDEVINFO;
  DeviceInterfaceData: SP_DEVICE_INTERFACE_DATA;
  DeviceInterfaceDetailData: PSP_DEVICE_INTERFACE_DETAIL_DATA;
  StorageDeviceNumber: TStorageDeviceNumber;
  DiskGeometryEx: TDiskGeometryEx;
  StoragePropertyQuery: TStoragePropertyQuery;
  StorageDeviceDescriptor: array [0..1023] of Char;

  // Fill InfoStr with drive info string (if result is True);
  function GetDriveInfoString(DriveN: DWORD; var InfoStr: String): Boolean;
  var
    H: THandle;
    DriveLet: Char;
  begin
    Result := False;
    H := CreateFile(PChar(DRIVE_NAME_PREFIX + IntToStr(DriveN)), 0, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
    if H = INVALID_HANDLE_VALUE then Exit;
    FillChar(DiskGeometryEx, SizeOf(DiskGeometryEx), 0);
    if not DeviceIoControl(H, IOCTL_DISK_GET_DRIVE_GEOMETRY_EX, nil, 0, @DiskGeometryEx, SizeOf(DiskGeometryEx), Ret, nil) or
       (DiskGeometryEx.Geometry.BytesPerSector <> SECTOR_SIZE) or
       (not AllowAll and (DiskGeometryEx.Geometry.MediaType <> mtRemovableMedia)) then Exit;

    // Drive letters and volume labels
    InfoStr := '';
    for DriveLet := 'A' to 'Z' do
      if LetInfo[DriveLet].DriveN = DriveN then
      begin
        if InfoStr <> '' then InfoStr := InfoStr + ', ';
        InfoStr := InfoStr + DriveLet + ':';
        if LetInfo[DriveLet].VolName = '' then
          InfoStr := InfoStr + ' (no label)'
        else
          InfoStr := InfoStr + ' (' + LetInfo[DriveLet].VolName + ')';
      end;
    if InfoStr = '' then InfoStr := 'no drive letters';
    InfoStr := InfoStr + ' [';

    // Drive size
    if DiskGeometryEx.DiskSize < 1000000 then
      InfoStr := InfoStr + FloatToStrF(DiskGeometryEx.DiskSize / 1000, ffNumber, 20, 2) + ' KB'
    else if DiskGeometryEx.DiskSize < 1000000000 then
      InfoStr := InfoStr + FloatToStrF(DiskGeometryEx.DiskSize / 1000000, ffNumber, 20, 1) + ' MB'
    else if DiskGeometryEx.DiskSize < 1000000000000 then
      InfoStr := InfoStr + FloatToStrF(DiskGeometryEx.DiskSize / 1000000000, ffNumber, 20, 1) + ' GB'
    else
      InfoStr := InfoStr + FloatToStrF(DiskGeometryEx.DiskSize / 1000000000000, ffNumber, 20, 1) + ' TB';
    InfoStr := InfoStr + ']';
    case DiskGeometryEx.Geometry.MediaType of
      mtRemovableMedia: InfoStr := InfoStr + ' - removable';
      mtFixedMedia: InfoStr := InfoStr + ' - fixed';
      mtUnknown: InfoStr := InfoStr + ' - unknown type';
      else InfoStr := InfoStr + ' - floppy';
    end;

    // Physical drive name (product id)
    FillChar(StoragePropertyQuery, SizeOf(StoragePropertyQuery), 0);
    FillChar(StorageDeviceDescriptor, SizeOf(StorageDeviceDescriptor), 0);
    StoragePropertyQuery.PropertyId := StorageDeviceProperty;
    StoragePropertyQuery.QueryType := PropertyStandardQuery;
    if DeviceIoControl(H, IOCTL_STORAGE_QUERY_PROPERTY, @StoragePropertyQuery, SizeOf(StoragePropertyQuery), @StorageDeviceDescriptor, SizeOf(StorageDeviceDescriptor), Ret, nil) then
    begin
      Ret := PStorageDeviceDescriptor(@StorageDeviceDescriptor).ProductIdOffset;
      if Ret <> 0 then
        InfoStr := Trim(PChar(@StorageDeviceDescriptor[Ret])) + ' - ' + InfoStr;
    end;
    CloseHandle(H);

    // Drive number
    InfoStr := '#' + IntToStr(DriveN) + '. ' + InfoStr;
    Result := True;
  end; // GetDriveInfoString

begin
  TimerDisks.Enabled := False;
  AllowAll := CheckAllowAll.Checked;
  DriveInfoList := TStringList.Create;

  // Fill LetInfo with drive numbers and volume labels
  for DriveLet := 'A' to 'Z' do
    LetInfo[DriveLet].DriveN := $FFFFFFFF;
  LetMask := GetLogicalDrives;
  for DriveLet := 'A' to 'Z' do
  begin
    if (LetMask and 1 <> 0) then
    begin
      H := CreateFile(PChar('\\.\'+DriveLet+':'), 0, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
      if H <> INVALID_HANDLE_VALUE then
      begin
        FillChar(StorageDeviceNumber, SizeOf(StorageDeviceNumber), -1);
        if DeviceIoControl(H, IOCTL_STORAGE_GET_DEVICE_NUMBER, nil, 0, @StorageDeviceNumber, SizeOf(StorageDeviceNumber), Ret, nil) and
           (StorageDeviceNumber.PartitionNumber <> $FFFFFFFF) then
        begin
          LetInfo[DriveLet].DriveN := StorageDeviceNumber.DeviceNumber;
          if GetVolumeInformation(PChar(DriveLet+':\'), VolName, SizeOf(VolName), nil, Ret, Ret, nil, 0) and (VolName <> '') then
            LetInfo[DriveLet].VolName := VolName;
        end;
        CloseHandle(H);
      end;
    end
    else if LetMask = 0 then Break;
    LetMask := LetMask shr 1;
  end; // for DiskLet

  // Fill DriveInfoList with physical drive information (GetDriveInfoString)
  DiskClassDevices := SetupDiGetClassDevs(@DiskClassDeviceInterfaceGuid, nil, 0, DIGCF_PRESENT or DIGCF_DEVICEINTERFACE);
  DiSuccess := (DiskClassDevices <> Pointer(INVALID_HANDLE_VALUE));
  Idx := 0;
  while (DiSuccess) do
  begin
    FillChar(DeviceInterfaceData, SizeOf(DeviceInterfaceData), 0);
    DeviceInterfaceData.cbSize := SizeOf(DeviceInterfaceData);
    if SetupDiEnumDeviceInterfaces(DiskClassDevices, 0, @DiskClassDeviceInterfaceGuid, Idx, DeviceInterfaceData) then
    begin
      DiSuccess := False;
      SetupDiGetDeviceInterfaceDetail(DiskClassDevices, DeviceInterfaceData, nil, 0, @Ret, nil);
      if GetLastError = ERROR_INSUFFICIENT_BUFFER then
      begin
        GetMem(DeviceInterfaceDetailData, Ret);
        FillChar(DeviceInterfaceDetailData^, Ret, 0);
        DeviceInterfaceDetailData.cbSize := 6; // doesn't work with SizeOf(DeviceInterfaceDetailData^) = 8;
        if SetupDiGetDeviceInterfaceDetail(DiskClassDevices, DeviceInterfaceData, DeviceInterfaceDetailData, Ret, nil, nil) then
        begin
          H := CreateFileW(DeviceInterfaceDetailData.DevicePath, 0, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
          if H <> INVALID_HANDLE_VALUE then
          begin
            DiSuccess := DeviceIoControl(H, IOCTL_STORAGE_GET_DEVICE_NUMBER, nil, 0, @StorageDeviceNumber, SizeOf(StorageDeviceNumber), Ret, nil);
            if DiSuccess and GetDriveInfoString(StorageDeviceNumber.DeviceNumber, S) then
              DriveInfoList.AddObject(S, Pointer(StorageDeviceNumber.DeviceNumber));
            CloseHandle(H);
          end;
        end;
        FreeMem(DeviceInterfaceDetailData);
      end
    end
    else // if SetupDiEnumDeviceInterfaces...
    begin
      DiSuccess := (GetLastError = ERROR_NO_MORE_ITEMS);
      Break;
    end;
    Inc(Idx);
  end; // while (DiSuccess)
  if DiskClassDevices <> Pointer(INVALID_HANDLE_VALUE) then SetupDiDestroyDeviceInfoList(DiskClassDevices);

  if DiSuccess then DriveInfoList.CustomSort(DriveSortCompareFunc)
  else
  // Alternative method (when SetupAPI fails)
  begin
    DriveInfoList.Clear;
    for DriveN := 0 to MAX_DRIVE_COUNT-1 do
      if GetDriveInfoString(DriveN, S) then
        DriveInfoList.AddObject(S, Pointer(DriveN));
  end;

  // Update ComboBox if needed
  if DriveInfoList.Text <> ComboDisk.Items.Text then
  begin
    ComboDisk.Items.Assign(DriveInfoList);
    Idx := ComboDisk.Items.IndexOf(LastDriveName);
//    if (N = -1) and (ComboDisk.Items.Count > 0) then N := 0;  // select first drive if no selection
    ComboDisk.ItemIndex := Idx;
    ComboDiskChange(ComboDisk);
  end;
  DriveInfoList.Free;

  TimerDisks.Enabled := True;
end; // UpdateDiskDrives

procedure TFormMain.FormShow(Sender: TObject);
begin
  UpdateDiskDrives;
  if ComboDisk.Items.Count > 0 then
  begin
    ComboDisk.ItemIndex := 0;
    ComboDiskChange(ComboDisk);
  end;
  SetEnables;
end;

procedure TFormMain.CheckBackupClick(Sender: TObject);
begin
  SetEnables;
end;

procedure TFormMain.CheckReplaceClick(Sender: TObject);
begin
  SetEnables;
end;

procedure TFormMain.EditBackupChange(Sender: TObject);
begin
  SetEnables;
end;

procedure TFormMain.EditReplaceChange(Sender: TObject);
begin
  SetEnables;
end;

procedure TFormMain.ButtonBackupBrowseClick(Sender: TObject);
begin
  if SaveDialogBackup.Execute then
    EditBackup.Text := SaveDialogBackup.FileName;
end;

procedure TFormMain.ButtonReplaceBrowseClick(Sender: TObject);
begin
  if OpenDialogReplace.Execute then
    EditReplace.Text := OpenDialogReplace.FileName;
end;

procedure TFormMain.ComboDiskChange(Sender: TObject);
var Idx: Integer;
begin
  Idx := ComboDisk.ItemIndex;
  if Idx <> -1 then
  begin
    LastDriveNum := DWORD(ComboDisk.Items.Objects[Idx]);
    LastDriveName := ComboDisk.Text;
  end
  else LastDriveNum := $FFFFFFFF;
  SetEnables;
end;

procedure TFormMain.CheckAllowAllClick(Sender: TObject);
begin
  UpdateDiskDrives;
end;

procedure TFormMain.TimerDisksTimer(Sender: TObject);
begin
  UpdateDiskDrives;
end;

procedure TFormMain.TextCopyrightDblClick(Sender: TObject);
begin
  ShellExecute2(Handle, '', 'mailto:jin_x@list.ru');
end;

// Backup and replace
procedure TFormMain.ButtonStartClick(Sender: TObject);
var
  H: THandle;
  DriveN: DWORD;
  N, i: Integer;
  Total, LBA1, LBA2: Int64;
  Part1, Part2, Ret: DWORD;
  DriveName, Filename, S: String;
  SaveDest, Error: Boolean;
  PartTblChk: (ptOk, ptEmpty, ptLarge, ptError);
  SrcSec: array [0..511] of Byte;
  DestSec: array [0..511] of Byte;
  DiskGeometryEx: TDiskGeometryEx;

  // Returns -1 if C=H=S=0
  function CHStoLBA(C, H, S: DWORD; const Geometry: TDiskGeometry): Int64;
  begin
    if (C or H or S = 0) then Result := -1
    else Result := (Int64(C) * Geometry.TracksPerCylinder + H) * Geometry.SectorsPerTrack + S - 1;
  end;

begin
  DriveN := LastDriveNum;
  if DriveN = $FFFFFFFF then Exit;
  DriveName := LastDriveName;

  ////////////////////////////////////////////////////////////////////////////////
  // Backup MBR sector
  if CheckBackup.Checked then
  begin
    // Check drive
    UpdateDiskDrives;
    if (DriveN <> LastDriveNum) or (DriveName <> LastDriveName) then
    begin
      MessageBox(0, 'Selected device is absent!', 'Backup Error', MB_OK or MB_ICONERROR or MB_TASKMODAL or MB_SETFOREGROUND);
      Exit;
    end;

    // Read original sector from drive
    H := CreateFile(PChar(DRIVE_NAME_PREFIX + IntToStr(DriveN)), GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
    if H = INVALID_HANDLE_VALUE then
    begin
      MessageBox(0, PChar('Error opening selected drive for reading!'#13'[' + SysErrorMessage(GetLastError) + '].'), 'Backup Error', MB_OK or MB_ICONERROR or MB_TASKMODAL or MB_SETFOREGROUND);
      Exit;
    end;
    try
      if (not ReadFile(H, SrcSec, SECTOR_SIZE, Ret, nil)) or (Ret <> SECTOR_SIZE) then
      begin
        MessageBox(0, PChar('Error reading from selected drive!'#13'[' + SysErrorMessage(GetLastError) + '].'), 'Backup Error', MB_OK or MB_ICONERROR or MB_TASKMODAL or MB_SETFOREGROUND);
        Exit;
      end;
    finally
      CloseHandle(H);
    end;

    // Read sector from file
    Filename := EditBackup.Text;
    FillChar(DestSec, SECTOR_SIZE, 0);
    SaveDest := CheckBackupSaveDest.Checked and FileExists(Filename);
    if SaveDest then
    begin
      H := FileOpen(Filename, fmOpenRead);
      if H = INVALID_HANDLE_VALUE then
      begin
        MessageBox(0, PChar('Error opening destination file for reading!'#13'[' + SysErrorMessage(GetLastError) + '].'), 'Backup Error', MB_OK or MB_ICONERROR or MB_TASKMODAL or MB_SETFOREGROUND);
        Exit;
      end;
      try
        N := FileRead(H, DestSec, SECTOR_SIZE);
        if N <> SECTOR_SIZE then
        begin
          if N = -1 then  // error
            MessageBox(0, PChar('Error reading from destination file!'#13'[' + SysErrorMessage(GetLastError) + '].'), 'Backup Error', MB_OK or MB_ICONERROR or MB_TASKMODAL or MB_SETFOREGROUND)
          else
            N := MessageBox(0, 'Destination file size is less than 512 bytes.'#13'Continue and still use it?', 'Backup Warning', MB_YESNO or MB_ICONWARNING or MB_TASKMODAL or MB_SETFOREGROUND);
          if N <> IDYES then Exit;
        end;
      finally
        FileClose(H);
      end;
    end; // if SaveDest

    // Copy sector content
    case ComboBackupType.ItemIndex of
      1: // bootstrap code only
      begin
        Move(SrcSec, DestSec, PART_TABLE_OFFSET);  // code
        Move(SrcSec[510], DestSec[510], 2);        // signature
        if CheckBackupClear.Checked then
          FillChar(DestSec[PART_TABLE_OFFSET], PART_TABLE_SIZE, 0);  // clear partition table
      end;
      2: // partition table only
      begin
        Move(SrcSec[PART_TABLE_OFFSET], DestSec[PART_TABLE_OFFSET], PART_TABLE_SIZE);
        if CheckBackupClear.Checked then
          FillChar(DestSec, PART_TABLE_OFFSET, 0);  // clear code
      end;
      else {0} // entire MBR sector
        Move(SrcSec, DestSec, SECTOR_SIZE);
    end; // case

    // Write sector to file
    if SaveDest then H := FileOpen(Filename, fmOpenWrite)
    else H := FileCreate(Filename);
    if H = INVALID_HANDLE_VALUE then
    begin
      MessageBox(0, PChar('Error opening destination file for writing!'#13'[' + SysErrorMessage(GetLastError) + '].'), 'Backup Error', MB_OK or MB_ICONERROR or MB_TASKMODAL or MB_SETFOREGROUND);
      Exit;
    end;
    try
      N := FileWrite(H, DestSec, SECTOR_SIZE);
      if N <> SECTOR_SIZE then
      begin
        MessageBox(0, PChar('Error writing to destination file!'#13'[' + SysErrorMessage(GetLastError) + '].'), 'Backup Error', MB_OK or MB_ICONERROR or MB_TASKMODAL or MB_SETFOREGROUND);
        Exit;
      end;
    finally
      FileClose(H);
    end;
    MessageBox(0, 'MBR sector is successfully backed up!', 'Backup Complete', MB_OK or MB_ICONINFORMATION or MB_TASKMODAL or MB_SETFOREGROUND);
  end; // if CheckBackup.Checked

  ////////////////////////////////////////////////////////////////////////////////
  // Replace MBR sector
  if CheckReplace.Checked then
  begin
    // Check drive
    UpdateDiskDrives;
    if (DriveN <> LastDriveNum) or (DriveName <> LastDriveName) then
    begin
      MessageBox(0, 'Selected device is absent!', 'Replace Error', MB_OK or MB_ICONERROR or MB_TASKMODAL or MB_SETFOREGROUND);
      Exit;
    end;

    // Read sector from file
    Filename := EditReplace.Text;
    H := FileOpen(Filename, fmOpenRead);
    if H = INVALID_HANDLE_VALUE then
    begin
      MessageBox(0, PChar('Error opening source file for reading!'#13'[' + SysErrorMessage(GetLastError) + '].'), 'Replace Error', MB_OK or MB_ICONERROR or MB_TASKMODAL or MB_SETFOREGROUND);
      Exit;
    end;
    try
      N := FileRead(H, SrcSec, SECTOR_SIZE);
      if N <> SECTOR_SIZE then
      begin
        if N = -1 then  // error
          MessageBox(0, PChar('Error reading from source file!'#13'[' + SysErrorMessage(GetLastError) + '].'), 'Replace Error', MB_OK or MB_ICONERROR or MB_TASKMODAL or MB_SETFOREGROUND)
        else
          MessageBox(0, 'Source file size is less than 512 bytes.', 'Replace Error', MB_OK or MB_ICONERROR or MB_TASKMODAL or MB_SETFOREGROUND);
        Exit;
      end;
      N := FileSeek(H, 0, 2);
      if N = -1 then S := 'may be' else S := 'is';
      if (N <> SECTOR_SIZE) and (MessageBox(0, PChar('Source file size ' + S + ' more than 512 bytes.'#13'Continue and still use it?'),
                                               'Replace Warning', MB_YESNO or MB_ICONWARNING or MB_TASKMODAL or MB_SETFOREGROUND) <> IDYES) then
        Exit;
    finally
      FileClose(H);
    end;

    // Read original sector from drive
    H := CreateFile(PChar(DRIVE_NAME_PREFIX + IntToStr(DriveN)), GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
    if H = INVALID_HANDLE_VALUE then
    begin
      MessageBox(0, PChar('Error opening selected drive for reading and writing!'#13'[' + SysErrorMessage(GetLastError) + '].'), 'Replace Error', MB_OK or MB_ICONERROR or MB_TASKMODAL or MB_SETFOREGROUND);
      Exit;
    end;
    try
      if (not ReadFile(H, DestSec, SECTOR_SIZE, Ret, nil)) or (Ret <> SECTOR_SIZE) then
      begin
        MessageBox(0, PChar('Error reading from selected drive!'#13'[' + SysErrorMessage(GetLastError) + '].'), 'Replace Error', MB_OK or MB_ICONERROR or MB_TASKMODAL or MB_SETFOREGROUND);
        Exit;
      end;

      // Copy sector content
      case ComboReplaceType.ItemIndex of
        1: // bootstrap code only
        begin
          Move(SrcSec, DestSec, PART_TABLE_OFFSET);  // code
          Move(SrcSec[510], DestSec[510], 2);        // signature
          if CheckReplaceClear.Checked then
            FillChar(DestSec[PART_TABLE_OFFSET], PART_TABLE_SIZE, 0);  // clear partition table
        end;
        2: // partition table only
        begin
          Move(SrcSec[PART_TABLE_OFFSET], DestSec[PART_TABLE_OFFSET], PART_TABLE_SIZE);
          if CheckReplaceClear.Checked then
            FillChar(DestSec, PART_TABLE_OFFSET, 0);  // clear code
        end;
        else {0} // entire MBR sector
          Move(SrcSec, DestSec, SECTOR_SIZE);
      end; // case

      if (PWord(@DestSec[510])^ <> $AA55) and
        (MessageBox(0, 'Replacing sector has invalid signature (not 0x55,0xAA)!'#13'Continue and still use it?',
                       'Replace Warning', MB_YESNO or MB_ICONWARNING or MB_TASKMODAL or MB_SETFOREGROUND) <> IDYES) then
        Exit;

      // Check partition table
      if CheckWarnBoot.Checked then
      begin
        FillChar(DiskGeometryEx, SizeOf(DiskGeometryEx), 0);
        if not DeviceIoControl(H, IOCTL_DISK_GET_DRIVE_GEOMETRY_EX, nil, 0, @DiskGeometryEx, SizeOf(DiskGeometryEx), Ret, nil) then
        begin
          if not MessageBox(0, PChar('Error requesting drive geometry!'#13'[' + SysErrorMessage(GetLastError) + '].'#13#13 +
                               'Partition table check may be incomplete!'#13'Continue checking and replacing?'),
                               'Replace Warning', MB_YESNO or MB_ICONWARNING or MB_TASKMODAL or MB_SETFOREGROUND) <> IDYES then
            Exit;
          with DiskGeometryEx, Geometry do
          begin
            SectorsPerTrack := 63;
            TracksPerCylinder := 255;
              Cylinders := $100000;
            DiskSize := Cylinders * TracksPerCylinder * SectorsPerTrack * SECTOR_SIZE;  // > 2 shl 32
          end;
        end; // if not DeviceIoControl
        Total := DiskGeometryEx.DiskSize div SECTOR_SIZE;  // total number of sector
        PartTblChk := ptEmpty;
        for i := 0 to PART_TABLE_SIZE-1 do
          if DestSec[PART_TABLE_OFFSET + i] <> 0 then
          begin
            PartTblChk := ptOk;
            Break;
          end;
        if PartTblChk <> ptEmpty then
          for i := 0 to 3 do
          begin
            Part1 := PDWORD(@DestSec[PART_TABLE_OFFSET + i*16+8])^;
            Part2 := PDWORD(@DestSec[PART_TABLE_OFFSET + i*16+12])^;  // sector number behind the last partition sector
            LBA1 := CHStoLBA(DestSec[PART_TABLE_OFFSET + i*16+3] + (DestSec[PART_TABLE_OFFSET + i*16+2] and $C0) shl 2,  // cylinder
                             DestSec[PART_TABLE_OFFSET + i*16+1],  // head
                             DestSec[PART_TABLE_OFFSET + i*16+2] and 63,  // sector
                             DiskGeometryEx.Geometry);
            LBA2 := CHStoLBA(DestSec[PART_TABLE_OFFSET + i*16+7] + (DestSec[PART_TABLE_OFFSET + i*16+6] and $C0) shl 2,  // cylinder
                             DestSec[PART_TABLE_OFFSET + i*16+5],  // head
                             DestSec[PART_TABLE_OFFSET + i*16+6] and 63,  // sector
                             DiskGeometryEx.Geometry);
            if (Part2 <> $FFFFFFFF) and ((Int64(Part1)+Part2 > Total) or (LBA2 >= Total)) then PartTblChk := ptLarge;
            if (LBA1 = -1) and (LBA2 = -1) then Error := False
            else Error := (LBA1 < 0) or (LBA2 < 0) or (LBA1 > LBA2);
            N := DestSec[PART_TABLE_OFFSET + i*16];  // activity flag
            Error := Error or ( not (N in [0, $80]) );
            Error := Error or ( ((N = $80) or (DestSec[PART_TABLE_OFFSET + i*16+4] <> 0) or (Part1 <> 0)) and (Part2 = 0) );
            if Error then
            begin
              PartTblChk := ptError;
              Break;
            end;
          end; // for i
        if PartTblChk <> ptOk then
        begin
          case PartTblChk of
            ptEmpty: S := 'is EMPTY';
            ptLarge: S := 'has TOO LARGE entries';
            else {ptError} S := 'is INCORRECT';
          end;
          if MessageBox(0, PChar('Partition table ' + S + ' (drive may be determined as floppy when booting as "USB HDD/FDD" on some BIOSes)!'#13'Continue replacing?'),
                           'Replace Warning', MB_YESNO or MB_ICONWARNING or MB_TASKMODAL or MB_SETFOREGROUND) <> IDYES then
            Exit;
        end;
      end; // if CheckWarnBoot.Checked

      // Write sector to drive
      if SetFilePointer(H, 0, nil, FILE_BEGIN) <> 0 then
      begin
        MessageBox(0, PChar('Error seeking selected drive before writing!'#13'[' + SysErrorMessage(GetLastError) + '].'), 'Replace Error', MB_OK or MB_ICONERROR or MB_TASKMODAL or MB_SETFOREGROUND);
        Exit;
      end;

      if (not WriteFile(H, DestSec, SECTOR_SIZE, Ret, nil)) or (Ret <> SECTOR_SIZE) then
      begin
        MessageBox(0, PChar('Error writing to selected drive!'#13'[' + SysErrorMessage(GetLastError) + '].'), 'Replace Error', MB_OK or MB_ICONERROR or MB_TASKMODAL or MB_SETFOREGROUND);
        Exit;
      end;
    finally
      CloseHandle(H);
    end;
    MessageBox(0, 'MBR sector is successfully replaced!', 'Replace Complete', MB_OK or MB_ICONINFORMATION or MB_TASKMODAL or MB_SETFOREGROUND);
  end; // if CheckReplace.Checked
end; // ButtonStartClick

procedure TFormMain.ButtonBackupSaveDestHelpClick(Sender: TObject);
begin
  MessageBox(0, 'If this "Save..." option is checked and backup destination file exists then MBR sector '+
                '(or part of MBR) is backed up without erasing other content of this destination file.',
                'Backup Option Info', MB_OK or MB_ICONINFORMATION or MB_TASKMODAL or MB_SETFOREGROUND);
end;

procedure TFormMain.ButtonWarnBootHelpClick(Sender: TObject);
begin
  MessageBox(0, 'Some BIOSes can offer to boot from "USB HDD/FDD" drive (using only such combined name, not "USB HDD" ' +
                'or "USB FDD" separately). Drive type (HDD or floppy) may be determined based on the first physical ' +
                'sector content, in particular depending on the correctness of the partition table. If this sector ' +
                'is determined as floppy boot-sector (not as HDD MBR) then some bytes in bootstrap code can be zeroed ' +
                'before execution for further correct work (e.g. bytes at offsets 0x1C...0x1F and 0x24).'#13#13+
                'I don''t guarantee that any BIOS determines sector type in the same way as this program does. '+
                'But you will see the warning message if this "Check..." option will be checked and partition table '+
                'of replacing MBR sector will be not correct.',
                'Replace Option Info', MB_OK or MB_ICONINFORMATION or MB_TASKMODAL or MB_SETFOREGROUND);
end;

procedure TFormMain.ComboBackupTypeChange(Sender: TObject);
begin
  CheckBackupClear.Checked := False;
  SetEnables;
end;

procedure TFormMain.ComboReplaceTypeChange(Sender: TObject);
begin
  CheckReplaceClear.Checked := False;
  SetEnables;
end;

procedure TFormMain.CheckBackupSaveDestClick(Sender: TObject);
begin
  CheckBackupClear.Checked := False;
  SetEnables;
end;

end.
