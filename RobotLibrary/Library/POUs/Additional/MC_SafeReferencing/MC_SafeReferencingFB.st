/// Execute the safe referencing process on the RC
/// F109: new function block (SRCI command 7010 SafeReferencing, spec 6.5.39)
FUNCTION_BLOCK MC_SafeReferencingFB EXTENDS RobotLibraryBaseExecuteFB
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      MC_SafeReferencingFB
//  Author:      Thorsten Brach
//  Date:        2026-10-25
//
//  Description:
//    SafeReferencing (spec 6.5.39, type 7010): the robot moves to the safe referencing position
//    ParCmd.JointPosition and the RC validates the position (sensor or user input). For several
//    reference positions the block is executed once per position; OutCmd.Status returns the state
//    of the referencing process. The command is executed in the sequence buffer (AbortingMode,
//    SequenceFlag).
//    F109: new function block (SRCI command 7010 SafeReferencing, spec 6.5.39)
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
VAR_INPUT
  /// Parameter which determines the behavior towards the previously sent and still active or buffered commands
  AbortingMode       : AbortingMode;
  /// Defines the target sequence in which the command will be executed
  SequenceFlag       : SequenceFlag;
  /// command parameter
  ParCmd             : SafeReferencingParCmd;
END_VAR

VAR_OUTPUT
  /// Command is transferred and confirmed by the RC
  CommandBuffered    : BOOL;
  /// The command takes control of the motion of the according axis group
  Active             : BOOL;
  /// The command was aborted by another command.
  CommandAborted     : BOOL;
  /// TRUE, while command is interrupted during execution and can be continued
  CommandInterrupted : BOOL;
  /// command outputs
  OutCmd             : SafeReferencingOutCmd;
END_VAR

VAR
  /// internal copy of command parameter
 _parCmd             : SafeReferencingParCmd;
  /// command data to send
 _command            : SafeReferencingSendData;
  /// response data received
 _response           : SafeReferencingRecvData;
END_VAR

  SUPER^(AxesGroup := AxesGroup);

END_FUNCTION_BLOCK

METHOD INTERNAL CheckAddParameter : BOOL
VAR_INPUT
  /// Payload pointer
  PayloadPtr : UDINT;
END_VAR
VAR
  /// Payload as byte array
  Payload    : ARRAY [1..SIZEOF(_command)] OF BYTE;
  /// Null Byte array
  Null       : ARRAY [1..SIZEOF(_command)] OF BYTE;
  /// Data length to compare
  DataLen    : UDINT;
END_VAR

  // Payload pointer must be decreased by one byte, because ADR(Payload) is already one byte !
  PayloadPtr := LIMIT (0, PayloadPtr - 1, SIZEOF(Payload) -1);
  // Convert command struct to payload array
  SysDepMemCpy( pDest := ADR(Payload), pSrc := ADR(_command), DataLen := SIZEOF(_command));
  // Calculate the data length to compare - at least one byte must be compared !
  DataLen := LIMIT(1, SIZEOF(Payload) - PayloadPtr, SIZEOF(Payload));
  // Compare Payload-Array with Null-Byte-Array
  CheckAddParameter := SysDepMemCmp( pData1 := ADR(Payload) + PayloadPtr , pData2 := ADR(Null), DataLen := DataLen) <>  RobotLibraryConstants.OK ;
  
  // payload order differs from the structure layout (Time between JointPosition.E1 and E2)
  // -> always add the parameter
  CheckAddParameter := TRUE;

END_METHOD

METHOD PROTECTED CheckFunctionSupported : BOOL
VAR_IN_OUT
  /// Robot assignment of function
  AxesGroup : AxesGroup;
END_VAR

  // SafeReferencing has no bit in "RCSupportedFunctions" (spec table of the supported functions,
  // bytes 0..13): the client sends the command, an RC without this optional function rejects it
  // with an error
  CheckFunctionSupported := TRUE;

END_METHOD

METHOD PROTECTED CheckParameterChanged : BOOL
VAR_IN_OUT
  /// Robot assignment of function
  AxesGroup    : AxesGroup;
