/// Read a server log of the RC line by line into LogFile
FUNCTION_BLOCK MC_ReadServerLogFB EXTENDS RobotLibraryBaseExecuteFB
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      MC_ReadServerLogFB
//  Author:      Thorsten Brach
//  Date:        2026-10-23
//
//  Description:
//    ReadServerLog (spec 6.2.6, type 9004): reads the server log ParCmd.ServerLogID from
//    ParCmd.StartLine on into the array LogFile, one CSV line per element. The RC sends a log line in
//    parts of up to 179 characters; the block joins them. The transfer ends with Done when the RC
//    reports the end of the log or when LogFile is full. A rising edge of Execute during the transfer
//    starts it again.
//    Telegram layout of SRCI SDK 1.1.2 (Offset as request counter, IsStartOfLine / IsEndOfLine /
//    EndOfLogReached / LogLine in the response); spec table 6-123 / 6-124 differ.
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
  ParCmd          : ReadServerLogParCmd;
END_VAR
VAR_OUTPUT
  /// Command is transferred and confirmed by the RC
  CommandBuffered : BOOL;
  /// command outputs
  OutCmd          : ReadServerLogOutCmd;
END_VAR
VAR_IN_OUT
  /// Requested log file: one log line per element
  LogFile         : ARRAY [*] OF STRING(RobotLibraryParameter.LOG_LINE_LEN);
END_VAR
VAR
  /// internal copy of command parameter
 _parCmd          : ReadServerLogParCmd;
  /// command data to send
 _command         : ReadServerLogSendData;
  /// response data received
 _response        : ReadServerLogRecvData;
  /// a part of the log was received and must be stored in LogFile (StoreLogContent)
 _contentReceived : BOOL;
  /// the response to the current Offset was handled
 _offsetHandled   : BOOL;
  /// new rising edge of Execute during the transfer: start again after the end of this one
 _restart         : BOOL;
  /// index of the element of LogFile for the current log line
 _line            : DINT;
  /// number of elements of LogFile used by this transfer
 _lines           : DINT;
  /// a log line is open (parts received, end of line not yet)
 _lineOpen        : BOOL;
  /// characters of the current log line
 _lineLen         : DINT;
  /// characters copied from the received part
 _copyLen         : DINT;
END_VAR

  SUPER^(AxesGroup := AxesGroup);
  
  // store the received part of the log (LogFile is only reachable in the call of the block)
  StoreLogContent( AxesGroup := AxesGroup, LogFile := LogFile );

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

  // ReadServerLog is a mandatory function of the profile Core (spec table 6-119): the RC
  // reports no bit for it in RCSupportedFunctions
  CheckFunctionSupported := TRUE;

END_METHOD

METHOD PROTECTED CheckParameterChanged : BOOL
VAR_IN_OUT
  /// Robot assignment of function
  AxesGroup    : AxesGroup;
