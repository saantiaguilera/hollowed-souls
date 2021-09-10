// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

library SafeCast {

  function toUint8(uint256 a) internal pure returns (uint8) {
    uint8 b = uint8(a);
    assert(b == a);
    return b;
  }

  function toUint16(uint256 a) internal pure returns (uint16) {
    uint16 b = uint16(a);
    assert(b == a);
    return b;
  }
}