END_VAR

  // Check ParCmd Size is > 0, because MemCmp does not work correctly with size = 0
  IF (SIZEOF(ParCmd) = 0) OR (_stepCmd = 0)
  THEN
    RETURN;
  END_IF
  
  // compare memory
  _parameterChanged := ( SysDepMemCmp(pData1 := ADR(ParCmd), pData2 := ADR(_parCmd), DataLen := SIZEOF(ParCmd)) <> RobotLibraryConstants.OK );
  
  // check parameter valid ?
  _parameterValid   := CheckParameterValid( AxesGroup := AxesGroup );
  
  IF ((  _parameterChanged        )  AND
      (  _parameterValid          )) OR
      (  _parameterUpdateInternal )
  THEN
    // Create log entry for parameter changed event
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.DEBUG,
                            MessageCode := 0,
                            MessageText := 'NotifyParameterChanged Event {1}',
                            Para1       :=  '' );
  
    // reset internal flag for send parameter update
   _parameterUpdateInternal := FALSE;
    // update internal copy of parameters
   _parCmd := ParCmd;
    // inc parameter sequence
   _command.ParSeq := _command.ParSeq + 1;
    // update command data
    CommandData := CreateCommandPayload(AxesGroup := AxesGroup); // ( Access via reference to rCommandFB in ACR )
    // notify active command register
    AxesGroup.Acyclic.ActiveCommandRegister.NotifyParameterChanged := _uniqueID;
  END_IF

END_METHOD

METHOD PROTECTED CheckParameterValid : BOOL
VAR_IN_OUT
  /// Robot assignment of function
  AxesGroup : AxesGroup;
