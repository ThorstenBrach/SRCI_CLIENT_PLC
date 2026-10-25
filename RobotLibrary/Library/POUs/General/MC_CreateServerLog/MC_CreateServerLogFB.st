/// Create a server log on the RC (snapshot of the event log, system states and ACR content)
FUNCTION_BLOCK MC_CreateServerLogFB EXTENDS RobotLibraryBaseExecuteFB
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      MC_CreateServerLogFB
//  Author:      Thorsten Brach
//  Date:        2026-10-23
//
//  Description:
//    CreateServerLog (spec 6.2.5, type 9003): the RC stores a snapshot of its event log ring buffer,
//    the system states and the ACR content as server log; OutCmd.ServerLogID returns its ID.
//    When the RC has no room for another log, it overwrites the oldest one (InfoID 16#6C70).
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
  /// Processing Mode
  ProcessingMode     : ProcessingMode;
  /// Defines the target sequence in which the command will be executed
  SequenceFlag       : SequenceFlag;
  /// command parameter
  ParCmd             : CreateServerLogParCmd;
END_VAR
VAR_OUTPUT
  /// Command is transferred and confirmed by the RC
  CommandBuffered    : BOOL;
  /// The command was aborted by another command.
  CommandAborted     : BOOL;
  /// TRUE, while command is interrupted during execution and can be continued
  CommandInterrupted : BOOL;
  /// Receiving of input parameter values has been acknowledged by RC
  ParameterAccepted  : BOOL;
  /// command outputs
  OutCmd             : CreateServerLogOutCmd;
END_VAR
VAR
  /// internal copy of command parameter
 _parCmd             : CreateServerLogParCmd;
  /// command data to send
 _command            : CreateServerLogSendData;
  /// response data received
 _response           : CreateServerLogRecvData;
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

  // CreateServerLog is a mandatory function of the profile Core (spec table 6-112): the RC
  // reports no bit for it in RCSupportedFunctions
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
                            Para1       := '');
  
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
    // Reset parameter accepted flag
    ParameterAccepted := FALSE;
  END_IF

END_METHOD

METHOD PROTECTED CheckParameterValid : BOOL
VAR_IN_OUT
  /// Robot assignment of function
  AxesGroup : AxesGroup;
END_VAR

  CheckParameterValid := TRUE;
  
  // Check ProcessingMode defined ?
  IF (( ProcessingMode < ProcessingModeEnum.BUFFERED         ) OR
      ( ProcessingMode > ProcessingModeEnum.TRIGGER_MULTIPLE ))
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_PROCESSINGMODE_NOT_DEFINED, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ProcessingMode = {1}',
                            Para1       := PROCESSING_MODE_TO_STRING(ProcessingMode));
    RETURN;
  END_IF
  
  // Check ProcessingMode allowed ? (spec table 6-112: no continuous modes)
  IF (( ProcessingMode <> ProcessingModeEnum.BUFFERED         ) AND
      ( ProcessingMode <> ProcessingModeEnum.ABORTING         ) AND
      ( ProcessingMode <> ProcessingModeEnum.PARALLEL         ) AND
      ( ProcessingMode <> ProcessingModeEnum.DEACTIVATE       ) AND
      ( ProcessingMode <> ProcessingModeEnum.TRIGGER_ONCE     ) AND
      ( ProcessingMode <> ProcessingModeEnum.TRIGGER_MULTIPLE ))
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_PROCESSINGMODE_NOT_ALLOWED, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ProcessingMode = {1}',
                            Para1       := PROCESSING_MODE_TO_STRING(ProcessingMode));
    RETURN;
  END_IF
  
  // Check SequenceFlag valid ?
  IF (( SequenceFlag <> SequenceFlagEnum.NO_SEQUENCE        ) AND
      ( SequenceFlag <> SequenceFlagEnum.PRIMARY_SEQUENCE   ) AND
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
  
  // Check ParCmd.ListenerID valid ?
  IF (( ParCmd.ListenerID <   0 ) OR
      ( ParCmd.ListenerID > 127 ))
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_LISTENERID_MUST_BE_POSITIVE, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.ListenerID = {1}',
                            Para1       := SINT_TO_STRING(ParCmd.ListenerID));
    RETURN;
  END_IF
  
  // trigger based ProcessingMode needs a ListenerID > 0 (table 7-1, 5.5.12.4)
  IF (( ProcessingMode >= ProcessingModeEnum.TRIGGER_BUFFERED ) AND
      ( ParCmd.ListenerID = 0                               ))
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_LISTENERID_MUST_BE_GREATER_THAN_ZERO, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.ListenerID = 0 with ProcessingMode = {1}',
                            Para1       := PROCESSING_MODE_TO_STRING(ProcessingMode));
    RETURN;
  END_IF
  
  // a ListenerID > 0 only with a trigger based ProcessingMode
  IF ((     ProcessingMode <> ProcessingModeEnum.DEACTIVATE       ) AND
      ( NOT ProcessingMode >= ProcessingModeEnum.TRIGGER_BUFFERED ) AND
      (     ParCmd.ListenerID > 0                               ))
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_LISTENERID_NOT_ALLOWED, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.ListenerID <> 0 with ProcessingMode = {1}',
                            Para1       := PROCESSING_MODE_TO_STRING(ProcessingMode));
    RETURN;
  END_IF
  
  // SequenceFlag must fit the ProcessingMode (not for DEACTIVATE, it is sent with the SequenceFlag of the command it ends)
  IF ((   ProcessingMode <> ProcessingModeEnum.DEACTIVATE        ) AND
      ((( ProcessingMode  = ProcessingModeEnum.BUFFERED          ) OR
        ( ProcessingMode  = ProcessingModeEnum.ABORTING          ) OR
        ( ProcessingMode  = ProcessingModeEnum.TRIGGER_BUFFERED  ) OR
        ( ProcessingMode  = ProcessingModeEnum.TRIGGER_ABORTING  )) = ( SequenceFlag = SequenceFlagEnum.NO_SEQUENCE )))
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_SEQFLAG_INVALID_IN_PROC_MODE, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara2 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter SequenceFlag = {1} with ProcessingMode = {2}',
                            Para1       := SEQUENCE_FLAG_TO_STRING(SequenceFlag),
                            Para2       := PROCESSING_MODE_TO_STRING(ProcessingMode));
    RETURN;
  END_IF

