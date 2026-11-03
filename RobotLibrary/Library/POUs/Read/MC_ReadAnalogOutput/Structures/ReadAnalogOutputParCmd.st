{attribute 'pack_mode' := '1'}
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      ReadAnalogOutputParCmd
//  Author:      Thorsten Brach
//  Date:        2026-10-25
//
//  Description:
//    Parameters of ReadAnalogOutput (spec table 6-571).
//    F109: new data type (SRCI command 6108 ReadAnalogOutput, spec 6.4.12)
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
TYPE ReadAnalogOutputParCmd :
STRUCT
  /// Number of the analog output 1..32
  Index              : USINT;
  /// ID of associated trigger function:
  /// •  0: No Trigger (default)  No trigger related behavior
  /// • >0: Trigger - Start executing when the trigger function with the identical EmitterID is triggered.
  /// Always positive.
  /// For more information, see chapter 5.5.12 Triggers
  ListenerID         : SINT;
END_STRUCT
END_TYPE