END_VAR

  // The parameters of the transfer are taken with the rising edge of Execute; during the transfer
  // only the block itself sends updates (next part of the log: Offset, end: Enable FALSE)
  IF ( _stepCmd = 0 )
  THEN
    RETURN;
  END_IF
  
  IF ( _parameterUpdateInternal )
  THEN
    // reset internal flag for send parameter update
   _parameterUpdateInternal := FALSE;
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
  
  // Check ParCmd.ExportMode: only 0 (output LogFile), the export to a file is optional (table 6-119)
  IF ( ParCmd.ExportMode <> 0 )
  THEN
    // Parameter not valid
    CheckParameterValid := FALSE;
    // Set error
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_EXPORTMODE_NOT_EXIST, Overwrite := TRUE );
    // Create log entry
    CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.ERROR,
                            MessageCode := ErrorID,
                            MessageText := 'Invalid Parameter ParCmd.ExportMode = {1}',
                            Para1       := USINT_TO_STRING(ParCmd.ExportMode));
    RETURN;
  END_IF
  
  // Check ParCmd.StartLine: the first line is 1 (log header)
  IF ( ParCmd.StartLine = 0 )
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
                            MessageText := 'Invalid Parameter ParCmd.StartLine = {1}',
                            Para1       := UDINT_TO_STRING(ParCmd.StartLine));
    RETURN;
  END_IF
  
  // Check ParCmd.ServerLogID: -1 (latest), 0 (oldest) or an ID
  IF ( ParCmd.ServerLogID < -1 )
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
                            MessageText := 'Invalid Parameter ParCmd.ServerLogID = {1}',
                            Para1       := INT_TO_STRING(ParCmd.ServerLogID));
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
// Sent CMD payload (PLC to RC) of "ReadServerLog" - layout of SRCI SDK 1.1.2 (spec table 6-123
// has no Offset, ContextFilter at byte 12)
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
// Byte 04 : BYTE  - Bit 0: Enable
// Byte 05 : BYTE  - Reserved
// Byte 06 : UINT  - ServerLogID HB
// Byte 07 :       - ServerLogID LB
// Byte 08 : UDINT - StartLine
// Byte 12 : UDINT - Offset
// Byte 16 : USINT - ContextFilter[0]
// ...
// Byte 25 : USINT - ContextFilter[9]
// --------------------------

  // set command parameter
  _command.CmdTyp      :=  CmdType.ReadServerLog;
  // spec table 6-121: parallel only (default of ExecMode, FB_init)
  _command.ExecMode    :=  ExecMode;
  _command.ParSeq      := _command.ParSeq;
  _command.Priority    :=  Priority;
  _command.Reserve     := 0;
  // -1 (latest) -> 16#FFFF
  _command.ServerLogID := INT_TO_UINT(_parCmd.ServerLogID);
  _command.StartLine   := _parCmd.StartLine;
  FOR _idx := 0 TO 9
  DO
    _command.ContextFilter[_idx] := _parCmd.ContextFilter[_idx];
  END_FOR
  
  // copy command data to header
  _cmdHeader := _command;
  // call base implementation to copy header to payload buffer
  CreateCommandPayload := SUPER^.CreateCommandPayload(AxesGroup := AxesGroup);
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.Enable
    CreateCommandPayload.AddBool(_command.Enable);
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
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.ServerLogID
    CreateCommandPayload.AddUint(_command.ServerLogID);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.StartLine
    CreateCommandPayload.AddUdint(_command.StartLine);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  // Check parameter must be added ?
  IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
  THEN
    // add command.Offset
    CreateCommandPayload.AddUdint(_command.Offset);
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  FOR _idx := 0 TO 9
  DO
    // Check parameter must be added ?
    IF ( CheckAddParameter(CreateCommandPayload.PayloadPtr))
    THEN
      // add command.ContextFilter[x]
      CreateCommandPayload.AddUsint(_command.ContextFilter[_idx]);
      // inc parameter counter
     _parameterCnt := _parameterCnt + 1;
    END_IF
  END_FOR
  
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
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Command.Enable
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.Enable = {1}',
                          Para1       :=  BOOL_TO_STRING(_command.Enable));
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Command.Reserve
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.Reserve = {1}',
                          Para1       :=  BYTE_TO_STRING(_command.Reserve));
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Command.ServerLogID
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.ServerLogID = {1}',
                          Para1       :=  UINT_TO_STRING(_command.ServerLogID));
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Command.StartLine
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.StartLine = {1}',
                          Para1       :=  UDINT_TO_STRING(_command.StartLine));
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Command.Offset
  CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Command.Offset = {1}',
                          Para1       :=  UDINT_TO_STRING(_command.Offset));
  
  FOR _idx := 0 TO 9
  DO
    // Return if no parameter is remaining...
    IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
    // dec remaining parameter(s)
    ParameterCnt := ParameterCnt - 1;
    // Create log entry for Command.ContextFilter
    CreateLogMessagePara2 ( Timestamp   := AxesGroup.State.SystemTime,
                            MessageType := MessageType.CMD,
                            Severity    := Severity.DEBUG,
                            MessageCode := 0,
                            MessageText := 'Command.ContextFilter[{2}] = {1}',
                            Para1       :=  USINT_TO_STRING(_command.ContextFilter[_idx]),
                            Para2       :=  DINT_TO_STRING(_idx));
  END_FOR

