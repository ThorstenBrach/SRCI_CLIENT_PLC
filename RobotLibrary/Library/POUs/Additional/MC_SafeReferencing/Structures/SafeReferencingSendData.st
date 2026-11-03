{attribute 'pack_mode' := '1'}
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      SafeReferencingSendData
//  Author:      Thorsten Brach
//  Date:        2026-10-25
//
//  Description:
//    Sent CMD payload of SafeReferencing (spec table 6-838).
//    The payload order differs from this structure: Time (bytes 45..46) lies between
//    JointPosition.E1 and JointPosition.E2.
//    F109: new data type (SRCI command 7010 SafeReferencing, spec 6.5.39)
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
TYPE SafeReferencingSendData EXTENDS CmdHeader :
STRUCT
  /// Velocity in % of nominal velocity multiplied by 100 (16#FFFF: default)
  VelocityRate     : UINT;
  /// Acceleration in % of nominal acceleration multiplied by 100 (16#FFFF: default)
  AccelerationRate : UINT;
  /// Deceleration in % of nominal deceleration multiplied by 100 (16#FFFF: default)
  DecelerationRate : UINT;
  /// Jerk in % of nominal jerk multiplied by 100 (16#FFFF: default)
  JerkRate         : UINT;
  /// Index of tool
  ToolNo           : USINT;
  /// Maximum permissible distance [mm] between the current TCP location and the target position
  /// defined via "JointPosition" (sphere around "JointPosition"):
  /// • <0 (default): Do not use a maximum distance
  /// •  0: Current position and "JointPosition" must be identical
  /// • >0: Use the parameter value as maximum distance
  MaximumDistance  : REAL;
  /// Absolute safe referencing position of the robot in joint position
  /// • J1..J6: Position [°] of the joints of the robot
  /// • E1..E6: Position of the external axes
  JointPosition    : RobotJointPosition;
  /// Time [ms] for the movement to reach the target position (0: not used)
  MoveTime         : UINT;
END_STRUCT
END_TYPE


