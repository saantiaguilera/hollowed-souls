// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

library Conversion {

  function toBytes(uint _i) internal pure returns (bytes memory bs) {
    if (_i == 0) {
      return "0";
    }
    uint j = _i;
    uint len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory buf = new bytes(len);
    uint k = len;
    while (_i != 0) {
      k = k-1;
      uint8 temp = (48 + uint8(_i - _i / 10 * 10));
      bytes1 b1 = bytes1(temp);
      buf[k] = b1;
      _i /= 10;
    }
    return buf;
  }
}