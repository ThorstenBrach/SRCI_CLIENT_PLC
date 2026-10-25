{attribute 'pack_mode' := '1'}
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      CreateServerLogOutCmd
//  Author:      Thorsten Brach
//  Date:        2026-10-23
//
//  Description:
//    Results of CreateServerLog (spec 6.2.5, table 6-113).
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
TYPE CreateServerLogOutCmd :
STRUCT
  /// Relates to ListenerID >0
  /// Number of successful trigger-based command invocations
  /// For more information refer to chapter 5.5.12.4.
  InvocationCounter : USINT;
  /// Unique system-generated ID of the "Action" when the function is triggered.
  /// • >0: The "Action" is started by the trigger function with identical FollowID.
  /// • <0: The "Action" is stopped by the trigger function with identical FollowID.
  /// For more information see chapter 5.5.12.4 EmitterID, ListenerID, FollowID and OriginID
  OriginID          : INT;
  /// ID of the newly created server log (input ServerLogID of ReadServerLog)
  ServerLogID       : INT;
END_STRUCT
END_TYPE


