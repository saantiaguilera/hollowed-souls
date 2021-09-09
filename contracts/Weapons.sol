// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./Attributes.sol";

contract Weapons is Initializable, ERC721Upgradeable, AccessControlUpgradeable {

  event NewWeapon(address indexed minter, uint256 indexed weapon);

  struct Weapon {
    string name;
    Attributes.Values requirements;
    // add everything else
    // https://onedrive.live.com/view.aspx?resid=21B7F6A9C97C5D9A!123&ithint=file%2cxlsx&authkey=!AEhHSWMwAhQdP5o
  }

  Weapon[] private weapons;

  function initialize() public initializer {
    __ERC721_init("HollowedSouls weapon", "HSW");
    __AccessControl_init_unchained();

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  modifier restricted() {
    require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not game admin");
    _;
  }

  function _createWeapon1(uint256 seed) private {
    weapons.push(
      Weapon(
        "test weapon",
        Attributes.Values(0, 0, 0, 0, 0, 0, 0, 0, 0)
      )
    );
  }

  // mint creates a new weapon. Weapons can't be created directly, as they are either found or dropped.
  function mint(
    address minter,
    uint256 weaponID,
    uint256 seed
  ) public restricted {

    uint256 tokenID = weapons.length;
    // We use abi calls so we can define all weapons as contract functions instead of keeping
    // them stored in the contract. This allows us to retroactively balance it through proxy
    // upgrades without having to set/apply/deploy (depending on the strat) all of them again.
    string memory fn = string(abi.encodePacked("_createWeapon", uintToBytes(weaponID), "(uint256)"));
    (bool ret,) = address(this).call(
      abi.encodeWithSignature(fn, seed)
    ); 
    require(ret, "failure creating weapon");
    require(weapons.length == tokenID + 1, "weapon wasn't pushed to slice");

    _safeMint(minter, tokenID);
    emit NewWeapon(minter, tokenID);
  }

  function uintToBytes(uint _i) internal pure returns (bytes memory str) {
    if (_i == 0) {
      return "0";
    }
    uint j = _i;
    uint len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint k = len;
    while (_i != 0) {
      k = k-1;
      uint8 temp = (48 + uint8(_i - _i / 10 * 10));
      bytes1 b1 = bytes1(temp);
      bstr[k] = b1;
      _i /= 10;
    }
    return bstr;
  }
}
