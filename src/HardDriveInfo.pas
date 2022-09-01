(******************************************************************************

The MIT License (MIT)

Copyright © 2020 Евгений Красников (Eugene Krasnikov aka Jin X)

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

// HardDriveInfo unit for [mbrset] (c) 2020 by Jin X

unit HardDriveInfo;

{$Z4}

interface

uses Windows;

const
  DRIVE_NAME_PREFIX = '\\.\PhysicalDrive';
  MAX_PARTITION_COUNT = 16;

  FILE_DEVICE_DISK = $00000007;
  FILE_ANY_ACCESS = 0;
  METHOD_BUFFERED = 0;

  IOCTL_DISK_BASE = FILE_DEVICE_DISK;
  IOCTL_DISK_GET_DRIVE_GEOMETRY_EX = (IOCTL_DISK_BASE shl 16) or (FILE_ANY_ACCESS shl 14) or ($0028 shl 2) or (METHOD_BUFFERED);
  IOCTL_DISK_GET_DRIVE_LAYOUT_EX = (IOCTL_DISK_BASE shl 16) or (FILE_ANY_ACCESS shl 14) or ($0014 shl 2) or (METHOD_BUFFERED);

  FILE_DEVICE_MASS_STORAGE = $0000002d;
  IOCTL_STORAGE_BASE = FILE_DEVICE_MASS_STORAGE;
  IOCTL_STORAGE_GET_DEVICE_NUMBER = (IOCTL_STORAGE_BASE shl 16) or (FILE_ANY_ACCESS shl 14) or ($0420 shl 2) or (METHOD_BUFFERED);
  IOCTL_STORAGE_QUERY_PROPERTY = (IOCTL_STORAGE_BASE shl 16) or (FILE_ANY_ACCESS shl 14) or ($0500 shl 2) or (METHOD_BUFFERED);

  IOCTL_VOLUME_BASE = $00000056;
  IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS = (IOCTL_VOLUME_BASE shl 16) or (FILE_ANY_ACCESS shl 14) or (0 shl 2) or (METHOD_BUFFERED);

  SetupApiModuleName = 'setupapi.dll';
  GUID_DEVINTERFACE_DISK = '{53F56307-B6BF-11D0-94F2-00A0C91EFB8B}';
  DIGCF_DEFAULT         = $00000001; // only valid with DIGCF_DEVICEINTERFACE
  DIGCF_PRESENT         = $00000002;
  DIGCF_ALLCLASSES      = $00000004;
  DIGCF_PROFILE         = $00000008;
  DIGCF_DEVICEINTERFACE = $00000010;

type
  ULONG_PTR = NativeUInt;
  
  TStorageDeviceNumber = record
    DeviceType: DWORD;
    DeviceNumber: DWORD;
    PartitionNumber: DWORD;
  end;

  TMediaType = (
    mtUnknown,         // Format is unknown
    mtF5_1Pt2_512,     // 5.25", 1.2MB,  512 bytes/sector
    mtF3_1Pt44_512,    // 3.5",  1.44MB, 512 bytes/sector
    mtF3_2Pt88_512,    // 3.5",  2.88MB, 512 bytes/sector
    mtF3_20Pt8_512,    // 3.5",  20.8MB, 512 bytes/sector
    mtF3_720_512,      // 3.5",  720KB,  512 bytes/sector
    mtF5_360_512,      // 5.25", 360KB,  512 bytes/sector
    mtF5_320_512,      // 5.25", 320KB,  512 bytes/sector
    mtF5_320_1024,     // 5.25", 320KB,  1024 bytes/sector
    mtF5_180_512,      // 5.25", 180KB,  512 bytes/sector
    mtF5_160_512,      // 5.25", 160KB,  512 bytes/sector
    mtRemovableMedia,  // Removable media other than floppy
    mtFixedMedia,      // Fixed hard disk media
    mtF3_120M_512,     // 3.5", 120M Floppy
    mtF3_640_512,      // 3.5" ,  640KB,  512 bytes/sector
    mtF5_640_512,      // 5.25",  640KB,  512 bytes/sector
    mtF5_720_512,      // 5.25",  720KB,  512 bytes/sector
    mtF3_1Pt2_512,     // 3.5" ,  1.2Mb,  512 bytes/sector
    mtF3_1Pt23_1024,   // 3.5" ,  1.23Mb, 1024 bytes/sector
    mtF5_1Pt23_1024,   // 5.25",  1.23MB, 1024 bytes/sector
    mtF3_128Mb_512,    // 3.5" MO 128Mb   512 bytes/sector
    mtF3_230Mb_512,    // 3.5" MO 230Mb   512 bytes/sector
    mtF8_256_128,      // 8",     256KB,  128 bytes/sector
    mtF3_200Mb_512,    // 3.5",   200M Floppy (HiFD)
    mtF3_240M_512,     // 3.5",   240Mb Floppy (HiFD)
    mtF3_32M_512       // 3.5",   32Mb Floppy
  );

  TDiskGeometry = record
    Cylinders: UInt64;
    MediaType: TMediaType;
    TracksPerCylinder: ULONG;
    SectorsPerTrack: ULONG;
    BytesPerSector: ULONG;
  end;

  TPartitionStyle = (
    PARTITION_STYLE_MBR,
    PARTITION_STYLE_GPT,
    PARTITION_STYLE_RAW
  );

  TDiskId = record
    case Byte of
      0: (Signature: ULONG;
          CheckSum: ULONG);
      1: (DiskId: TGUID);
  end;

  TDiskPartitionInfo = record
    SizeOfPartitionInfo: ULONG;
    PartitionStyle: TPartitionStyle;
    DiskId: TDiskId;
  end;

  TDetectionType = (
    DetectNone,
    DetectInt13,
    DetectExInt13);

  TDiskInt13Info = record
    DriveSelect: Word;
    MaxCylinders: DWORD;
    SectorsPerTrack: Word;
    MaxHeads: Word;
    NumberDrives: Word;
  end;

  TDiskExInt13Info = record
    ExBufferSize: Word;
    ExFlags: Word;
    ExCylinders: DWORD;
    ExHeads: DWORD;
    ExSectorsPerTrack: DWORD;
    ExSectorsPerDrive: UINT;
    ExSectorSize: Word;
    ExReserved: Word;
  end;

  TDiskDetectionInfo = record
    SizeOfDetectInfo: ULONG;
    DetectionType: TDetectionType;
    Int13: TDiskInt13Info;
    ExInt13: TDiskExInt13Info;
  end;

  TDiskGeometryEx = record
    Geometry: TDiskGeometry;
    DiskSize: UInt64;
    DiskPartitionInfo: TDiskPartitionInfo;
    DiskDetectionInfo: TDiskDetectionInfo;
  end;

  TDiskGeometryExMbr = record
    Geometry: TDiskGeometry;
    DiskSize: UInt64;
    DiskPartitionInfo: record
      SizeOfPartitionInfo: ULONG;
      DiskId: record
        PartitionStyle: record
          Signature: ULONG;
          CheckSum: ULONG;
        end;
      end;
    end;
    DiskDetectionInfo: TDiskDetectionInfo;
  end;
  PDiskGeometryExMbr = ^TDiskGeometryExMbr;

  TDriveLayoutInformationMbr = record
    Signature: DWORD;
    CheckSum: DWORD;
  end;

  TDriveLayoutInformationGpt = record
    DiskId: TGUID;
    StartingUsableOffset: UInt64;
    UsableLength: UInt64;
    MaxPartitionCount: DWORD;
  end;

  TDriveLayoutInformationUnion = record
    case Byte of
    0: (Mbr: TDriveLayoutInformationMbr);
    1: (Gpt: TDriveLayoutInformationGpt);
  end;

  TPartitionInformationMbr = record
    PartitionType: Byte;
    BootIndicator: Boolean;
    RecognizedPartition: Boolean;
    HiddenSectors: DWORD;
    PartitionId: TGUID;
  end;

  TPartitionInformationGpt = record
    PartitionType: TGUID;
    PartitionId: TGUID;
    Attributes: UInt64;
    Name: array [0..35] of WideChar;
  end;

  TPartitionInformationEx = record
    PartitionStyle: TPartitionStyle;
    StartingOffset: UInt64;
    PartitionLength: UInt64;
    PartitionNumber: DWORD;
    RewritePartition: Boolean;
    IsServicePartition: Boolean;
    case Byte of
      0: (Mbr: TPartitionInformationMbr);
      1: (Gpt: TPartitionInformationGpt);
  end;

  TDriveLayoutInformationEx = record
    PartitionStyle: TPartitionStyle;
    PartitionCount: DWORD;
    Layout: TDriveLayoutInformationUnion;
    PartitionEntry: array [1..MAX_PARTITION_COUNT] of TPartitionInformationEx;
  end;

  // https://docs.microsoft.com/en-us/windows/win32/api/winioctl/ne-winioctl-storage_property_id
  TStoragePropertyId = (
    StorageDeviceProperty,
    StorageAdapterProperty,
    StorageDeviceIdProperty,
    StorageDeviceUniqueIdProperty,
    StorageDeviceWriteCacheProperty,
    StorageMiniportProperty,
    StorageAccessAlignmentProperty,
    StorageDeviceSeekPenaltyProperty,
    StorageDeviceTrimProperty,
    StorageDeviceWriteAggregationProperty,
    StorageDeviceDeviceTelemetryProperty,
    StorageDeviceLBProvisioningProperty,
    StorageDevicePowerProperty,
    StorageDeviceCopyOffloadProperty,
    StorageDeviceResiliencyProperty,
    StorageDeviceMediumProductType,
    StorageAdapterRpmbProperty,
    StorageAdapterCryptoProperty,
    StorageDeviceIoCapabilityProperty,
    StorageAdapterProtocolSpecificProperty,
    StorageDeviceProtocolSpecificProperty,
    StorageAdapterTemperatureProperty,
    StorageDeviceTemperatureProperty,
    StorageAdapterPhysicalTopologyProperty,
    StorageDevicePhysicalTopologyProperty,
    StorageDeviceAttributesProperty,
    StorageDeviceManagementStatus,
    StorageAdapterSerialNumberProperty,
    StorageDeviceLocationProperty,
    StorageDeviceNumaProperty,
    StorageDeviceZonedDeviceProperty,
    StorageDeviceUnsafeShutdownCount,
    StorageDeviceEnduranceProperty
  );

  TStorageQueryType = (PropertyStandardQuery, PropertyExistsQuery);

  TStoragePropertyQuery = record
    PropertyId: TStoragePropertyId;
    QueryType: TStorageQueryType;
    AdditionalParameters: array [0..0] of Byte;
  end;

  TStorageDescriptorHeader = record
    Version: DWORD;
    Size: DWORD;
  end;

  TStorageBusType = (
    BusTypeUnknown,  // Unknown bus type
    BusTypeScsi,     // SCSI bus
    BusTypeAtapi,    // ATAPI bus
    BusTypeAta,      // ATA bus
    BusType1394,     // IEEE-1394 bus
    BusTypeSsa,      // SSA bus
    BusTypeFibre,    // Fibre Channel bus
    BusTypeUsb,      // USB bus
    BusTypeRAID,     // RAID bus
    BusTypeiScsi,
    BusTypeSas,      // Serial Attached SCSI (SAS) bus
    BusTypeSata,     // SATA bus
    BusTypeSd,
    BusTypeMmc,
    BusTypeVirtual,
    BusTypeFileBackedVirtual,
    BusTypeSpaces,
    BusTypeNvme,
    BusTypeSCM,
    BusTypeUfs,
    BusTypeMax,
    BusTypeMaxReserved
  );

  TStorageDeviceDescriptor = record
    Version: DWORD;
    Size: DWORD;
    DeviceType: Byte;
    DeviceTypeModifier: Byte;
    RemovableMedia: Boolean;
    CommandQueueing: Boolean;
    VendorIdOffset: DWORD;
    ProductIdOffset: DWORD;
    ProductRevisionOffset: DWORD;
    SerialNumberOffset: DWORD;
    BusType: TStorageBusType;
    RawPropertiesLength: DWORD;
    RawDeviceProperties: array [0..0] of Byte;
  end;
  PStorageDeviceDescriptor = ^TStorageDeviceDescriptor;

  HDEVINFO = Pointer;

  SP_DEVICE_INTERFACE_DATA = record
    cbSize: Cardinal;
    InterfaceClassGuid: TGUID;
    Flags: Cardinal;
    Reserved: ULONG_PTR;
  end;
  _SP_DEVICE_INTERFACE_DATA = SP_DEVICE_INTERFACE_DATA;
  PSP_DEVICE_INTERFACE_DATA = ^SP_DEVICE_INTERFACE_DATA;

  SP_DEVICE_INTERFACE_DETAIL_DATA = record
      cbSize: Cardinal;
      DevicePath: array [0..0] of WideChar;
  end;
  _SP_DEVICE_INTERFACE_DETAIL_DATA = SP_DEVICE_INTERFACE_DETAIL_DATA;
  PSP_DEVICE_INTERFACE_DETAIL_DATA = ^SP_DEVICE_INTERFACE_DETAIL_DATA;

  SP_DEVINFO_DATA = record
    cbSize: Cardinal;
    ClassGuid: TGUID;
    DevInst: Cardinal;
    Reserved: ULONG_PTR;
  end;
  PSP_DEVINFO_DATA = ^SP_DEVINFO_DATA;

function GetVolumePathNamesForVolumeName(lpszVolumeName: LPCSTR; lpszVolumePathNames: LPSTR;
  cchBufferLength: DWORD; var lpcchReturnLength: DWORD): BOOL; stdcall; external kernel32 name 'GetVolumePathNamesForVolumeNameA';

function SetupDiGetClassDevs(ClassGuid: PGUID; const Enumerator: PWideChar;
  hwndParent: HWND; Flags: Cardinal): HDEVINFO; stdcall; external SetupApiModuleName name 'SetupDiGetClassDevsW';

function SetupDiEnumDeviceInterfaces(DeviceInfoSet: HDEVINFO; DeviceInfoData: Pointer; const InterfaceClassGuid: PGUID;
  MemberIndex: Cardinal;
  var DeviceInterfaceData: SP_DEVICE_INTERFACE_DATA): BOOL; stdcall; external SetupApiModuleName name 'SetupDiEnumDeviceInterfaces';

function SetupDiGetDeviceInterfaceDetail(DeviceInfoSet: HDEVINFO;
  var DeviceInterfaceData: SP_DEVICE_INTERFACE_DATA;
  DeviceInterfaceDetailData: PSP_DEVICE_INTERFACE_DETAIL_DATA;
  DeviceInterfaceDetailDataSize: Cardinal; RequiredSize: PCardinal;
  Device: PSP_DEVINFO_DATA): BOOL; stdcall; external SetupApiModuleName name 'SetupDiGetDeviceInterfaceDetailW';

function SetupDiDestroyDeviceInfoList(
  DeviceInfoSet: HDEVINFO): BOOL; stdcall; external SetupApiModuleName name 'SetupDiDestroyDeviceInfoList';

implementation

end.
