{attribute 'pack_mode' := '1'}
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      ReadSafeReferencePositionRecvData
//  Author:      Thorsten Brach
//  Date:        2026-10-25
//
//  Description:
//    Received CMD payload of ReadSafeReferencePosition (spec table 6-832).
//    ST-FIX F183: the spec table lists ActualCartesianPosition.E2..E6 between J6 and E1, but the
//    function only outputs NumberOfPositions and a RobotJointPosition (copy error in the spec);
//    the SRCI SDK sends E1..E6 directly after J6 (byte 30).
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
TYPE ReadSafeReferencePositionRecvData EXTENDS RspHeader :
STRUCT
  /// Number of existing reference positions on the RC; 0 if no position is defined
  NumberOfPositions    : USINT;
  /// Reserve
  Reserve              : BYTE;
  /// Absolute safe reference position of the robot in joint position
  /// • J1..J6: Position [°] of the joints of the robot
  /// • E1..E6: Position of the external axes
  Position             : RobotJointPosition;
END_STRUCT
END_TYPE


