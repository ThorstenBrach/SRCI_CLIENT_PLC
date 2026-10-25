{attribute 'pack_mode' := '1'}
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      ReadServerLogOutCmd
//  Author:      Thorsten Brach
//  Date:        2026-10-23
//
//  Description:
//    Results of ReadServerLog (spec 6.2.6, table 6-120).
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
TYPE ReadServerLogOutCmd :
STRUCT
  /// Total number of log lines in the requested log
  AvailableLogLines         : UDINT;
  /// Number of log lines in the requested log after the ContextFilter
  AvailableFilteredLogLines : UDINT;
  /// Number of log lines received and stored in LogFile (spec table 6-120: USINT)
  ReceivedLogLines          : UDINT;
  /// Received log lines compared to AvailableFilteredLogLines [%]
  Progress                  : REAL;
  /// The last log line of the requested log was transmitted
  EndOfLogReached           : BOOL;
  /// Number of the log line received last
  LogLine                   : UDINT;
END_STRUCT
END_TYPE


