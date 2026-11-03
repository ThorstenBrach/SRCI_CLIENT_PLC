{attribute 'pack_mode' := '1'}
// -------------------------------------------------------------------------
//  SRCI Robot Library
// -------------------------------------------------------------------------
//
//  Object:      ReadSafeReferencePositionSendData
//  Author:      Thorsten Brach
//  Date:        2026-10-25
//
//  Description:
//    Sent CMD payload of ReadSafeReferencePosition (spec table 6-831).
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
TYPE ReadSafeReferencePositionSendData EXTENDS CmdHeader :
STRUCT
  /// Safe referencing position index (0: invalid, >0: index of the safe reference position)
  Index : USINT;
END_STRUCT
END_TYPE