END_VAR

  CheckParameterValid := TRUE;
  
  // Check AbortingMode valid ?
  IF (( AbortingMode <> AbortingModeEnum.BUFFER ) AND
      ( AbortingMode <> AbortingModeEnum.ABORT  ))
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_ABORTINGMODE_INVALID, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter AbortingMode = {1}',
                            Para1       := ABORTING_MODE_TO_STRING(AbortingMode));
    RETURN;
  END_IF
  
  
  // Check SequenceFlag valid ?
  IF (( SequenceFlag <> SequenceFlagEnum.PRIMARY_SEQUENCE   ) AND
      ( SequenceFlag <> SequenceFlagEnum.SECONDARY_SEQUENCE ))
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_SEQFLAG_NOT_ALLOWED, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter SequenceFlag = {1}',
                            Para1       := SEQUENCE_FLAG_TO_STRING(SequenceFlag));
    RETURN;
  END_IF
  
  
  // Check ParCmd.JointPosition.J1 valid ?
  IF ( SysDepIsValidReal(ParCmd.JointPosition.J1) = FALSE )
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_INVALID_PAR_CMD, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.JointPosition.J1 = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.JointPosition.J1));
    RETURN;
  END_IF
  
  
  // Check ParCmd.JointPosition.J2 valid ?
  IF ( SysDepIsValidReal(ParCmd.JointPosition.J2) = FALSE )
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_INVALID_PAR_CMD, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.JointPosition.J2 = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.JointPosition.J2));
    RETURN;
  END_IF
  
  
  // Check ParCmd.JointPosition.J3 valid ?
  IF ( SysDepIsValidReal(ParCmd.JointPosition.J3) = FALSE )
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_INVALID_PAR_CMD, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.JointPosition.J3 = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.JointPosition.J3));
    RETURN;
  END_IF
  
  
  // Check ParCmd.JointPosition.J4 valid ?
  IF ( SysDepIsValidReal(ParCmd.JointPosition.J4) = FALSE )
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_INVALID_PAR_CMD, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.JointPosition.J4 = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.JointPosition.J4));
    RETURN;
  END_IF
  
  
  // Check ParCmd.JointPosition.J5 valid ?
  IF ( SysDepIsValidReal(ParCmd.JointPosition.J5) = FALSE )
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_INVALID_PAR_CMD, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.JointPosition.J5 = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.JointPosition.J5));
    RETURN;
  END_IF
  
  
  // Check ParCmd.JointPosition.J6 valid ?
  IF ( SysDepIsValidReal(ParCmd.JointPosition.J6) = FALSE )
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_INVALID_PAR_CMD, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.JointPosition.J6 = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.JointPosition.J6));
    RETURN;
  END_IF
  
  
  // Check ParCmd.JointPosition.E1 valid ?
  IF ( SysDepIsValidReal(ParCmd.JointPosition.E1) = FALSE )
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_INVALID_PAR_CMD, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.JointPosition.E1 = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.JointPosition.E1));
    RETURN;
  END_IF
  
  
  // Check ParCmd.JointPosition.E2 valid ?
  IF ( SysDepIsValidReal(ParCmd.JointPosition.E2) = FALSE )
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_INVALID_PAR_CMD, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.JointPosition.E2 = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.JointPosition.E2));
    RETURN;
  END_IF
  
  
  // Check ParCmd.JointPosition.E3 valid ?
  IF ( SysDepIsValidReal(ParCmd.JointPosition.E3) = FALSE )
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_INVALID_PAR_CMD, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.JointPosition.E3 = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.JointPosition.E3));
    RETURN;
  END_IF
  
  
  // Check ParCmd.JointPosition.E4 valid ?
  IF ( SysDepIsValidReal(ParCmd.JointPosition.E4) = FALSE )
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_INVALID_PAR_CMD, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.JointPosition.E4 = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.JointPosition.E4));
    RETURN;
  END_IF
  
  
  // Check ParCmd.JointPosition.E5 valid ?
  IF ( SysDepIsValidReal(ParCmd.JointPosition.E5) = FALSE )
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_INVALID_PAR_CMD, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.JointPosition.E5 = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.JointPosition.E5));
    RETURN;
  END_IF
  
  
  // Check ParCmd.JointPosition.E6 valid ?
  IF ( SysDepIsValidReal(ParCmd.JointPosition.E6) = FALSE )
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_INVALID_PAR_CMD, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.JointPosition.E6 = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.JointPosition.E6));
    RETURN;
  END_IF
  
  
  // Check ParCmd.MaximumDistance valid ?
  IF ( SysDepIsValidReal(ParCmd.MaximumDistance) = FALSE )
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_INVALID_PAR_CMD, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.MaximumDistance = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.MaximumDistance));
    RETURN;
  END_IF
  
  
  // Check ParCmd.VelocityRate valid ?
  // ST-FIX F152: OR_ELSE - ST evaluates OR completely, a comparison with NaN raises an FPU exception
  IF  (( SysDepIsValidReal(ParCmd.VelocityRate) = FALSE )  OR_ELSE
      (* every value < 0 is the default *)
       (                   ParCmd.VelocityRate  >   100 ))
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_VELOCITY_INVALID, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.VelocityRate = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.VelocityRate));
    RETURN;
  END_IF
  
  
  // Check ParCmd.AccelerationRate valid ?
  // ST-FIX F152: OR_ELSE - ST evaluates OR completely, a comparison with NaN raises an FPU exception
  IF  (( SysDepIsValidReal(ParCmd.AccelerationRate) = FALSE )  OR_ELSE
      (* every value < 0 is the default *)
       (                   ParCmd.AccelerationRate  >   100 ))
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_ACCELERATION_INVALID, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.AccelerationRate = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.AccelerationRate));
    RETURN;
  END_IF
  
  
  // Check ParCmd.DecelerationRate valid ?
  // ST-FIX F152: OR_ELSE - ST evaluates OR completely, a comparison with NaN raises an FPU exception
  IF  (( SysDepIsValidReal(ParCmd.DecelerationRate) = FALSE )  OR_ELSE
      (* every value < 0 is the default *)
       (                   ParCmd.DecelerationRate  >   100 ))
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_DECELERATION_INVALID, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.DecelerationRate = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.DecelerationRate));
    RETURN;
  END_IF
  
  
  // Check ParCmd.JerkRate valid ?
  // ST-FIX F152: OR_ELSE - ST evaluates OR completely, a comparison with NaN raises an FPU exception
  IF  (( SysDepIsValidReal(ParCmd.JerkRate) = FALSE )  OR_ELSE
      (* every value < 0 is the default *)
       (                   ParCmd.JerkRate  >   100 ))
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_JERK_INVALID, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.JerkRate = {1}',
                            Para1       := VALID_REAL_TO_STRING(ParCmd.JerkRate));
    RETURN;
  END_IF
  
  
  // Check ParCmd.ToolNo valid ?
  IF (( ParCmd.ToolNo > 254                                                ) OR
      ( ParCmd.ToolNo > AxesGroup.State.ConfigurationData.HighestToolIndex ) OR
      ( ParCmd.ToolNo > AxesGroup.State.UnifiedToolIndex                   ))
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
  
    // Check ToolNo available on RC ?
    IF (( ParCmd.ToolNo > AxesGroup.State.ConfigurationData.HighestToolIndex ) AND ( ParCmd.ToolNo <= 254 ))
    THEN
      SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_TOOLNO_UNAVAILABLE, Overwrite := TRUE );
    ELSE
      SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_TOOLNO_RANGE, Overwrite := TRUE );
    END_IF
  
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.ToolNo = {1}',
                            Para1       := USINT_TO_STRING(ParCmd.ToolNo));
    RETURN;
  END_IF
  
  
  // Check ParCmd.MoveTime valid ? (transmitted as UINT [ms])
  IF  ( ParCmd.MoveTime > T#65535MS )
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_INVALID_PAR_CMD, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.MoveTime = {1}',
                            Para1       := TIME_TO_STRING(ParCmd.MoveTime));
    RETURN;
  END_IF

