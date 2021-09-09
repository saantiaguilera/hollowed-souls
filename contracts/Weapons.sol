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

  mapping(uint256 => Weapon) private availableWeapons; // all available weapons with their base attributes.

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

  modifier existingWeapon(uint256 weaponID) {
    require(bytes(availableWeapons[weaponID].name).length > 0, "weapon doesn't exist");
    _;
  }

  // mint creates a new weapon. Weapons can't be created directly, as they are either found or dropped.
  function mint(
    address minter,
    uint256 weaponID // ,
    // uint256 seed
  ) public restricted existingWeapon(weaponID) {

    uint256 tokenID = weapons.length;
    weapons.push(availableWeapons[weaponID]); // TODO: Use seed to modify weapon
    _safeMint(minter, tokenID);
    emit NewWeapon(minter, tokenID);
  }
}