END_METHOD

METHOD FB_init : BOOL
VAR_INPUT
  /// if TRUE, the retain variables are initialized (warm start / cold start)
  bInitRetains : BOOL;
  /// if TRUE, the instance afterwards gets moved into the copy code (online change)
  bInCopyCode  : BOOL;
END_VAR

  MyType := 'MC_ReadServerLogFB';
  
  // spec 6.2.6: processed with low priority because of its processing time
  ExecMode := ExecutionMode.PARALLEL;
  Priority := PriorityLevel.LOW;

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
  
  // the counters of the log come with every part (StoreLogContent), the received lines are counted there

END_METHOD

METHOD PROTECTED OnExecRun : DINT
VAR_IN_OUT
  /// Robot assignment of function
  AxesGroup : AxesGroup;
END_VAR

  // call base implementation
  SUPER^.OnExecRun(AxesGroup := AxesGroup);
  
  CASE _stepCmd OF
  
    00:  IF (( _execute_R.Q ) OR ( _restart )) AND ( NOT Error )
         THEN
          _restart := FALSE;
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
             // first element of LogFile, no open line
            _line            := 0;
            _lines           := 0;
            _lineOpen        := FALSE;
            _lineLen         := 0;
            _contentReceived := FALSE;
            _offsetHandled   := FALSE;
             // transfer on, first request
            _command.Enable := TRUE;
            _command.Offset := 1;
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
  
    01:  // spec 6.2.6: a new rising edge of Execute during the transfer aborts it and starts the
         // command again. SRCI SDK 1.1 keeps the read position of a running command, so the transfer
         // ends first (Enable FALSE) and the command is added again (new ACR entry).
         IF ( _executeRestart_R.Q ) AND ( NOT _restart )
         THEN
          _restart := TRUE;
          _command.Enable := FALSE;
          _parameterUpdateInternal := TRUE;
         END_IF
  
         // Wait for responce received
         IF ( _responseReceived )
         THEN
           // reset response received flag
          _responseReceived := FALSE;
  
           CASE _response.State OF
             CmdMessageState.DONE:
               IF ( _restart )
               THEN
                 // the old transfer ended: start again (step 00)
                 Reset();
                _restart := TRUE;
               ELSE
                 OnUpdateStateFlags(_response.State);
                 // set timeout
                 SetTimeout(PT := _timeoutCmd, rTimer := _timerCmd);
                 // inc step counter
                _stepCmd := _stepCmd + 1;
               END_IF
  
             CmdMessageState.ABORTED, CmdMessageState.ERROR:
              _restart := FALSE;
               OnUpdateStateFlags(_response.State);
               // set timeout
               SetTimeout(PT := _timeoutCmd, rTimer := _timerCmd);
               // inc step counter
              _stepCmd := _stepCmd + 1;
  
           ELSE
             OnUpdateStateFlags(_response.State);
             // a part of the log for the current request ? (responses to older requests are ignored)
             IF (( _command.Enable                     ) AND
                 ( NOT _restart                        ) AND
                 ( NOT _offsetHandled                  ) AND
                 ( _response.Offset = _command.Offset  ))
             THEN
              _offsetHandled   := TRUE;
              _contentReceived := TRUE;
             END_IF
           END_CASE
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
  IF ( NOT Execute ) AND ( NOT _restart )
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
    CmdMessageState.BUFFERED            : CommandBuffered := TRUE;
    // Buffered in planner for future execution
    CmdMessageState.BUFFERED_IN_PLANNER : CommandBuffered := TRUE;
    // Currently active and in progress
    CmdMessageState.ACTIVE              : CommandBuffered := TRUE;
    // Interrupted and awaiting continuation
    CmdMessageState.INTERRUPTED         :;
    // Requested for abort
    CmdMessageState.ABORT_REQUEST       :;
    // Successfully completed
    CmdMessageState.DONE                : Done            := TRUE;
                                          Busy            := FALSE;
    // Aborted before completion
    CmdMessageState.ABORTED             : Busy            := FALSE;
    // Encountered an error during execution
    CmdMessageState.ERROR               : Error           := TRUE;
                                          Busy            := FALSE;
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
  /// Byte 13: line flags
 _flags        : BYTE;