END_METHOD

METHOD INTERNAL CreateCommandPayload : RobotLibraryCommandDataFB
VAR_IN_OUT
  /// Robot assignment of function
  AxesGroup : AxesGroup;
END_VAR
VAR
  /// Parameter count
 _parameterCnt : DINT;
END_VAR
// Table 6-838: Sent CMD payload (PLC to RC) of "SafeReferencing"
// --------------------------
// Header
// --------------------------
// Byte 00 : UINT  - Type HB
// Byte 01 :       - Type LB
// Byte 02 : USINT - Reserve | ExecutionMode
// Byte 03 : USINT - ParSeq  | Priority
// --------------------------
// Datablock
// --------------------------
// Byte 04 : UINT  - VelocityRate HB
// Byte 05 :       - VelocityRate LB
// Byte 06 : UINT  - AccelerationRate HB
// Byte 07 :       - AccelerationRate LB
// Byte 08 : UINT  - DecelerationRate HB
// Byte 09 :       - DecelerationRate LB
// Byte 10 : UINT  - JerkRate HB
// Byte 11 :       - JerkRate LB
// Byte 12 : USINT - ToolNo
// Byte 13 : REAL  - MaximumDistance HW HB
// Byte 14 :       - MaximumDistance HW LB
// Byte 15 :       - MaximumDistance LW HB
// Byte 16 :       - MaximumDistance LW LB
// Byte 17 : REAL  - JointPosition.J1 HW HB
// Byte 18 :       - JointPosition.J1 HW LB
// Byte 19 :       - JointPosition.J1 LW HB
// Byte 20 :       - JointPosition.J1 LW LB
// Byte 21 : REAL  - JointPosition.J2 HW HB
// Byte 22 :       - JointPosition.J2 HW LB
// Byte 23 :       - JointPosition.J2 LW HB
// Byte 24 :       - JointPosition.J2 LW LB
// Byte 25 : REAL  - JointPosition.J3 HW HB
// Byte 26 :       - JointPosition.J3 HW LB
// Byte 27 :       - JointPosition.J3 LW HB
// Byte 28 :       - JointPosition.J3 LW LB
// Byte 29 : REAL  - JointPosition.J4 HW HB
// Byte 30 :       - JointPosition.J4 HW LB
// Byte 31 :       - JointPosition.J4 LW HB
// Byte 32 :       - JointPosition.J4 LW LB
// Byte 33 : REAL  - JointPosition.J5 HW HB
// Byte 34 :       - JointPosition.J5 HW LB
// Byte 35 :       - JointPosition.J5 LW HB
// Byte 36 :       - JointPosition.J5 LW LB
// Byte 37 : REAL  - JointPosition.J6 HW HB
// Byte 38 :       - JointPosition.J6 HW LB
// Byte 39 :       - JointPosition.J6 LW HB
// Byte 40 :       - JointPosition.J6 LW LB
// Byte 41 : REAL  - JointPosition.E1 HW HB
// Byte 42 :       - JointPosition.E1 HW LB
// Byte 43 :       - JointPosition.E1 LW HB
// Byte 44 :       - JointPosition.E1 LW LB
// Byte 45 : UINT  - Time HB
// Byte 46 :       - Time LB
// Byte 47 : REAL  - JointPosition.E2 HW HB
// Byte 48 :       - JointPosition.E2 HW LB
// Byte 49 :       - JointPosition.E2 LW HB
// Byte 50 :       - JointPosition.E2 LW LB
// Byte 51 : REAL  - JointPosition.E3 HW HB
// Byte 52 :       - JointPosition.E3 HW LB
// Byte 53 :       - JointPosition.E3 LW HB
// Byte 54 :       - JointPosition.E3 LW LB
// Byte 55 : REAL  - JointPosition.E4 HW HB
// Byte 56 :       - JointPosition.E4 HW LB
// Byte 57 :       - JointPosition.E4 LW HB
// Byte 58 :       - JointPosition.E4 LW LB
// Byte 59 : REAL  - JointPosition.E5 HW HB
// Byte 60 :       - JointPosition.E5 HW LB
// Byte 61 :       - JointPosition.E5 LW HB
// Byte 62 :       - JointPosition.E5 LW LB
// Byte 63 : REAL  - JointPosition.E6 HW HB
// Byte 64 :       - JointPosition.E6 HW LB
// Byte 65 :       - JointPosition.E6 LW HB
// Byte 66 :       - JointPosition.E6 LW LB
// --------------------------

  // set command parameter
  _command.CmdTyp            :=  CmdType.SafeReferencing;
  // ExecutionMode from AbortingMode and SequenceFlag (spec table 5-77)
  IF ( SequenceFlag = SequenceFlagEnum.SECONDARY_SEQUENCE )
  THEN
    IF ( AbortingMode = AbortingModeEnum.ABORT )
    THEN
      _command.ExecMode := ExecutionMode.SEQUENCE_ABORT_OTHERS_SECONDARY;
    ELSE
      _command.ExecMode := ExecutionMode.SEQUENCE_SECONDARY;
    END_IF
  ELSE
    IF ( AbortingMode = AbortingModeEnum.ABORT )
    THEN
      _command.ExecMode := ExecutionMode.SEQUENCE_ABORT_OTHERS_PRIMARY;
    ELSE
      _command.ExecMode := ExecutionMode.SEQUENCE_PRIMARY;
    END_IF
  END_IF
  _command.ParSeq            := _command.ParSeq;
  _command.Priority          :=  Priority;
  _command.VelocityRate      :=  REAL_TO_PERCENT_UINT(_parCmd.VelocityRate     , IsOptional := FALSE);
  _command.AccelerationRate  :=  REAL_TO_PERCENT_UINT(_parCmd.AccelerationRate , IsOptional := FALSE);
  _command.DecelerationRate  :=  REAL_TO_PERCENT_UINT(_parCmd.DecelerationRate , IsOptional := TRUE );
  _command.JerkRate          :=  REAL_TO_PERCENT_UINT(_parCmd.JerkRate         , IsOptional := TRUE );
  _command.ToolNo            := _parCmd.ToolNo;
  _command.MaximumDistance   := _parCmd.MaximumDistance;
  _command.JointPosition     := _parCmd.JointPosition;
  _command.MoveTime          :=  TIME_TO_UINT(_parCmd.MoveTime);
  
  
  // copy command data to header
  _cmdHeader := _command;
  // call base implementation to copy header to payload buffer
  CreateCommandPayload := SUPER^.CreateCommandPayload(AxesGroup := AxesGroup);
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.VelocityRate
    CreateCommandPayload.AddUint(_command.VelocityRate);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.AccelerationRate
    CreateCommandPayload.AddUint(_command.AccelerationRate);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.DecelerationRate
    CreateCommandPayload.AddUint(_command.DecelerationRate);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.JerkRate
    CreateCommandPayload.AddUint(_command.JerkRate);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.ToolNo
    CreateCommandPayload.AddUsint(_command.ToolNo);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.MaximumDistance
    CreateCommandPayload.AddReal(_command.MaximumDistance);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.JointPosition.J1
    CreateCommandPayload.AddReal(_command.JointPosition.J1);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.JointPosition.J2
    CreateCommandPayload.AddReal(_command.JointPosition.J2);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.JointPosition.J3
    CreateCommandPayload.AddReal(_command.JointPosition.J3);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.JointPosition.J4
    CreateCommandPayload.AddReal(_command.JointPosition.J4);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.JointPosition.J5
    CreateCommandPayload.AddReal(_command.JointPosition.J5);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.JointPosition.J6
    CreateCommandPayload.AddReal(_command.JointPosition.J6);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.JointPosition.E1
    CreateCommandPayload.AddReal(_command.JointPosition.E1);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.MoveTime
    CreateCommandPayload.AddUint(_command.MoveTime);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.JointPosition.E2
    CreateCommandPayload.AddReal(_command.JointPosition.E2);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.JointPosition.E3
    CreateCommandPayload.AddReal(_command.JointPosition.E3);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.JointPosition.E4
    CreateCommandPayload.AddReal(_command.JointPosition.E4);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.JointPosition.E5
    CreateCommandPayload.AddReal(_command.JointPosition.E5);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.JointPosition.E6
    CreateCommandPayload.AddReal(_command.JointPosition.E6);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Create logging
  CreateCommandPayloadLog(AxesGroup := AxesGroup, ParameterCnt := _parameterCnt);

