/// Read a safe reference position of the RC
/// F109: new function block (SRCI command 7009 ReadSafeReferencePosition, spec 6.5.38)
FUNCTION_BLOCK MC_ReadSafeReferencePositionFB EXTENDS RobotLibraryBaseExecuteFB
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      MC_ReadSafeReferencePositionFB
//  Author:      Thorsten Brach
//  Date:        2026-10-25
//
//  Description:
//    ReadSafeReferencePosition (spec 6.5.38, type 7009): reads the safe reference position
//    ParCmd.Index (1..n) that was defined during the safety commissioning of the robot.
//    OutCmd.Position returns the joint position, OutCmd.NumberOfPositions the number of defined
//    safe reference positions. The command is always executed in the parallel buffer.
//    F109: new function block (SRCI command 7009 ReadSafeReferencePosition, spec 6.5.38)
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
  /// command parameter
  ParCmd          : ReadSafeReferencePositionParCmd;
END_VAR
VAR_OUTPUT
  /// Command is transferred and confirmed by the RC
  CommandBuffered : BOOL;
  /// command outputs
  OutCmd          : ReadSafeReferencePositionOutCmd;
END_VAR

VAR
  /// internal copy of command parameter
 _parCmd          : ReadSafeReferencePositionParCmd;
  /// command data to send
 _command         : ReadSafeReferencePositionSendData;
  /// response data received
 _response        : ReadSafeReferencePositionRecvData;
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

END_METHOD

METHOD PROTECTED CheckFunctionSupported : BOOL
VAR_IN_OUT
  /// Robot assignment of function
  AxesGroup : AxesGroup;
END_VAR

  // ReadSafeReferencePosition has no bit in "RCSupportedFunctions" (spec table of the supported functions,
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
  
  // Check ParCmd.Index valid ? (0: invalid)
  IF ( ParCmd.Index = 0 )
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
                            MessageText := 'Invalid Parameter ParCmd.Index = {1}',
                            Para1       :=  USINT_TO_STRING(ParCmd.Index));
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
// Table 6-831: Sent CMD payload (PLC to RC) of "ReadSafeReferencePosition"
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
// Byte 04 : USINT - Index
// --------------------------

  // set command parameter
  _command.CmdTyp   :=  CmdType.ReadSafeReferencePosition;
  _command.ExecMode :=  ExecMode;
  _command.ParSeq   := _command.ParSeq;
  _command.Priority :=  Priority;
  _command.Index    := _parCmd.Index;
  
  // copy command data to header
  _cmdHeader := _command;
  // call base implementation to copy header to payload buffer
  CreateCommandPayload := SUPER^.CreateCommandPayload(AxesGroup := AxesGroup);
  
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.Index
    CreateCommandPayload.AddUsint(_command.Index);
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
  // Create log entry for Index
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.Index = {1}',
                          Para1       :=  USINT_TO_STRING(_command.Index));

END_METHOD

METHOD FB_init : BOOL
VAR_INPUT
  /// if TRUE, the retain variables are initialized (warm start / cold start)
  bInitRetains : BOOL;
  /// if TRUE, the instance afterwards gets moved into the copy code (online change)
  bInCopyCode  : BOOL;
END_VAR

  MyType := 'MC_ReadSafeReferencePositionFB';
  
  // the command is always executed in the parallel buffer (spec table 6-829)
  ExecMode := ExecutionMode.PARALLEL;
  Priority := PriorityLevel.NORMAL;

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
    OutCmd.NumberOfPositions := _response.NumberOfPositions;
    OutCmd.Position          := _response.Position;
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
  Done := FALSE;
  
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
    CmdMessageState.ACTIVE              :;
    // Interrupted and awaiting continuation
    CmdMessageState.INTERRUPTED         :;
    // Requested for abort
    CmdMessageState.ABORT_REQUEST       :;
    // Successfully completed
    CmdMessageState.DONE                : Done               := TRUE;
                                          Busy               := FALSE;
    // Aborted before completion
    CmdMessageState.ABORTED             : Busy               := FALSE;
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
  /// internal index for loops
 _idx          : DINT;
  /// Parameter count
 _parameterCnt : DINT;