END_VAR
// Received CMD payload (RC to PLC) of "ReadServerLog" - layout of SRCI SDK 1.1.2 (spec table
// 6-124: byte 13 only IsSplitLine, LogContent from byte 14)
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
// Byte 04 : UDINT   - AvailableLogLines
// Byte 08 : UDINT   - AvailableFilteredLogLines
// Byte 12 : USINT   - LogContentLength
// Byte 13 : BYTE    - Bit 0: IsStartOfLine, Bit 1: IsEndOfLine, Bit 2: EndOfLogReached
// Byte 14 : UDINT   - LogLine
// Byte 18 : UDINT   - Offset
// Byte 22 : CHAR    - LogContent[0]
// ...
// Byte 200: CHAR    - LogContent[178]
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
    // Get Response.AvailableLogLines
   _response.AvailableLogLines := ResponseData.GetUdint();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.AvailableFilteredLogLines
   _response.AvailableFilteredLogLines := ResponseData.GetUdint();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.LogContentLength
   _response.LogContentLength := ResponseData.GetUsint();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.IsStartOfLine / IsEndOfLine / EndOfLogReached
   _flags                     := ResponseData.GetByte();
   _response.IsStartOfLine    := _flags.0;
   _response.IsEndOfLine      := _flags.1;
   _response.EndOfLogReached  := _flags.2;
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.LogLine
   _response.LogLine := ResponseData.GetUdint();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining)
  THEN
    // Get Response.Offset
   _response.Offset := ResponseData.GetUdint();
    // inc parameter counter
   _parameterCnt := _parameterCnt + 1;
  END_IF
  
  // Check payload remaining ?
  IF ( ResponseData.IsPayloadRemaining ) AND ( _response.LogContentLength > 0 )
  THEN
    // Get Response.LogContent (LogContentLength characters)
   _response.LogContent := ResponseData.GetString( Size := MIN( USINT_TO_DINT(_response.LogContentLength), RobotLibraryConstants.SERVER_LOG_CONTENT_MAX ));
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
  // Create log entry for AvailableLogLines
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.AvailableLogLines = {1}',
                          Para1       :=  UDINT_TO_STRING(_response.AvailableLogLines));
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for AvailableFilteredLogLines
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.AvailableFilteredLogLines = {1}',
                          Para1       :=  UDINT_TO_STRING(_response.AvailableFilteredLogLines));
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for LogContentLength
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.LogContentLength = {1}',
                          Para1       :=  USINT_TO_STRING(_response.LogContentLength));
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for IsStartOfLine
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.IsStartOfLine = {1}',
                          Para1       :=  BOOL_TO_STRING(_response.IsStartOfLine));
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for LogLine
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.LogLine = {1}',
                          Para1       :=  UDINT_TO_STRING(_response.LogLine));
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for Offset
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.Offset = {1}',
                          Para1       :=  UDINT_TO_STRING(_response.Offset));
  
  // Return if no parameter is remaining...
  IF ( ParameterCnt = 0 ) THEN RETURN; END_IF
  // dec remaining parameter(s)
  ParameterCnt := ParameterCnt - 1;
  // Create log entry for LogContent
  CreateLogMessagePara1 ( Timestamp   := Timestamp,
                          MessageType := MessageType.CMD,
                          Severity    := Severity.DEBUG,
                          MessageCode := 0,
                          MessageText := 'Response.LogContent = {1}',
                          Para1       :=  _response.LogContent);

END_METHOD

