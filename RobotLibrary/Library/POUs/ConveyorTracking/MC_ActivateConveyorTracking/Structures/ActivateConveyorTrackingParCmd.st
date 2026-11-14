{attribute 'pack_mode' := '1'} 
// ------------------------------------------------------------------------- 
//  SRCI Robot Library                                                
// ------------------------------------------------------------------------- 
//                                                                           
//  Object:      ActivateConveyorTrackingParCmd                                       
//  Author:      Thorsten Brach                                                
//  Date:        2024-06-11
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
TYPE ActivateConveyorTrackingParCmd :
STRUCT
  /// Index of assigned conveyor
  ConveyorNo         : USINT; // ST-FIX F175: ConveyorNo / ConnectionMode are USINT (6.3.26 application layer and CML; the SINT of the telegram table 6-460 is a copy error, all other conveyor telegrams have USINT)
  /// Specifies encoder connection setup (at least one option must be supported)
  ConnectionMode     : ConnectionMode;
  /// Relates to "ConnectionMode" 1 – "PLC connected": Value of the encoder connected to the conveyor belt
  PLCEncoderValue    : REAL;
END_STRUCT
END_TYPE


