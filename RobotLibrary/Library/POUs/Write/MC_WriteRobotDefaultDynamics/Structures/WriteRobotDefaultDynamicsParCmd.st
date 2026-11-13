{attribute 'pack_mode' := '1'} 
// ------------------------------------------------------------------------- 
//  SRCI Robot Library                                                
// ------------------------------------------------------------------------- 
//                                                                           
//  Object:      WriteRobotDefaultDynamicsParCmd                                       
//  Author:      Thorsten Brach                                                
//  Date:        2024-08-08
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
TYPE WriteRobotDefaultDynamicsParCmd :
STRUCT
  /// Default dynamics values according to Table 6-165.
  DynamicValues          : DefaultDynamics := ( VelocityRate := -1.0, AccelerationRate := -1.0, DecelerationRate := -1.0, JerkRate := -1.0); // ST-FIX F126: spec 6.2.13 / 6.2.14: input of the write command, default '<0' = do not change; 0.0 wrote 0 (minimum) for every value that was not set
END_STRUCT
END_TYPE


