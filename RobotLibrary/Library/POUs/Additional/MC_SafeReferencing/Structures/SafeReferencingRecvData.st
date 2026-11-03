{attribute 'pack_mode' := '1'}
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      SafeReferencingRecvData
//  Author:      Thorsten Brach
//  Date:        2026-10-25
//
//  Description:
//    Received CMD payload of SafeReferencing (spec table 6-839).
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
TYPE SafeReferencingRecvData EXTENDS RspHeader :
STRUCT
  /// Status of the referencing process:
  /// • 0: Safe referencing not started
  /// • 1: Safe referencing in progress
  /// • 2: Referencing successfully completed for all required positions
  /// • 3: Additional position needs to be referenced
  /// • 4: Additional user input required
  Status : USINT;
END_STRUCT
END_TYPE


