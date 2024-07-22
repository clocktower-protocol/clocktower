// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CLOCKToken is ERC20{

   constructor(uint256 initialSupply) ERC20("CLockTower", "CLOCK") {
        _mint(msg.sender, initialSupply);
   }

}