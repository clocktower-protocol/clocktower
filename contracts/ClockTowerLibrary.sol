// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

library ClockTowerLibrary {

     enum SubType {
        MONTHLY,
        YEARLY
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

    struct SubStruct {
         //map of subscribers
        mapping(bytes32 => address[]) subscribersMap;
    }


     //struct of Subscription indexes
    struct SubIndex {
        bytes32 id;
        uint16 dueDay;
        SubType subType;
    }

   function unixToDays(uint unix) public pure returns (uint16 yearDays, uint16 day) {
       
        uint _days = unix/86400;
       
        int __days = int(_days);

        int L = __days + 68569 + 2440588;
        int N = 4 * L / 146097;
        L = L - (146097 * N + 3) / 4;
        int _year = 4000 * (L + 1) / 1461001;
        L = L - 1461 * _year / 4 + 31;
        int _month = 80 * L / 2447;
        int _day = L - 2447 * _month / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        uint uintyear = uint(_year);
        uint month = uint(_month);
        uint uintday = uint(_day);

        day = uint16(uintday);        

        uint dayCounter;

        //loops through months to get current day of year
        for(uint monthCounter = 1; monthCounter <= month; monthCounter++) {
            dayCounter += _getDaysInMonth(uintyear, month);
        }

        yearDays = uint16(dayCounter);
    }

    function _isLeapYear(uint year) internal pure returns (bool leapYear) {
        leapYear = ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0);
    }

     function _getDaysInMonth(uint year, uint month) internal pure returns (uint daysInMonth) {
        if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
            daysInMonth = 31;
        } else if (month != 2) {
            daysInMonth = 30;
        } else {
            daysInMonth = _isLeapYear(year) ? 29 : 28;
        }
    }

    
    //deletes subscription index from account
    function deleteSubFromAccount(address account, address[] storage subscribers) public {
        
        //deletes index in account
        //address[] storage subscribers = subscribersMap[id];

        uint index2;

        for(uint i; i < subscribers.length; i++) {
            if(subscribers[i] == account) {
                index2 = i;
                delete subscribers[i];
                break; 
            }

            subscribers[index2] = subscribers[subscribers.length - 1];
            subscribers.pop();
        }
    }
    

    

}