END_METHOD

METHOD INTERNAL CreateCommandPayload : RobotLibraryCommandDataFB
VAR_IN_OUT
  /// Robot assignment of function
  AxesGroup : AxesGroup;
END_VAR
VAR
  /// internal index for loops
 _idx          : DINT;
  /// Parameter count
 _parameterCnt : DINT;
END_VAR
// Table 6-116: Sent CMD payload (PLC to RC) of "CreateServerLog"
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
// Byte 04 : SINT  - EmitterID[0];
// Byte 05 : SINT  - EmitterID[1];
// Byte 06 : SINT  - EmitterID[2];
// Byte 07 : SINT  - EmitterID[3];
// Byte 08 : SINT  - ListenerID;  (table 6-116 ends at byte 7; table 6-114 and the trigger header table 5-73 have it)
// Byte 09 : BYTE  - Reserved;
// --------------------------

  // set command parameter
  _command.CmdTyp       :=  CmdType.CreateServerLog;
  // ExecutionMode from ProcessingMode (and SequenceFlag), spec table 5-77
  CASE ProcessingMode OF
    ProcessingModeEnum.BUFFERED, ProcessingModeEnum.TRIGGER_BUFFERED:
      IF ( SequenceFlag = SequenceFlagEnum.SECONDARY_SEQUENCE )
      THEN
        _command.ExecMode := ExecutionMode.SEQUENCE_SECONDARY;
      ELSE
        _command.ExecMode := ExecutionMode.SEQUENCE_PRIMARY;
      END_IF
    ProcessingModeEnum.ABORTING, ProcessingModeEnum.TRIGGER_ABORTING:
      IF ( SequenceFlag = SequenceFlagEnum.SECONDARY_SEQUENCE )
      THEN
        _command.ExecMode := ExecutionMode.SEQUENCE_ABORT_OTHERS_SECONDARY;
      ELSE
        _command.ExecMode := ExecutionMode.SEQUENCE_ABORT_OTHERS_PRIMARY;
      END_IF
    ProcessingModeEnum.PARALLEL, ProcessingModeEnum.TRIGGER_ONCE:
      _command.ExecMode := ExecutionMode.PARALLEL;
    ProcessingModeEnum.TRIGGER_MULTIPLE:
      _command.ExecMode := ExecutionMode.TRIGGER_MULTIPLE;
    ProcessingModeEnum.DEACTIVATE:
      _command.ExecMode := ExecutionMode.STOP_PARALLEL_CONTINUOUS_TRIGGER;
  ELSE
    // undefined or not allowed ProcessingMode -> error, not sent
    _command.ExecMode := ExecMode;
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_PROCESSINGMODE_NOT_DEFINED, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ProcessingMode = {1}',
                            Para1       := PROCESSING_MODE_TO_STRING(ProcessingMode));
    OnUpdateStateFlags( State := CmdMessageState.ERROR );
  END_CASE
  _command.ParSeq       := _command.ParSeq;
  _command.Priority     :=  Priority;
  _command.EmitterID[0] := 0;
  _command.EmitterID[1] := 0;
  _command.EmitterID[2] := 0;
  _command.EmitterID[3] := 0;
  _command.ListenerID   := _parCmd.ListenerID;
  _command.Reserve      := 0;
  
  // copy command data to header
  _cmdHeader := _command;
  // call base implementation to copy header to payload buffer
  CreateCommandPayload := SUPER^.CreateCommandPayload(AxesGroup := AxesGroup);
  
  FOR _idx := 0 TO 3
  DO
    // Check parameter must be added ?
    IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
    THEN
      // add command.EmitterID[x]
      CreateCommandPayload.AddSint(_command.EmitterID[_idx]);
      // inc parameter counter
     _parameterCnt := _parameterCnt + 1;
    END_IF
  END_FOR
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.ListenerID
    CreateCommandPayload.AddSint(_command.ListenerID);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.Reserve
    CreateCommandPayload.AddByte(_command.Reserve);
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
VAR
  /// internal index for loops
 _idx : DINT;
