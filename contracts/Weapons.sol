// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./math/SafeMath16.sol";
import "./math/SafeMath8.sol";
import "./math/SafeCast.sol";
import "./math/Conversion.sol";
import "./Attributes.sol";
import "./BasicRandom.sol";

contract Weapons is Initializable, ERC721Upgradeable, AccessControlUpgradeable {

  using Conversion for uint256;
  using SafeCast for uint256;
  using BasicRandom for uint256;
  using SafeMath16 for uint16;
  using SafeMath8 for uint8;

  string public constant WEAPON_TYPE_AXE = "Axe";

  uint16 private constant SC_NAN = 1000; // Same
  uint16 private constant SC_E = 1010;   // 1%
  uint16 private constant SC_D = 1025;   // 2,5%
  uint16 private constant SC_C = 1050;   // 5%
  uint16 private constant SC_B = 1100;   // 10%
  uint16 private constant SC_A = 1200;   // 20%
  uint16 private constant SC_S = 1400;   // 40%

  uint private constant BLESSING_MAX_CRIT = 1250; // 25% more
  uint private constant BLESSING_MAX_PWR = 1400; // 40% more
  uint private constant BLESSING_MIN_WEIGHT = 500; // 50% reduction
  uint private constant BLESSING_MAX_SCALING = 1400; // 50% more

  event NewWeapon(address indexed minter, uint256 indexed weapon);

  struct Weapon {
    string name;
    string wtype;
    Attributes.Values requirements;
    uint8 weight;
    uint8 crit;
    uint8 reinforcement;
    Damage power;
    AuxiliaryDamage auxPower;
    Scaling scaling;

    // add everything else
    // https://onedrive.live.com/view.aspx?resid=21B7F6A9C97C5D9A!123&ithint=file%2cxlsx&authkey=!AEhHSWMwAhQdP5o
  }

  struct Damage {
    uint16 phy;
    uint16 magic;
    uint16 fire;
    uint16 light;
    uint16 dark;
  }

  struct AuxiliaryDamage {
    uint16 bleed;
    uint16 poison;
    uint16 frost;
  }

  struct Scaling {
    uint16 str;
    uint16 dex;
    uint16 intt;
    uint16 fth;
  }

  enum RandomizableStats {
    WEIGHT,
    CRIT,
    PWR,
    SCALING
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
    string memory fn = string(abi.encodePacked("_createWeapon", weaponID.toBytes(), "()"));
    (bool ret,) = address(this).call(
      abi.encodeWithSignature(fn)
    ); 
    require(ret, "failure creating weapon");
    require(weapons.length == tokenID + 1, "weapon wasn't pushed to slice");

    _bless(tokenID, seed);
    _safeMint(minter, tokenID);
    emit NewWeapon(minter, tokenID);
  }

  // _bless a weapon based on randoms.
  // TODO: combine seeds with current values on each.
  // There's probably a nicer way to do this, but without switchs and gas expensive stuff I haven't realized yet.
  function _bless(uint tokenID, uint seed) private {
    // Throw the dice to see which stats we are going to bless.
    uint n = seed.rand(1, 1000); // 1000 total chances.
    RandomizableStats[] memory vals = new RandomizableStats[](4); // We will mutate it.
    vals[0] = RandomizableStats.CRIT;
    vals[1] = RandomizableStats.PWR;
    vals[2] = RandomizableStats.SCALING;
    vals[3] = RandomizableStats.WEIGHT;
    if (n <= 500) { // 50% = 0 stat
      vals = new RandomizableStats[](0);
    } else if (n <= 800) { // 30% = 1 stat
      uint i = seed.combine(block.number).rand(0, vals.length-1);
      RandomizableStats d = vals[i];
      vals = new RandomizableStats[](1);
      vals[0] = d;
    } else if (n <= 975) { // 17,5% = 2 stats
      uint i = seed.combine(block.number).rand(1, 1e18);
      uint j = seed.combine(i).rand(0, vals.length-1);
      i = i.mod(vals.length);
      if (i == j) {
        j = j.add(i).mod(vals.length);
      }
      RandomizableStats di = vals[i];
      RandomizableStats dj = vals[j];
      vals = new RandomizableStats[](2);
      vals[0] = di;
      vals[1] = dj;
    } else if (n <= 999) { // 2,49% = 3 stats
      uint i = seed.combine(block.number).rand(0, vals.length-1);
      if (i != vals.length-1) {
        vals[i] = vals[vals.length-1];
      }
      delete(vals[vals.length-1]);
    } // Nothing to do on the most lucky case (0,01% = 4 stats)

    uint ss = seed.combine(block.timestamp);
    for (uint8 i = 0; i < vals.length; i++) {
      ss = ss.combine(i+1); // reseed on each iteration

      if (vals[i] == RandomizableStats.CRIT) {
        // crit blessing is up to 25%
        weapons[tokenID].crit = uint256(weapons[tokenID].crit).mul(ss.rand(1000, BLESSING_MAX_CRIT)).div(1000).toUint8();
      } else if (vals[i] == RandomizableStats.PWR) {
        weapons[tokenID].power.phy = uint256(weapons[tokenID].power.phy).mul(ss.rand(1000, BLESSING_MAX_PWR)).div(1000).toUint16();
        weapons[tokenID].power.magic = uint256(weapons[tokenID].power.magic).mul(ss.rand(1000, BLESSING_MAX_PWR)).div(1000).toUint16();
        weapons[tokenID].power.fire = uint256(weapons[tokenID].power.fire).mul(ss.rand(1000, BLESSING_MAX_PWR)).div(1000).toUint16();
        weapons[tokenID].power.dark = uint256(weapons[tokenID].power.dark).mul(ss.rand(1000, BLESSING_MAX_PWR)).div(1000).toUint16();
        weapons[tokenID].power.light = uint256(weapons[tokenID].power.light).mul(ss.rand(1000, BLESSING_MAX_PWR)).div(1000).toUint16();
      } else if (vals[i] == RandomizableStats.SCALING) {
        weapons[tokenID].scaling.str = uint256(weapons[tokenID].scaling.str).mul(ss.rand(1000, BLESSING_MAX_SCALING)).div(1000).toUint16();
        weapons[tokenID].scaling.dex = uint256(weapons[tokenID].scaling.dex).mul(ss.rand(1000, BLESSING_MAX_SCALING)).div(1000).toUint16();
        weapons[tokenID].scaling.intt = uint256(weapons[tokenID].scaling.intt).mul(ss.rand(1000, BLESSING_MAX_SCALING)).div(1000).toUint16();
        weapons[tokenID].scaling.fth = uint256(weapons[tokenID].scaling.fth).mul(ss.rand(1000, BLESSING_MAX_SCALING)).div(1000).toUint16();
      } else if (vals[i] == RandomizableStats.WEIGHT) {
        weapons[tokenID].weight = uint256(weapons[tokenID].weight).mul(ss.rand(BLESSING_MIN_WEIGHT, 1000)).div(1000).toUint8();
      }
    }
  }

  function _createWeapon1() private {
    weapons.push(
      Weapon(
        "Battle Axe",
        WEAPON_TYPE_AXE,
        Attributes.Values(0, 0, 0, 0, 12, 8, 0, 0, 0),
        4,
        100,
        1,
        Damage(250, 0, 0, 0, 0),
        AuxiliaryDamage(0, 0, 0),
        Scaling(SC_C, SC_D, SC_NAN, SC_NAN)
      )
    );
  }
}
