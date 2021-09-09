// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

library Attributes {

  uint8 public constant SIZE = 9; // 255 attrs seems enough.

  struct Values {
    uint8 vigor;
    uint8 attunement;
    uint8 endurance;
    uint8 vitality;
    uint8 str;
    uint8 dex;
    uint8 intt;
    uint8 fth;
    uint8 luck;
  }
}
