// SPDX-License-Identifier: BUSL-1.1
//Copyright Hugo Marx 2023
//Written by Hugo Marx
pragma solidity ^0.8.21;
import "hardhat/console.sol";

interface ClockTowerSubscribe {
    //acount struct
    struct Account {
        address accountAddress;
        bool exists;
        SubIndex[] subscriptions;
        SubIndex[] provSubs;
    }

     //struct of Subscription indexes
    struct SubIndex {
        bytes32 id;
        uint16 dueDay;
        Frequency frequency;
        Status status;
    }

     enum Frequency {
        WEEKLY,
        MONTHLY,
        QUARTERLY,
        YEARLY
    }

    enum Status {
        ACTIVE,
        CANCELLED,
        UNSUBSCRIBED
    }

    function getAccount(address account) external view returns (Account memory);
}

contract ClockTowerVerify {

     //0.01 eth in wei
    uint public systemFee;

    //admin address
    address payable admin;

    //system fee turned on
    bool allowSystemFee;

    //clockTowerSubscriber contract address
    address clockSubscribeAddress;

    constructor() payable {

        //0.01 eth in wei
        systemFee = 10000000000000000;

        allowSystemFee = false;

        //admin addresses
        admin = payable(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

        clockSubscribeAddress = 0x5FbDB2315678afecb367f032d93F642f64180aa3;

    }

    //functions for receiving ether
    receive() external payable{}
    fallback() external payable{}

    //EVENTS
    event Verify(
        bytes32 indexed id,
        address indexed provider,
        string domain,
        string url,
        string email,
        string phone
    );

    //STRUCTS

     //acount struct
    struct Account {
        address accountAddress;
        bool exists;
        SubIndex[] subscriptions;
        SubIndex[] provSubs;
    }

     //struct of Subscription indexes
    struct SubIndex {
        bytes32 id;
        uint16 dueDay;
        Frequency frequency;
        Status status;
    }

    //ENUMS
     enum Frequency {
        WEEKLY,
        MONTHLY,
        QUARTERLY,
        YEARLY
    }

    enum Status {
        ACTIVE,
        CANCELLED,
        UNSUBSCRIBED
    }

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

    //VERIFICATION FUNCTIONS

    function checkIfProvider(address provider, bytes32 id) isAdmin external returns (bool) {

        ClockTowerSubscribe.Account memory returnedAccount = ClockTowerSubscribe(clockSubscribeAddress).getAccount(provider);
    } 
    

}