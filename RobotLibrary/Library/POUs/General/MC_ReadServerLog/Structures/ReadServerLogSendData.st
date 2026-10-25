{attribute 'pack_mode' := '1'}
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      ReadServerLogSendData
//  Author:      Thorsten Brach
//  Date:        2026-10-23
//
//  Description:
//    Sent CMD payload of ReadServerLog in the layout of SRCI SDK 1.1.2 (spec table 6-123
//    without Offset).
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
TYPE ReadServerLogSendData EXTENDS CmdHeader :
STRUCT
  /// Byte 4 Bit 0: TRUE while log lines are transferred
  Enable        : BOOL;
  /// Reserve
  Reserve       : BYTE;
  /// ID of the requested server log (16#FFFF: latest, 0: oldest)
  ServerLogID   : UINT;
  /// First log line of the requested log
  StartLine     : UDINT;
  /// Request counter (SRCI SDK 1.1): every new value requests the next part of the log
  Offset        : UDINT;
  /// Only log lines of these contexts (spec table 6-118)
  ContextFilter : ARRAY [0..9] OF USINT;
END_STRUCT
END_TYPE


