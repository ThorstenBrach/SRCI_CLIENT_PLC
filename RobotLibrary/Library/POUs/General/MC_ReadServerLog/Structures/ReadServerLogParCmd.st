{attribute 'pack_mode' := '1'}
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      ReadServerLogParCmd
//  Author:      Thorsten Brach
//  Date:        2026-10-23
//
//  Description:
//    Parameters of ReadServerLog (spec 6.2.6, table 6-119).
//
//  Copyright:
//    (C) 2026 Thorsten Brach. All rights reserved
//             Licensed under the MIT License.
//
//  Disclaimer:
//    This project is provided without any guarantee and can be used for
//    private and commercial purposes. Any use is at the user's
//    own risk and responsibility.
//
// -------------------------------------------------------------------------
TYPE ReadServerLogParCmd :
STRUCT
  /// ID of the requested server log
  /// • -1 (default): latest server log
  /// •  0: oldest server log (SRCI SDK 1.1; spec table 6-119: 1)
  /// • >0: server log with this ID (OutCmd.ServerLogID of CreateServerLog)
  ServerLogID   : INT := -1;
  /// First log line of the requested log that is transferred to the PLC (1: log header)
  StartLine     : UDINT := 1;
  /// Only log lines of these contexts (spec table 6-118); all 0: no filter
  ContextFilter : ARRAY [0..9] OF USINT;
  /// Target of the log: 0 = output LogFile (default), 1 = export to a file (not supported)
  ExportMode    : USINT;
  /// File name of the export (ExportMode 1)
  ExportName    : STRING(20);
END_STRUCT
END_TYPE


