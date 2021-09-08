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
  string public constant CHARACTER_TYPE_SORCERER = "Sorcerer";
  string public constant CHARACTER_TYPE_PYROMANCER = "Pyromancer";
  string public constant CHARACTER_TYPE_CLERIC = "Cleric";
  string public constant CHARACTER_TYPE_DEPRIVED = "Deprived";

  int private constant PLAYER_METADATA_OWNS_CHARACTER = 1 << 0; // If the player already has a character

  event NewCharacter(address indexed minter, uint256 indexed character);

  struct Character {
    string name;

    uint level;

    uint vigor;
    uint attunement;
    uint endurance;
    uint vitality;
    uint str;
    uint dex;
    uint intt;
    uint fth;
    uint luck;
  }

  mapping(address => uint) private soulsByPlayer;
  mapping(address => int) private playerMetadata;
  mapping(address => Character) private charactersByPlayer;

  mapping(string => uint[]) private startingClassesAttrs;

  Character[] private characters;

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
  }

  // onlyNonContract is a super simple modifier to shallowly detect if the address is a contract or not.
  modifier onlyNonContract() {
    require(tx.origin == msg.sender, "Contracts not allowed");
    _;
  }

  // noCharacter asserts that the owner has no characters.
  modifier noCharacter(address owner) {
    require((playerMetadata[owner] & PLAYER_METADATA_OWNS_CHARACTER) == 0, "Owner already has a character");
    _;
  }

  // hasCharacter asserts that the owner has a character.
  modifier hasCharacter(address owner) {
    require((playerMetadata[owner] & PLAYER_METADATA_OWNS_CHARACTER) == PLAYER_METADATA_OWNS_CHARACTER, "Owner has no character");
    _;
  }

  // mint a character of the given starting class.
  function mint(string startingClass, string name) public onlyNonContract {
    uint[] attrs = startingClassesAttrs[startingClass];
    require(attrs.length == 9, "Unknown starting class");

    _mintCharacter(name, attrs);
  }

  function getSelfCharacter() public view hasCharacter(msg.sender) returns(Character) {
    return charactersByPlayer[msg.sender];
  }

  function _mintCharacter(string name, uint[] attrs) private noCharacter(msg.sender) {
    uint tokenID = characters.length;
    Character char = Character(
      name,
      -89, // 10 base stats * 9 attributes - 1 starting level
      attrs[0], attrs[1], attrs[2], attrs[3], attrs[4], attrs[5], attrs[6], attrs[7], attrs[8]
    );

    // apply class stats to level
    for (uint8 i = 0; i < attrs.length; i++) {
      char.level += attrs[i];
    }

    characters.push(char);
    charactersByPlayer[msg.sender] = char;
    playerMetadata[msg.sender] |= PLAYER_METADATA_OWNS_CHARACTER;
    _safeMint(msg.sender, tokenID);
    emit NewCharacter(msg.sender, tokenID);
  }
}
