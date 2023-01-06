// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "hardhat/console.sol";
//import "./Timelibrary.sol";
//import "./ClockTowerLibrary.sol";

contract ClocktowerPure {

      //checks if value is in array
    function isInTimeArray(uint40 value, uint40[] memory array) external pure returns (bool) {
    
        for(uint i; i < array.length; i++){
            if(array[i] == value) {
                    return true;
            }
        }
        return false; 
    }

    //checks if value is in array
    function isInAddressArray(address value, address[] memory array) external pure returns (bool result) {
        result = false;
        for(uint i; i < array.length; i++){
            if(array[i] == value) {
                    return true;
            }
        }
        return false;
    }

       //converts unixTime to hours
    function unixToHours(uint40 unixTime) external pure returns(uint40 hourCount){
        hourCount = unixTime/3600;
        return hourCount;
    }

    //&&
    //converts hours since merge to unix epoch utc time
    function hourstoUnix(uint40 timeTrigger) external pure returns(uint40 unixTime) {
        unixTime = timeTrigger*3600;
        return unixTime;
    }

}