END_METHOD

METHOD INTERNAL CreateCommandPayloadLog
VAR_IN_OUT
  /// Robot assignment of function
  AxesGroup : AxesGroup;
END_VAR
VAR_INPUT
  /// Parameter count
  ParameterCnt : DINT;
END_VAR

  // Create log entry for Parameter start
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Create command payload with {1} parameter(s) :',
                          Para1       := DINT_TO_STRING(ParameterCnt));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for VelocityRate
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.VelocityRate = {1}',
                          Para1       :=  UINT_TO_STRING(_command.VelocityRate));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for AccelerationRate
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.AccelerationRate = {1}',
                          Para1       :=  UINT_TO_STRING(_command.AccelerationRate));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for DecelerationRate
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.DecelerationRate = {1}',
                          Para1       :=  UINT_TO_STRING(_command.DecelerationRate));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for JerkRate
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.JerkRate = {1}',
                          Para1       :=  UINT_TO_STRING(_command.JerkRate));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for ToolNo
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.ToolNo = {1}',
                          Para1       :=  USINT_TO_STRING(_command.ToolNo));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for MaximumDistance
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.MaximumDistance = {1}',
                          Para1       :=  REAL_TO_STRING(_command.MaximumDistance));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for JointPosition.J1
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.JointPosition.J1 = {1}',
                          Para1       :=  REAL_TO_STRING(_command.JointPosition.J1));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for JointPosition.J2
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.JointPosition.J2 = {1}',
                          Para1       :=  REAL_TO_STRING(_command.JointPosition.J2));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for JointPosition.J3
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.JointPosition.J3 = {1}',
                          Para1       :=  REAL_TO_STRING(_command.JointPosition.J3));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for JointPosition.J4
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.JointPosition.J4 = {1}',
                          Para1       :=  REAL_TO_STRING(_command.JointPosition.J4));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for JointPosition.J5
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.JointPosition.J5 = {1}',
                          Para1       :=  REAL_TO_STRING(_command.JointPosition.J5));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for JointPosition.J6
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.JointPosition.J6 = {1}',
                          Para1       :=  REAL_TO_STRING(_command.JointPosition.J6));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for JointPosition.E1
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.JointPosition.E1 = {1}',
                          Para1       :=  REAL_TO_STRING(_command.JointPosition.E1));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for MoveTime
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.MoveTime = {1}',
                          Para1       :=  UINT_TO_STRING(_command.MoveTime));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for JointPosition.E2
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.JointPosition.E2 = {1}',
                          Para1       :=  REAL_TO_STRING(_command.JointPosition.E2));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for JointPosition.E3
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.JointPosition.E3 = {1}',
                          Para1       :=  REAL_TO_STRING(_command.JointPosition.E3));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for JointPosition.E4
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.JointPosition.E4 = {1}',
                          Para1       :=  REAL_TO_STRING(_command.JointPosition.E4));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for JointPosition.E5
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.JointPosition.E5 = {1}',
                          Para1       :=  REAL_TO_STRING(_command.JointPosition.E5));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for JointPosition.E6
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.JointPosition.E6 = {1}',
                          Para1       :=  REAL_TO_STRING(_command.JointPosition.E6));