END_VAR

  // Create log entry for Parameter start
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Create command payload with {1} parameter(s) :',
                          Para1       := DINT_TO_STRING(ParameterCnt));
  
  // Create log entry for EmitterID[x]
  FOR _idx := 0 TO 3
  DO
    // Return if no parameter is remaining...
    IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
    // dec remaining parameter(s)
    ParameterCnt := ParameterCnt - 1;
    // Create log entry for Command.EmitterID
    CreateLogMessagePara2 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.DEBUG,
                            MessageCode := 0,
                            MessageText := 'Command.EmitterID[{2}] = {1}',
                            Para1       :=  SINT_TO_STRING(_command.EmitterID[_idx]),
                            Para2       :=  DINT_TO_STRING(_idx));
  END_FOR
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for ListenerID
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.ListenerID = {1}',
                          Para1       :=  SINT_TO_STRING(_command.ListenerID));
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Reserve
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.Reserve = {1}',
                          Para1       :=  BYTE_TO_STRING(_command.Reserve));

END_METHOD

METHOD FB_init : BOOL
VAR_INPUT
  /// if TRUE, the retain variables are initialized (warm start / cold start)
  bInitRetains : BOOL;
  /// if TRUE, the instance afterwards gets moved into the copy code (online change)
  bInCopyCode  : BOOL;
END_VAR

  MyType := 'MC_CreateServerLogFB';
  
  ExecMode       := ExecutionMode.PARALLEL;
  Priority       := PriorityLevel.NORMAL;
  ProcessingMode := ProcessingModeEnum.PARALLEL;
  SequenceFlag   := SequenceFlagEnum.NO_SEQUENCE;

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
    OutCmd.OriginID          := _response.OriginID;
    OutCmd.InvocationCounter := _response.InvocationCounter;
    OutCmd.ServerLogID       := _response.ServerLogID;
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
  
    01:  // ProcessingMode DEACTIVATE + new rising edge of Execute while the command runs (triggered):
         // the same command again with execution mode Stop, the RC ends it with DONE
         IF ( _executeRestart_R.Q ) AND ( ProcessingMode = ProcessingModeEnum.DEACTIVATE )
         THEN
           // inc parameter sequence
          _command.ParSeq := _command.ParSeq + 1;
           // update command data (execution mode Stop)
           CommandData := CreateCommandPayload(AxesGroup := AxesGroup);
           // notify active command register
           AxesGroup.Acyclic.ActiveCommandRegister.NotifyParameterChanged := _uniqueID;
         END_IF
  
         // Wait for responce received
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
                                          ParameterAccepted  := TRUE;
    // Buffered in planner for future execution
    CmdMessageState.BUFFERED_IN_PLANNER : CommandBuffered    := TRUE;
                                          ParameterAccepted  := TRUE;
    // Currently active and in progress
    CmdMessageState.ACTIVE              :;
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
// Table 6-117: Received CMD payload (RC to PLC) of "CreateServerLog"
// --------------------------
// Header
// --------------------------
// Byte 00 : USINT   - ParSeq | State
// Byte 01 : SINT    - AlarmMessageSeverity
// Byte 02 : UINT    - AlarmMessageCode HB
// Byte 03 :         - AlarmMessageCode LB
// --------------------------
// Datablock
// --------------------------
// Byte 04 : USINT   - InvocationCounter
// Byte 05 : SINT    - Reserved
// Byte 06 : INT     - OriginID HB
// Byte 07 :         - OriginID LB
// Byte 08 : INT     - ServerLogID HB
// Byte 09 :         - ServerLogID LB
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
    // Get Response.InvocationCounter
   _response.InvocationCounter := ResponseData.GetUsint();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.Reserve
   _response.Reserve := ResponseData.GetSint();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.OriginID
   _response.OriginID := ResponseData.GetInt();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.ServerLogID
   _response.ServerLogID := ResponseData.GetInt();
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
  // Create log entry for InvocationCounter
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.InvocationCounter = {1}',
                          Para1       :=  USINT_TO_STRING(_response.InvocationCounter));
  
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
                          Para1       :=  SINT_TO_STRING(_response.Reserve));
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for OriginID
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.OriginID = {1}',
                          Para1       :=  INT_TO_STRING(_response.OriginID));
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for ServerLogID
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.ServerLogID = {1}',
                          Para1       :=  INT_TO_STRING(_response.ServerLogID));

END_METHOD

METHOD PROTECTED Reset : DINT
VAR_INPUT
END_VAR

  Reset := SUPER^.Reset();
  
  Done               := FALSE;
  Busy               := FALSE;
  ParameterAccepted  := FALSE;
  CommandBuffered    := FALSE;
  CommandAborted     := FALSE;
  CommandInterrupted := FALSE;

END_METHOD

