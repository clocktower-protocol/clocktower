// SPDX-License-Identifier: UNLICENSED
//Copyright Hugo Marx 2023
//Written by Hugo Marx
pragma solidity ^0.8.9;

library ClockTowerLibrary {

     enum SubType {
        MONTHLY,
        YEARLY
    }

    //struct of Subscription indexes
    struct SubIndex {
        bytes32 id;
        uint16 dueDay;
        SubType subType;
    }

    //Subscription struct
    struct Subscription {
        bytes32 id;
        uint amount;
        address owner;
        bool exists;
        bool cancelled;
        address token;
        SubType subType;
        uint16 dueDay;
        string description;
        //address[] subscribers;
    }

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

    function setSubscription(uint amount, address token, string memory description, SubType subType, uint16 dueDay) private view returns (Subscription memory subscription){

         //creates id hash
        bytes32 id = keccak256(abi.encodePacked(msg.sender, token, dueDay, description, block.timestamp));

        subscription = Subscription(id, amount, msg.sender, true, false, token, subType, dueDay, description);
    }
    

   

    /*
      enum SubType {
        MONTHLY,
        YEARLY
    }

    
    struct Maps {
        //day of month 
        mapping(uint16 => Subscription[]) monthMap;
        //day of year
        mapping(uint16 => Subscription[]) yearMap;

        //map of subscribers
        mapping(bytes32 => address) subscribersMap;
    }
    

    
    //Subscription struct
    struct Subscription {
        bytes32 id;
        uint amount;
        address owner;
        bool exists;
        address token;
        string description;
        SubType subType;
        uint16 dueDay;
        //address[] subscribers;
    }
    

     //struct of Subscription indexes
    struct SubIndex {
        bytes32 id;
        uint16 dueDay;
        SubType subType;
    }

     //converts unixTime to hours
    function unixToHours(uint40 unixTime) external pure returns(uint40 hourCount){
        hourCount = unixTime/3600;
        return hourCount;
    }
    
    
     //fetches subscription from day maps by id
    function getSubByIndex(SubIndex memory index, Maps storage self) view external returns(Subscription memory subscription){
        
          if(index.subType == SubType.MONTHLY){
            
            Subscription[] memory subList = self.monthMap[index.dueDay];

                //searchs for subscription in day map
                for(uint j; j < subList.length; j++) {
                    if(subList[j].id == index.id) {
                        subscription = subList[j];
                    }
                }
          }
           if(index.subType == SubType.YEARLY){
            Subscription[] memory subList = self.yearMap[index.dueDay];

                //searchs for subscription in day map
                for(uint j; j < subList.length; j++) {
                    if(subList[j].id == index.id) {
                        subscription = subList[j];
                    }
                }
          }

          return subscription;
    }
    

     //sets Subscription
    function setSubscription(uint amount, address token, string memory description, SubType subType, uint16 dueDay) external view returns (Subscription memory subscription){

         //creates id hash
        bytes32 id = keccak256(abi.encodePacked(msg.sender, token, dueDay, description, block.timestamp));

        subscription = Subscription(id, amount, msg.sender, true, token, description, subType, dueDay);
    }

    */
}