END_METHOD

METHOD FB_init : BOOL
VAR_INPUT
  /// if TRUE, the retain variables are initialized (warm start / cold start)
  bInitRetains : BOOL;
  /// if TRUE, the instance afterwards gets moved into the copy code (online change)
  bInCopyCode  : BOOL;
END_VAR

  MyType := 'MC_SafeReferencingFB';
  
  ExecMode     := ExecutionMode.SEQUENCE_PRIMARY;
  Priority     := PriorityLevel.NORMAL;
  AbortingMode := AbortingModeEnum.BUFFER;
  SequenceFlag := SequenceFlagEnum.PRIMARY_SEQUENCE;

END_METHOD

METHOD PROTECTED OnApplyOutCmd
VAR_INPUT
  /// Command message state
  State : CmdMessageState;
END_VAR

  IF ( State = CmdMessageState.EMPTY )
  THEN
    // Reset command outputs
    SysDepMemSet(pDest := ADR(OutCmd), Value := 0, DataLen := SIZEOF(OutCmd));
  END_IF
  
  IF (( State = CmdMessageState.ACTIVE ) OR
      ( State = CmdMessageState.DONE   ))
  THEN
    // Update results
    OutCmd.Status := _response.Status;
  END_IF

END_METHOD

METHOD PROTECTED OnExecRun : DINT
VAR_IN_OUT
  /// Robot assignment of function
  AxesGroup : AxesGroup;
