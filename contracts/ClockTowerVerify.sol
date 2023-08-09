// SPDX-License-Identifier: BUSL-1.1
//Copyright Hugo Marx 2023
//Written by Hugo Marx
pragma solidity ^0.8.21;
import "hardhat/console.sol";

contract ClockTowerVerify {

     //0.01 eth in wei
    uint public systemFee;

    //admin address
    address payable admin;

    //system fee turned on
    bool allowSystemFee;

    constructor() payable {

        //0.01 eth in wei
        systemFee = 10000000000000000;

        allowSystemFee = false;

        //admin addresses
        admin = payable(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    }

    //functions for receiving ether
    receive() external payable{}
    fallback() external payable{}

    //ADMIN METHODS*************************************

    function adminRequire() private view {
        require(msg.sender == admin, "16");
    }
    
    
    //checks if user is admin
    modifier isAdmin() {
        adminRequire();
        _;
    }

    //Create skim method to get accumulated systemFees
    function collectFees() isAdmin external {

        if(address(this).balance > 5000) {
            admin.transfer(address(this).balance - 5000);
        }
    }   

    function changeAdmin(address payable newAddress) isAdmin external {
       require((newAddress != address(0)));

        admin = newAddress;
    }

    //allow system fee
    function systemFeeActivate(bool status) isAdmin external {
        allowSystemFee = status;
    }

    //change fixed fee
    function changeSystemFee(uint _fixed_fee) isAdmin external {
        systemFee = _fixed_fee;
    }

}