METHOD PROTECTED Reset : DINT
VAR_INPUT
END_VAR

  Reset := SUPER^.Reset();
  
  Done             := FALSE;
  Busy             := FALSE;
  CommandBuffered  := FALSE;
  _restart         := FALSE;
  _contentReceived := FALSE;
  _offsetHandled   := FALSE;
  _command.Enable  := FALSE;

END_METHOD

METHOD PRIVATE StoreLogContent
VAR_IN_OUT
  /// Robot assignment of function
  AxesGroup : AxesGroup;
  /// Requested log file: one log line per element
  LogFile : ARRAY [*] OF STRING(RobotLibraryParameter.LOG_LINE_LEN);
END_VAR
VAR
  /// LogFile is full
  Full : BOOL;
END_VAR

  IF ( NOT _contentReceived )
  THEN
    RETURN;
  END_IF
  _contentReceived := FALSE;
  
  OutCmd.AvailableLogLines         := _response.AvailableLogLines;
  OutCmd.AvailableFilteredLogLines := _response.AvailableFilteredLogLines;
  
  // a part of a log line ? (a response without log line: the RC had not read the log yet)
  IF ( _response.LogLine > 0 ) AND (( _response.LogContentLength > 0 ) OR ( _response.IsEndOfLine ))
  THEN
    // a new line starts in the next element of LogFile
    IF (( _response.IsStartOfLine ) OR ( NOT _lineOpen ))
    THEN
     _line  := LOWER_BOUND(LogFile, 1) + _lines;
     _lines := _lines + 1;
      SysDepMemSet( pDest := ADR(LogFile[_line]), Value := 0, DataLen := SIZEOF(LogFile[_line]) );
     _lineLen  := 0;
     _lineOpen := TRUE;
    END_IF
  
    // append the part (a line longer than LOG_LINE_LEN is cut)
   _copyLen := MIN( USINT_TO_DINT(_response.LogContentLength), RobotLibraryParameter.LOG_LINE_LEN - _lineLen );
    IF ( _copyLen > 0 )
    THEN
      SysDepMemCpy( pDest := ADR(LogFile[_line]) + _lineLen, pSrc := ADR(_response.LogContent), DataLen := DINT_TO_UDINT(_copyLen) );
     _lineLen := _lineLen + _copyLen;
    ELSIF ( _response.LogContentLength > 0 )
    THEN
      CreateLogMessagePara1 ( Timestamp   := AxesGroup.State.SystemTime,
                              MessageType := MessageType.CMD,
                              Severity    := Severity.WARNING,
                              MessageCode := 0,
                              MessageText := 'Log line {1} longer than LOG_LINE_LEN, cut',
                              Para1       := UDINT_TO_STRING(_response.LogLine));
    END_IF
  
    IF ( _response.IsEndOfLine )
    THEN
     _lineOpen               := FALSE;
      OutCmd.ReceivedLogLines := OutCmd.ReceivedLogLines + 1;
      OutCmd.LogLine          := _response.LogLine;
      IF ( _response.AvailableFilteredLogLines > 0 )
      THEN
        OutCmd.Progress := MIN( 100.0, UDINT_TO_REAL(OutCmd.ReceivedLogLines) * 100.0 / UDINT_TO_REAL(_response.AvailableFilteredLogLines) );
      END_IF
    END_IF
  END_IF
  
  OutCmd.EndOfLogReached := _response.EndOfLogReached;
  // no element of LogFile left for another line
  Full := ( NOT _lineOpen ) AND ( LOWER_BOUND(LogFile, 1) + _lines > UPPER_BOUND(LogFile, 1) );
  
  IF (( _response.EndOfLogReached ) OR ( Full ))
  THEN
    // end of the transfer: Enable FALSE, the RC answers with DONE
   _command.Enable := FALSE;
  ELSE
    // next part of the log
   _command.Offset := _command.Offset + 1;
   _offsetHandled  := FALSE;
  END_IF
  _parameterUpdateInternal := TRUE;

END_METHOD