END_VAR

  // call base implementation
  SUPER^.OnExecRun(AxesGroup := AxesGroup);
  
  CASE _stepCmd OF
  
    00:  IF ( _execute_R.Q ) AND ( NOT Error)
         THEN
           // Check function is supported and parameter are valid ?
           IF (( CheckFunctionSupported( AxesGroup := AxesGroup )) AND
               ( CheckParameterValid   ( AxesGroup := AxesGroup )))
           THEN
             // set busy flag
             Busy := TRUE;
             // Reset command outputs
             SysDepMemSet(pDest := ADR(OutCmd), Value := 0, DataLen := SIZEOF(OutCmd));
             // apply command parameter
            _parCmd := ParCmd;
             // init parameter sequence
            _command.ParSeq := 1;
             // create command data
             CommandData := CreateCommandPayload(AxesGroup := AxesGroup);
             // Add command to active command register
            _uniqueID := AxesGroup.Acyclic.ActiveCommandRegister.AddCmd( pCommandFB := ADR(THIS^ ));
             // set timeout
             SetTimeout(PT := _timeoutCmd, rTimer := _timerCmd);
             // inc step counter
            _stepCmd := _stepCmd + 1;
           END_IF
         END_IF
  
  
    01:  // Wait for responce received
         IF ( _responseReceived )
         THEN
           // reset response received flag
          _responseReceived := FALSE;
           // update state flags
           OnUpdateStateFlags(_response.State);
           // update command outputs
           OnApplyOutCmd(_response.State);
  
           // Done, Aborted or Error ?
           IF (_response.State >= CmdMessageState.DONE )
           THEN
             // set timeout
             SetTimeout(PT := _timeoutCmd, rTimer := _timerCmd);
             // inc step counter
            _stepCmd := _stepCmd + 1;
           END_IF
         END_IF
  
  
    02: IF ( NOT Execute)
        THEN
          Reset();
        END_IF
  
  ELSE
    // invalid step
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_INVALID_STEP, Overwrite := TRUE );
  END_CASE
  
  
  // Reset FB
  IF ( NOT Execute )
  THEN
    Reset();
  END_IF