END_VAR
// Table 6-832: Received CMD payload (RC to PLC) of "ReadSafeReferencePosition"
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
// Byte 04 : USINT - NumberOfPositions
// Byte 05 : BYTE  - Reserved
// Byte 06 : REAL  - ActualJointPosition.J1 HW HB
// Byte 07 :       - ActualJointPosition.J1 HW LB
// Byte 08 :       - ActualJointPosition.J1 LW HB
// Byte 09 :       - ActualJointPosition.J1 LW LB
// Byte 10 : REAL  - ActualJointPosition.J2 HW HB
// Byte 11 :       - ActualJointPosition.J2 HW LB
// Byte 12 :       - ActualJointPosition.J2 LW HB
// Byte 13 :       - ActualJointPosition.J2 LW LB
// Byte 14 : REAL  - ActualJointPosition.J3 HW HB
// Byte 15 :       - ActualJointPosition.J3 HW LB
// Byte 16 :       - ActualJointPosition.J3 LW HB
// Byte 17 :       - ActualJointPosition.J3 LW LB
// Byte 18 : REAL  - ActualJointPosition.J4 HW HB
// Byte 19 :       - ActualJointPosition.J4 HW LB
// Byte 20 :       - ActualJointPosition.J4 LW HB
// Byte 21 :       - ActualJointPosition.J4 LW LB
// Byte 22 : REAL  - ActualJointPosition.J5 HW HB
// Byte 23 :       - ActualJointPosition.J5 HW LB
// Byte 24 :       - ActualJointPosition.J5 LW HB
// Byte 25 :       - ActualJointPosition.J5 LW LB
// Byte 26 : REAL  - ActualJointPosition.J6 HW HB
// Byte 27 :       - ActualJointPosition.J6 HW LB
// Byte 28 :       - ActualJointPosition.J6 LW HB
// Byte 29 :       - ActualJointPosition.J6 LW LB
// Byte 30 : REAL  - ActualCartesianPosition.E2 HW HB
// Byte 31 :       - ActualCartesianPosition.E2 HW LB
// Byte 32 :       - ActualCartesianPosition.E2 LW HB
// Byte 33 :       - ActualCartesianPosition.E2 LW LB
// Byte 34 : REAL  - ActualCartesianPosition.E3 HW HB
// Byte 35 :       - ActualCartesianPosition.E3 HW LB
// Byte 36 :       - ActualCartesianPosition.E3 LW HB
// Byte 37 :       - ActualCartesianPosition.E3 LW LB
// Byte 38 : REAL  - ActualCartesianPosition.E4 HW HB
// Byte 39 :       - ActualCartesianPosition.E4 HW LB
// Byte 40 :       - ActualCartesianPosition.E4 LW HB
// Byte 41 :       - ActualCartesianPosition.E4 LW LB
// Byte 42 : REAL  - ActualCartesianPosition.E5 HW HB
// Byte 43 :       - ActualCartesianPosition.E5 HW LB
// Byte 44 :       - ActualCartesianPosition.E5 LW HB
// Byte 45 :       - ActualCartesianPosition.E5 LW LB
// Byte 46 : REAL  - ActualCartesianPosition.E6 HW HB
// Byte 47 :       - ActualCartesianPosition.E6 HW LB
// Byte 48 :       - ActualCartesianPosition.E6 LW HB
// Byte 49 :       - ActualCartesianPosition.E6 LW LB
// Byte 50 : REAL  - ActualJointPosition.E1 HW HB
// Byte 51 :       - ActualJointPosition.E1 HW LB
// Byte 52 :       - ActualJointPosition.E1 LW HB
// Byte 53 :       - ActualJointPosition.E1 LW LB
// Byte 54 : REAL  - ActualJointPosition.E2 HW HB
// Byte 55 :       - ActualJointPosition.E2 HW LB
// Byte 56 :       - ActualJointPosition.E2 LW HB
// Byte 57 :       - ActualJointPosition.E2 LW LB
// Byte 58 : REAL  - ActualJointPosition.E3 HW HB
// Byte 59 :       - ActualJointPosition.E3 HW LB
// Byte 60 :       - ActualJointPosition.E3 LW HB
// Byte 61 :       - ActualJointPosition.E3 LW LB
// Byte 62 : REAL  - ActualJointPosition.E4 HW HB
// Byte 63 :       - ActualJointPosition.E4 HW LB
// Byte 64 :       - ActualJointPosition.E4 LW HB
// Byte 65 :       - ActualJointPosition.E4 LW LB
// Byte 66 : REAL  - ActualJointPosition.E5 HW HB
// Byte 67 :       - ActualJointPosition.E5 HW LB
// Byte 68 :       - ActualJointPosition.E5 LW HB
// Byte 69 :       - ActualJointPosition.E5 LW LB
// Byte 70 : REAL  - ActualJointPosition.E6 HW HB
// Byte 71 :       - ActualJointPosition.E6 HW LB
// Byte 72 :       - ActualJointPosition.E6 LW HB
// Byte 73 :       - ActualJointPosition.E6 LW LB
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
    // Get Response.NumberOfPositions
   _response.NumberOfPositions := ResponseData.GetUsint();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.Reserve
   _response.Reserve := ResponseData.GetByte();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.Position.J1
   _response.Position.J1 := ResponseData.GetReal();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.Position.J2
   _response.Position.J2 := ResponseData.GetReal();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.Position.J3
   _response.Position.J3 := ResponseData.GetReal();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.Position.J4
   _response.Position.J4 := ResponseData.GetReal();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.Position.J5
   _response.Position.J5 := ResponseData.GetReal();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.Position.J6
   _response.Position.J6 := ResponseData.GetReal();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // bytes 30..49 (spec table 6-832: ActualCartesianPosition.E2..E6)
  FOR _idx := 2 TO 6
  DO
    // Check payload remaining ?
    IF ( ResponseData.IsPayloadRemaining)
    THEN
      // Get Response.CartesianPositionExt[x]
     _response.CartesianPositionExt[_idx] := ResponseData.GetReal();
      // inc parameter counter
     _parameterCnt := _parameterCnt + 1;
    END_IF
  END_FOR
  
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.Position.E1
   _response.Position.E1 := ResponseData.GetReal();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.Position.E2
   _response.Position.E2 := ResponseData.GetReal();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.Position.E3
   _response.Position.E3 := ResponseData.GetReal();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.Position.E4
   _response.Position.E4 := ResponseData.GetReal();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.Position.E5
   _response.Position.E5 := ResponseData.GetReal();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.Position.E6
   _response.Position.E6 := ResponseData.GetReal();
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
VAR
  /// internal index for loops
 _idx : DINT;
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
  // Create log entry for NumberOfPositions
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.NumberOfPositions = {1}',
                          Para1       :=  USINT_TO_STRING(_response.NumberOfPositions));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Reserve
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.Reserve = {1}',
                          Para1       :=  BYTE_TO_STRING(_response.Reserve));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Position.J1
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.Position.J1 = {1}',
                          Para1       :=  REAL_TO_STRING(_response.Position.J1));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Position.J2
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.Position.J2 = {1}',
                          Para1       :=  REAL_TO_STRING(_response.Position.J2));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Position.J3
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.Position.J3 = {1}',
                          Para1       :=  REAL_TO_STRING(_response.Position.J3));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Position.J4
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.Position.J4 = {1}',
                          Para1       :=  REAL_TO_STRING(_response.Position.J4));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Position.J5
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.Position.J5 = {1}',
                          Para1       :=  REAL_TO_STRING(_response.Position.J5));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Position.J6
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.Position.J6 = {1}',
                          Para1       :=  REAL_TO_STRING(_response.Position.J6));
  
  
  // Create log entries for CartesianPositionExt[x]
  FOR _idx := 2 TO 6
  DO
    // Return if no parameter is remaining...
    IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
    // dec remaining parameter(s)
    ParameterCnt := ParameterCnt - 1;
    // Create log entry for CartesianPositionExt[x]
    CreateLogMessagePara2 ( Timestamp   := Timestamp,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.DEBUG,
                            MessageCode := 0,
                            MessageText := 'Response.CartesianPositionExt[{2}] = {1}',
                            Para1       :=  REAL_TO_STRING(_response.CartesianPositionExt[_idx]),
                            Para2       :=  DINT_TO_STRING(_idx));
  END_FOR
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Position.E1
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.Position.E1 = {1}',
                          Para1       :=  REAL_TO_STRING(_response.Position.E1));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Position.E2
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.Position.E2 = {1}',
                          Para1       :=  REAL_TO_STRING(_response.Position.E2));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Position.E3
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.Position.E3 = {1}',
                          Para1       :=  REAL_TO_STRING(_response.Position.E3));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Position.E4
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.Position.E4 = {1}',
                          Para1       :=  REAL_TO_STRING(_response.Position.E4));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Position.E5
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.Position.E5 = {1}',
                          Para1       :=  REAL_TO_STRING(_response.Position.E5));
  
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Position.E6
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.Position.E6 = {1}',
                          Para1       :=  REAL_TO_STRING(_response.Position.E6));

END_METHOD

METHOD PROTECTED Reset : DINT
VAR_INPUT
END_VAR

  Reset := SUPER^.Reset();
  
  Done               := FALSE;
  Busy               := FALSE;
  CommandBuffered    := FALSE;

END_METHOD

