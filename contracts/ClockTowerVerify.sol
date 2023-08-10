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

        clockSubscribeAddress = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;

    }

    //functions for receiving ether
    receive() external payable{}
    fallback() external payable{}

    //EVENTS
    event VerifyLog(
        bytes32 indexed id,
        address indexed provider,
        uint indexed timestamp,
        string domain,
        string url,
        string email,
        string phone
    );

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

    function checkIfProvider(bytes32 id) view public returns (bool) {

        //require((provider != address(0)));

        ClockTowerSubscribe.Account memory returnedAccount = ClockTowerSubscribe(clockSubscribeAddress).getAccount(msg.sender);

        bool result;

        if(returnedAccount.exists) {
            //checks if subscription is part of account
            for(uint i; i < returnedAccount.provSubs.length; i++) {
                if(returnedAccount.provSubs[i].id == id) {
                    result = true;
                }
            }
        }

       return result;
    } 

    function addVerifyLog(string calldata domain, string calldata url, string calldata email, string calldata phone, bytes32 id) external {

        //checks that msg.sender is provider of subscription
        require(checkIfProvider(id), "1");

        //TODO: add size checks and maybe use bytes instead

        //creates event
        emit VerifyLog(id, msg.sender, block.timestamp, domain, url, email, phone);
    }


    

}