END_METHOD

METHOD PROTECTED OnUpdateStateFlags
VAR_INPUT
  /// Command message state
  State : CmdMessageState;
END_VAR

  // Reset State flags
  Active             := FALSE;
  CommandAborted     := FALSE;
  CommandInterrupted := FALSE;
  Done               := FALSE;
  
  CASE State OF
  
    // No operation or process is active
    CmdMessageState.EMPTY               :;
    // Created but not yet started
    CmdMessageState.CREATED             :;
    // Buffered and awaiting execution
    CmdMessageState.BUFFERED            : CommandBuffered    := TRUE;
    // Buffered in planner for future execution
    CmdMessageState.BUFFERED_IN_PLANNER : CommandBuffered    := TRUE;
    // Currently active and in progress
    CmdMessageState.ACTIVE              : Active             := TRUE;
    // Interrupted and awaiting continuation
    CmdMessageState.INTERRUPTED         : CommandInterrupted := TRUE;
    // Requested for abort
    CmdMessageState.ABORT_REQUEST       :;
    // Successfully completed
    CmdMessageState.DONE                : Done               := TRUE;
                                          Busy               := FALSE;
    // Aborted before completion
    CmdMessageState.ABORTED             : CommandAborted     := TRUE;
                                          Busy               := FALSE;
    // Encountered an error during execution
    CmdMessageState.ERROR               : Error              := TRUE;
                                          Busy               := FALSE;
  END_CASE

END_METHOD

METHOD INTERNAL ParseResponsePayload : DINT
VAR_INPUT
  /// Response data
  ResponseData : RobotLibraryResponseDataFB;
  /// Timestamp
  Timestamp    : SystemTime;
END_VAR
VAR
  /// Parameter count
 _parameterCnt : DINT;
END_VAR
// Table 6-839: Received CMD payload (RC to PLC) of "SafeReferencing"
// --------------------------
// Header
// --------------------------
// Byte 00 : USINT - ParSeq | State
// Byte 01 : SINT  - AlarmMessageSeverity
// Byte 02 : UINT  - AlarmMessageCode HB
// Byte 03 :       - AlarmMessageCode LB
// --------------------------
// Datablock
// --------------------------
// Byte 04 : USINT - Status
// --------------------------

  // call base implementation to parse the header from payload buffer
  ResponseData.PayloadPtr := SUPER^.ParseResponsePayload(ResponseData := ResponseData, Timestamp := Timestamp);
  
  // missing (trailing zero) bytes of the payload are 0, no values of the previous response
  SysDepMemSet( pDest := ADR(_response), Value := 0, DataLen := SIZEOF(_response));
  
  // copy parsed header to response
  _response.ParSeq               := _rspHeader.ParSeq;
  _response.State                := _rspHeader.State;
  _response.AlarmMessageSeverity := _rspHeader.AlarmMessageSeverity;
  _response.AlarmMessageCode     := _rspHeader.AlarmMessageCode;
  
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.Status
   _response.Status := ResponseData.GetUsint();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Create logging
  ParseResponsePayloadLog(ResponseData := ResponseData, Timestamp := Timestamp, ParameterCnt := _parameterCnt);

END_METHOD

METHOD INTERNAL ParseResponsePayloadLog
VAR_INPUT
  /// Response data
  ResponseData : RobotLibraryResponseDataFB;
  /// Timestamp
  Timestamp    : SystemTime;
  /// Parameter count
  ParameterCnt : DINT;
END_VAR

  // Create log entry for Parameter start
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := '{1} parameter(s) to parse from the response data:',
                          Para1       := DINT_TO_STRING(ParameterCnt));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Status
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.Status = {1}',
                          Para1       :=  USINT_TO_STRING(_response.Status));

END_METHOD

METHOD PROTECTED Reset : DINT
VAR_INPUT
END_VAR

  Reset := SUPER^.Reset();
  
  Done               := FALSE;
  Busy               := FALSE;
  Active             := FALSE;
  CommandBuffered    := FALSE;
  CommandAborted     := FALSE;
  CommandInterrupted := FALSE;

END_METHOD

