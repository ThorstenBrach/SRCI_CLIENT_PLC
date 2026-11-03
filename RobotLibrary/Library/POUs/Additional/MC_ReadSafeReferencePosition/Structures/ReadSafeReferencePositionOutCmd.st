{attribute 'pack_mode' := '1'}
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      ReadSafeReferencePositionOutCmd
//  Author:      Thorsten Brach
//  Date:        2026-10-25
//
//  Description:
//    Outputs of ReadSafeReferencePosition (spec table 6-828).
//    F109: new data type (SRCI command 7009 ReadSafeReferencePosition, spec 6.5.38)
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
TYPE ReadSafeReferencePositionOutCmd :
STRUCT
  /// Number of existing reference positions on the RC; 0 if no position is defined
  NumberOfPositions : USINT;
  /// Absolute safe reference position of the robot in joint position
  /// • J1..J6: Position [°] of the joints of the robot
  /// • E1..E6: Position of the external axes
  Position          : RobotJointPosition;
END_STRUCT
END_TYPE


