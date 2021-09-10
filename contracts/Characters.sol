// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./math/SafeMath16.sol";
import "./math/SafeMath8.sol";
import "./Attributes.sol";

contract Characters is Initializable, ERC721Upgradeable, AccessControlUpgradeable {
  
  using SafeMath16 for uint16;
  using SafeMath8 for uint8;

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

  uint16 private constant PLAYER_MAX_LEVEL = 99 * 9; // 9 == Attributes.SIZE, solc can't infer it at compile time

  uint private constant LVLUP_BASE_SOULS_COST = 673; // Base souls cost for levelling up (from lvl 1->2).
  uint private constant LVLUP_MULTIPLIER_COST = 1027; // Base multiplier cost for levelling up (2,7%)

  event NewCharacter(address indexed minter, uint256 indexed character);
  event LevelUp(address indexed owner, uint256 indexed character, uint16 indexed level);

  struct Character {
    string name;

    uint16 level;

    Attributes.Values attrs;
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
      lvlUpSoulsCost.push(lvlUpSoulsCost[i-1].mul(LVLUP_MULTIPLIER_COST).div(1000));
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
    require(attrs.length == Attributes.SIZE, "attrs size is unexpected");
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
    for (uint8 i = 0; i < Attributes.SIZE; i++) {
      spentLvls = spentLvls.add(attrs[i]);
    }
    require(spentLvls > 0, "no levels to spend");

    uint256 tokenID = tokenOfOwnerByIndex(msg.sender, 0);
    uint16 currentLvl = characters[tokenID].level;
    require(spentLvls.add(currentLvl) < PLAYER_MAX_LEVEL, "levelling up overflows max lvl");

    uint256 soulsRequired = 0; // Check souls needed and if they are available
    for (uint16 i = 0; i < spentLvls; i++) {
      soulsRequired = soulsRequired.add(lvlUpSoulsCost[i.add(currentLvl)]);
    }
    require(soulsRequired <= soulsByPlayer[msg.sender], "not enough souls");

    // Apply levels
    soulsByPlayer[msg.sender] = soulsByPlayer[msg.sender].sub(soulsRequired);
    characters[tokenID].level = characters[tokenID].level.add(spentLvls);
    _applyAttributes(tokenID, attrs);
    emit LevelUp(msg.sender, tokenID, currentLvl.add(spentLvls));
  }

  function _mintCharacter(string memory name, uint8[] memory attrs) private noCharacter(msg.sender) {
    uint tokenID = characters.length;
    int8 lvl = -89; // 10 base stats * 9 attributes - 1 starting level // TODO: Make it constant

    // apply class stats to level
    for (uint8 i = 0; i < Attributes.SIZE; i++) {
      lvl += int8(attrs[i]); // cast is safe. initial attributes don't even surpass a word
    }
    require(lvl > 0, "class attributes are lower than the base allowance");

    characters.push(Character(
      name,
      uint16(lvl),
      Attributes.Values(0, 0, 0, 0, 0, 0, 0, 0, 0) // Empty struct, we fill it later
    ));
    _safeMint(msg.sender, tokenID);
    _applyAttributes(tokenID, attrs);
    emit NewCharacter(msg.sender, tokenID);
  }

  function _applyAttributes(uint256 id, uint8[] memory attrs) private allowedAttributes(attrs) {
    Character storage char = characters[id];
    char.attrs.vigor = char.attrs.vigor.add(attrs[0]);
    char.attrs.attunement = char.attrs.attunement.add(attrs[1]);
    char.attrs.endurance = char.attrs.endurance.add(attrs[2]);
    char.attrs.vitality = char.attrs.vitality.add(attrs[3]);
    char.attrs.str = char.attrs.str.add(attrs[4]);
    char.attrs.dex = char.attrs.dex.add(attrs[5]);
    char.attrs.intt = char.attrs.intt.add(attrs[6]);
    char.attrs.fth = char.attrs.fth.add(attrs[7]);
    char.attrs.luck = char.attrs.luck.add(attrs[8]);
  }
}