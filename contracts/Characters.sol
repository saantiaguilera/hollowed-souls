// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract Characters is Initializable, ERC721Upgradeable, AccessControlUpgradeable {

  string public constant CHARACTER_TYPE_KNIGHT = "Knight";
  string public constant CHARACTER_TYPE_MERCENARY = "Mercenary";
  string public constant CHARACTER_TYPE_WARRIOR = "Warrior";
  string public constant CHARACTER_TYPE_HERALD = "Herald";
  string public constant CHARACTER_TYPE_THIEF = "Thief";
  string public constant CHARACTER_TYPE_ASSASSIN = "Assassin";
  string public constant CHARACTER_TYPE_SORCERER = "Sorcercer";
  string public constant CHARACTER_TYPE_PYROMANCER = "Pyromancer";
  string public constant CHARACTER_TYPE_CLERIC = "Cleric";
  string public constant CHARACTER_TYPE_DEPRIVED = "Deprived";

  uint8 private constant ATTRS_NUM = 9; // 255 attrs seems enough.

  uint16 private constant PLAYER_MAX_LEVEL = 99 * ATTRS_NUM;

  uint private constant LVLUP_BASE_SOULS_COST = 673; // Base souls cost for levelling up (from lvl 1->2).
  uint private constant LVLUP_MULTIPLIER_COST = 1027; // Base multiplier cost for levelling up (2,7%)

  event NewCharacter(address indexed minter, uint256 indexed character);

  struct Character {
    string name;

    uint16 level;

    Attribute attrs;
  }

  struct Attribute {
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

  mapping(address => uint) private soulsByPlayer;

  mapping(string => uint8[]) private startingClassesAttrs;

  Character[] private characters;

  uint256[] private lvlUpSoulsCost;

  function initialize() public initializer {
    __ERC721_init("HollowedSouls character", "HSC");
    __AccessControl_init_unchained();

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

    // TODO: Consider making it part of a migration
    startingClassesAttrs[CHARACTER_TYPE_KNIGHT] = [12, 10, 11, 15, 13, 12,  9,  9,  7];
    startingClassesAttrs[CHARACTER_TYPE_MERCENARY] = [11, 12, 11, 10, 10, 16, 10,  8,  9]; 
    startingClassesAttrs[CHARACTER_TYPE_WARRIOR] = [14,  6, 12, 11, 16,  9,  8,  9, 11];
    startingClassesAttrs[CHARACTER_TYPE_HERALD] = [12, 10,  9, 12, 12, 11,  8, 13, 11];
    startingClassesAttrs[CHARACTER_TYPE_THIEF] = [10, 11, 10,  9,  9, 13, 10,  8, 14];
    startingClassesAttrs[CHARACTER_TYPE_ASSASSIN] = [10, 14, 11, 10, 10, 14, 11,  9, 10];
    startingClassesAttrs[CHARACTER_TYPE_SORCERER] = [9, 16,  9,  7,  7, 12, 16,  7, 12];
    startingClassesAttrs[CHARACTER_TYPE_PYROMANCER] = [11, 12, 10,  8, 12,  9, 14, 14,  7];
    startingClassesAttrs[CHARACTER_TYPE_CLERIC] = [10, 14,  9,  7, 12,  8,  7, 16, 13];
    startingClassesAttrs[CHARACTER_TYPE_DEPRIVED] = [10, 10, 10, 10, 10, 10, 10, 10, 10];

    lvlUpSoulsCost.push(LVLUP_BASE_SOULS_COST); // Initial lvl up cost
    for (uint i = 1; i < PLAYER_MAX_LEVEL; i++) { // First lvl is precomputed
      lvlUpSoulsCost.push((lvlUpSoulsCost[i-1] * LVLUP_MULTIPLIER_COST) / 1000);
    }
  }

  // onlyNonContract is a super simple modifier to shallowly detect if the address is a contract or not.
  modifier onlyNonContract() {
    require(tx.origin == msg.sender, "Contracts not allowed");
    _;
  }

  // noCharacter asserts that the owner has no characters.
  modifier noCharacter(address owner) {
    require(balanceOf(owner) == 0, "Owner already has a character");
    _;
  }

  // hasCharacter asserts that the owner has a character.
  modifier hasCharacter(address owner) {
    require(balanceOf(owner) == 1, "Owner has no character");
    _;
  }

  modifier allowedAttributes(uint8[] memory attrs) {
    require(attrs.length == ATTRS_NUM, "attrs size is unexpected");
    _;
  }

  // mint a character of the given starting class.
  function mint(
    string memory startingClass, 
    string memory name
  ) public onlyNonContract allowedAttributes(startingClassesAttrs[startingClass]) {

    _mintCharacter(name, startingClassesAttrs[startingClass]);
  }

  // levelUp a character
  function levelUp(
    uint8[] memory attrs
  ) public hasCharacter(msg.sender) allowedAttributes(attrs) {

    uint16 spentLvls = 0; // Compute how much levels the sender is trying to use
    for (uint8 i = 0; i < ATTRS_NUM; i++) {
      spentLvls += uint16(attrs[i]);
    }
    require(spentLvls > 0, "no levels to spend");

    uint256 tokenID = tokenOfOwnerByIndex(msg.sender, 0);
    uint16 currentLvl = characters[tokenID].level;
    require(spentLvls + currentLvl < PLAYER_MAX_LEVEL, "levelling up overflows max lvl");

    uint256 soulsRequired = 0; // Check souls needed and if they are available
    for (uint16 i = 0; i < spentLvls; i++) {
      soulsRequired += lvlUpSoulsCost[i+currentLvl]; // TODO: Use safemath
    }
    require(soulsRequired <= soulsByPlayer[msg.sender], "not enough souls");

    // Apply levels
    soulsByPlayer[msg.sender] -= soulsRequired;
    characters[tokenID].level += spentLvls;
    _applyAttributes(tokenID, attrs);
  }

  function _mintCharacter(string memory name, uint8[] memory attrs) private noCharacter(msg.sender) {
    uint tokenID = characters.length;
    int8 lvl = -89; // 10 base stats * 9 attributes - 1 starting level

    // apply class stats to level
    for (uint8 i = 0; i < ATTRS_NUM; i++) {
      lvl += int8(attrs[i]);
    }
    require(lvl > 0, "class attributes are lower than the base allowance");

    characters.push(Character(
      name,
      uint16(lvl),
      Attribute(0, 0, 0, 0, 0, 0, 0, 0, 0) // Empty struct, we fill it later
    ));
    _safeMint(msg.sender, tokenID);
    _applyAttributes(tokenID, attrs);
    emit NewCharacter(msg.sender, tokenID);
  }

  function _applyAttributes(uint256 id, uint8[] memory attrs) private allowedAttributes(attrs) {
    Character storage char = characters[id]; // TODO: Use safemath
    char.attrs.vigor += attrs[0];
    char.attrs.attunement += attrs[1];
    char.attrs.endurance += attrs[2];
    char.attrs.vitality += attrs[3];
    char.attrs.str += attrs[4];
    char.attrs.dex += attrs[5];
    char.attrs.intt += attrs[6];
    char.attrs.fth += attrs[7];
    char.attrs.luck += attrs[8];
  }
}