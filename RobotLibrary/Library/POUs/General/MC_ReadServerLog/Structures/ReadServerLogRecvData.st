{attribute 'pack_mode' := '1'}
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      ReadServerLogRecvData
//  Author:      Thorsten Brach
//  Date:        2026-10-23
//
//  Description:
//    Received CMD payload of ReadServerLog in the layout of SRCI SDK 1.1.2 (spec table 6-124:
//    only IsSplitLine, no EndOfLogReached / LogLine / Offset, 187 characters).
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
TYPE ReadServerLogRecvData EXTENDS RspHeader :
STRUCT
  /// Total number of log lines in the requested log
  AvailableLogLines         : UDINT;
  /// Number of log lines after the ContextFilter
  AvailableFilteredLogLines : UDINT;
  /// Number of characters in LogContent
  LogContentLength          : USINT;
  /// Byte 13 Bit 0: LogContent starts a log line
  IsStartOfLine             : BOOL;
  /// Byte 13 Bit 1: LogContent ends a log line
  IsEndOfLine               : BOOL;
  /// Byte 13 Bit 2: the last log line was transmitted
  EndOfLogReached           : BOOL;
  /// Number of the transmitted log line
  LogLine                   : UDINT;
  /// Request counter of the command this response belongs to
  Offset                    : UDINT;
  /// Part of the log line (CSV)
  LogContent                : STRING(RobotLibraryConstants.SERVER_LOG_CONTENT_MAX);
END_STRUCT
END_TYPE


