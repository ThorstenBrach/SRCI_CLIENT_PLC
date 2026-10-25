{attribute 'pack_mode' := '1'}
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      CreateServerLogSendData
//  Author:      Thorsten Brach
//  Date:        2026-10-23
//
//  Description:
//    Sent CMD payload of CreateServerLog (spec table 6-116, trigger header table 5-73).
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
TYPE CreateServerLogSendData EXTENDS CmdHeader :
STRUCT
  /// ID of Action that will be executed when this command is active (always 0)
  EmitterID  : ARRAY [0..3] OF SINT;
  /// ID of associated trigger function:
  /// •  0: No Trigger (default)  No trigger related behavior
  /// • >0: Trigger - Start executing when the trigger function with the identical EmitterID is triggered.
  /// Always positive.
  /// For more information, see chapter 5.5.12 Triggers
  ListenerID : SINT;
  /// Reserve
  Reserve    : BYTE;
END_STRUCT
END_TYPE


