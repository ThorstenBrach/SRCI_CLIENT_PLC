{attribute 'pack_mode' := '1'}
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      ReadSafeReferencePositionParCmd
//  Author:      Thorsten Brach
//  Date:        2026-10-25
//
//  Description:
//    Parameters of ReadSafeReferencePosition (spec table 6-827).
//    F109: new data type (SRCI command 7009 ReadSafeReferencePosition, spec 6.5.38)
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
TYPE ReadSafeReferencePositionParCmd :
STRUCT
  /// Safe referencing position index
  /// • 0: Invalid
  /// • 1 (default): Read safe reference position 1
  /// • >1: Read the safe reference position according to the index, if available
  Index : USINT := 1;
END_STRUCT
END_TYPE


