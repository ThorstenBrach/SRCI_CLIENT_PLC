{attribute 'pack_mode' := '1'}
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      MoveDirectCamRecvData
//  Author:      Thorsten Brach
//  Date:        2026-10-25
//
//  Description:
//    Received CMD payload of MoveDirectCam (spec table 6-555).
//    F109: new data type (SRCI command 2401 MoveDirectCam, spec 6.4.9)
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
TYPE MoveDirectCamRecvData EXTENDS RspHeader :
STRUCT
  /// Percentage of already traversed distance of current job.
  /// If not supported : • -1
  Progress          : UINT;
  /// Distance-to-go of the current job.
  /// • -1: No valid value because move command is not yet active (valid values are pending) or not supported by RC
  /// • >0: Actual distance between current and target position
  /// •  0: Target position reached
  RemainingDistance  : REAL;
END_STRUCT
END_TYPE


