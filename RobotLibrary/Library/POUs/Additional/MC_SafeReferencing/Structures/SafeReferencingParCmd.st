{attribute 'pack_mode' := '1'}
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      SafeReferencingParCmd
//  Author:      Thorsten Brach
//  Date:        2026-10-25
//
//  Description:
//    Parameters of SafeReferencing (spec table 6-833).
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
TYPE SafeReferencingParCmd :
STRUCT
  /// Absolute safe referencing position of the robot in joint position
  /// • J1..J6: Position [°] of the joints of the robot
  /// • E1..E6: Position of the external axes
  JointPosition    : RobotJointPosition;
  /// Maximum permissible distance [mm] between the current TCP location and the target position
  /// defined via "JointPosition" (sphere around "JointPosition"):
  /// • <0 (default): Do not use a maximum distance
  /// •  0: Current position and "JointPosition" must be identical
  /// • >0: Use the parameter value as maximum distance
  MaximumDistance  : REAL := -1.0;
  /// Velocity of the movement in % of nominal velocity
  /// •  <0%: (default) - Use default velocity
  /// •   0%:           - Use internal minimal velocity
  /// • 100%:           - Use maximal reference velocity
  /// See chapter 5.5.7 Robot dynamics
  VelocityRate     : REAL := -1.0;
  /// Acceleration of the movement in % of nominal acceleration
  /// •  <0%: (default) - Use default acceleration
  /// •   0%:           - Use internal minimal acceleration
  /// • 100%:           - Use maximal reference acceleration
  /// See chapter 5.5.7 Robot dynamics
  AccelerationRate : REAL := -1.0;
  /// Deceleration of the movement in % of nominal deceleration
  /// •  <0%: (default) - Use default deceleration
  /// •   0%:           - Use internal minimal deceleration
  /// • 100%:           - Use maximal reference deceleration
  /// See chapter 5.5.7 Robot dynamics
  DecelerationRate : REAL := -1.0;
  /// Jerk of the movement in % of nominal jerk
  /// •  <0%: (default) - Use default jerk
  /// •   0%:           - Use internal minimal jerk
  /// • 100%:           - Use maximal reference jerk
  /// See chapter 5.5.7 Robot dynamics
  JerkRate         : REAL := -1.0;
  /// Index of tool
  /// •      0: Flange (default)
  /// • 1..254: Tool frames
  ToolNo           : USINT;
  /// Parameter is used if it is greater than 0 (default)
  /// • Velocity input is ignored
  /// • Parameter defines the time for the movement to reach the target position
  /// Error is sent by the RC if the time cannot be kept
  MoveTime         : TIME;
END_STRUCT
END_TYPE


