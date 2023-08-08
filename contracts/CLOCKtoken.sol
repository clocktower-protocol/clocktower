// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract CLOCKToken is ERC20Permit {

   constructor(uint256 initialSupply) ERC20Permit("CLockTower") ERC20("CLockTower", "CLOCK") {
        _mint(msg.sender, initialSupply);
   }

}