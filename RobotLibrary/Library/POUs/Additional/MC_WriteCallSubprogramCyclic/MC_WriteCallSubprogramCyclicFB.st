/// Writes cyclic data of called subprogram
FUNCTION_BLOCK MC_WriteCallSubprogramCyclicFB EXTENDS RobotLibraryBaseEnableFB
// ------------------------------------------------------------------------- 
//  SRCI Robot Library                                                
// ------------------------------------------------------------------------- 
//                                                                           
//  Object:      WriteCallSubprogramCyclicFB                                       
//  Author:      Thorsten Brach                                                
//  Date:        2024-06-01
//
//  Description:                                              
//   
//                                                                           
//  Copyright: 
//    (C) 2024 Thorsten Brach. All rights reserved                                                                                                                                            
//             Licensed under the MIT License.
//                                                                           
//  Disclaimer:                                                                           
//    This project is provided without any guarantee and can be used for   
//    private and commercial purposes. Any use is at the user’s 
//    own risk and responsibility.
//
// -------------------------------------------------------------------------
VAR_INPUT
  /// command parameter
  ParCmd  : WriteCallSubprogramCyclicParCmd;
END_VAR

VAR_OUTPUT
  /// command outputs
  OutCmd  : WriteCallSubprogramCyclicOutCmd;
END_VAR

  SUPER^(AxesGroup := AxesGroup);

END_FUNCTION_BLOCK

METHOD PROTECTED CheckFunctionSupported : BOOL
VAR_IN_OUT
  /// Robot assignment of function
  AxesGroup : AxesGroup; 
END_VAR

  CheckFunctionSupported := AxesGroup.State.RobotData.RCSupportedFunctions.WriteCallSubprogramCyclic;
  
  IF ( NOT CheckFunctionSupported )
  THEN
    // call base implementation for set error and create log entry
    SUPER^.CheckFunctionSupported(AxesGroup := AxesGroup);
  END_IF

END_METHOD

METHOD FB_init : BOOL
VAR_INPUT
  /// if TRUE, the retain variables are initialized (warm start / cold start)
  bInitRetains : BOOL; 
  /// if TRUE, the instance afterwards gets moved into the copy code (online change)
  bInCopyCode  : BOOL;  
END_VAR

  MyType := 'MC_WriteCallSubprogramCyclicFB';
  
  ExecMode := ExecutionMode.PARALLEL;
  Priority := PriorityLevel.NORMAL;

END_METHOD

METHOD PROTECTED OnExecErrorClear : DINT
VAR_IN_OUT
  /// Robot assignment of function
  AxesGroup : AxesGroup; 
END_VAR

  // Overwrite base implementation, because FB does not send telegrams via ACR
  OnExecErrorClear := Reset();

END_METHOD

METHOD PROTECTED OnExecRun : DINT
VAR_IN_OUT
  /// Robot assignment of function
  AxesGroup : AxesGroup; 
END_VAR

  // call base implementation
  SUPER^.OnExecRun(AxesGroup := AxesGroup);
  
  // configures the optional cyclic data area of the message frame (applied with the next initialization)
  AxesGroup.Parameter.Plc.OptionalCyclic.UseCallSubprogram := Enable;
  
  // ST-FIX F136: step chain like MC_ReadCallSubprogramCyclicFB (spec 6.5.19): the function must be
  // supported, "Enabled" while the cyclic area is active and "Data" is written only while enabled
  CASE _stepCmd OF
    
    00:  IF ( _enable_R.Q ) AND ( NOT Error )
         THEN
           // reset the rising edge
          _enable_R();
           // Check function is supported ?
           IF ( CheckFunctionSupported( AxesGroup := AxesGroup ))
           THEN
             // Reset all internal flags
             Reset();
             // set busy flag
             Busy := TRUE;
             // inc step counter
            _stepCmd := _stepCmd + 1;
           END_IF
         END_IF
  
    01:  // Wait for the cyclic area of the message frame
         IF ( AxesGroup.CyclicOptional.PlcToRob.SubProgramData.Active )
         THEN
           Busy    := FALSE;
           Enabled := TRUE;
           // write the data to the RC
           AxesGroup.CyclicOptional.PlcToRob.SubProgramData.Data := ParCmd.Data;
         END_IF
         
         IF ( _enable_F.Q )
         THEN
           // reset the falling edge
          _enable_F();
           // inc step counter
          _stepCmd := _stepCmd + 1;
         END_IF
  
    02:  IF ( NOT Enable )
         THEN
           Reset();
         END_IF
  
  ELSE
    // invalid step
    SetError( ErrorID := RobotLibraryErrorIdEnum.ERR_INVALID_STEP, Overwrite := TRUE );
  END_CASE
  
  // Reset FB
  IF (( _enable_R.Q ) OR
      ( _enable_F.Q ))
  THEN
    Reset();
  END_IF

END_METHOD

