// SPDX-License-Identifier: BUSL-1.1
// Copyright Clocktower LLC 2025
pragma solidity ^0.8.28;


library ClockTowerTimeLibrary {

/// @title Clocktower Time Library
/// @author Hugo Marx

 struct Time {
        uint16 dayOfMonth;
        uint16 weekDay;
        uint16 quarterDay;
        uint16 yearDay;
        uint16 year;
        uint16 month;
    }


 //TIME FUNCTIONS-----------------------------------
    /// @notice Converts unix time number to Time struct
    /// @param unix Unix Epoch Time number
    /// @return time Time struct
    function unixToTime(uint256 unix) public pure returns (Time memory time) {
       
        uint256 _days = unix/86400;
        uint16 day;
        uint16 yearDay;
       
        int256 __days = int(_days);

        int256 L = __days + 68569 + 2440588;
        int256 N = 4 * L / 146097;
        L = L - (146097 * N + 3) / 4;
        int256 _year = 4000 * (L + 1) / 1461001;
        L = L - 1461 * _year / 4 + 31;
        int256 _month = 80 * L / 2447;
        int256 _day = L - 2447 * _month / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        uint256 uintyear = uint(_year);
        uint256 month = uint(_month);
        uint256 uintday = uint(_day);

        day = uint16(uintday);        

        uint256 dayCounter;

        //loops through months to get current day of year
        for(uint256 monthCounter = 1; monthCounter <= month; monthCounter++) {
            if(monthCounter == month) {
                dayCounter += day;
            } else {
                dayCounter += getDaysInMonth(uintyear, monthCounter);
            }
        }

        yearDay = uint16(dayCounter);

        //gets day of quarter
        time.quarterDay = getdayOfQuarter(yearDay, uintyear);
        time.weekDay = getDayOfWeek(unix);
        time.dayOfMonth = day;
        time.yearDay = yearDay;
        time.year = uint16(uintyear);
        time.month = uint16(month);
    }

    /// @notice Checks if year is a leap year
    /// @param year Year number
    /// @return  leapYear Boolean value. True if leap year false if not
    function isLeapYear(uint256 year) internal pure returns (bool leapYear) {
        leapYear = ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0);
    }

    /// @notice Returns number of days in month 
    /// @param year Number of year
    /// @param month Number of month. 1 - 12
    /// @dev Month range is 1 - 12
    /// @return daysInMonth Number of days in the month
    function getDaysInMonth(uint256 year, uint256 month) internal pure returns (uint256 daysInMonth) {
        if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
            daysInMonth = 31;
        } else if (month != 2) {
            daysInMonth = 30;
        } else {
            daysInMonth = isLeapYear(year) ? 29 : 28;
        }
    }

    /// @notice Gets numberical day of week from Unixtime number
    /// @param unixTime Unix Epoch Time number
    /// @return dayOfWeek Returns Day of Week 
    /// @dev 1 = Monday, 7 = Sunday
    function getDayOfWeek(uint256 unixTime) internal pure returns (uint16 dayOfWeek) {
        uint256 _days = unixTime / 86400;
        uint256 dayOfWeekuint = (_days + 3) % 7 + 1;
        dayOfWeek = uint16(dayOfWeekuint);

    }

    /// @notice Gets day of quarter
    /// @param yearDays Day of year
    /// @param year Number of year
    /// @return quarterDay Returns day in quarter
    function getdayOfQuarter(uint256 yearDays, uint256 year) internal pure returns (uint16 quarterDay) {
        
        uint256 leapDay;
        if(isLeapYear(year)) {
            leapDay = 1;
        } else {
            leapDay = 0;
        }

        if(yearDays <= (90 + leapDay)) {
            quarterDay = uint16(yearDays);
        } else if((90 + leapDay) < yearDays && yearDays <= (181 + leapDay)) {
            quarterDay = uint16(yearDays - (90 + leapDay));
        } else if((181 + leapDay) < yearDays && yearDays <= (273 + leapDay)) {
            quarterDay = uint16(yearDays - (181 + leapDay));
        } else {
            quarterDay = uint16(yearDays - (273 + leapDay));
        }
    }

    /// @notice Converts unix time to number of days past Jan 1st 1970
    /// @param unixTime Number in Unix Epoch Time
    /// @return dayCount Number of days since Jan. 1st 1970
    function unixToDays(uint40 unixTime) external pure returns(uint40 dayCount) {
        dayCount = unixTime/86400;
    }

    /// @notice Prorates amount based on days remaining in subscription cycle
    /// @param unixTime Current time in Unix Epoch Time
    /// @param dueDay The day in the cycle the subscription is due
    /// @dev The dueDay will be within differing ranges based on frequency. 
    /// @param fee Amount to be prorated
    /// @param frequency Frequency number of cycle
    /// @dev 0 = Weekly, 1 = Monthly, 2 = Quarterly, 3 = Yearly
    /// @return Prorated amount
    function prorate(uint256 unixTime, uint40 dueDay, uint256 fee, uint8 frequency) external pure returns (uint256)  {
        Time memory time = unixToTime(unixTime);
        uint256 currentDay;
        uint256 max;
        uint256 lastDayOfMonth;
        
        //sets maximum range day amount
        if(frequency == 0) {
            currentDay = time.weekDay;
            max = 7;
        //monthly
        } else if (frequency == 1){
            //calculates maximum days in current month
            lastDayOfMonth = getDaysInMonth(time.year, time.month);
            currentDay = time.dayOfMonth;
            max = lastDayOfMonth;
        //quarterly and yearly
        } else if (frequency == 2) {
            currentDay = getdayOfQuarter(time.yearDay, time.year);
            max = 90;
        //yearly
        } else if (frequency == 3) {
            currentDay = time.yearDay;
            max = 365;
        }

        //monthly
        if(frequency == 1) {
            uint256 dailyFee = (fee * 12 / 365);
            if(dueDay != currentDay && currentDay > dueDay){
                    //dates split months
                    fee = (dailyFee * (max - (currentDay - dueDay)));
            } else if (dueDay != currentDay && currentDay < dueDay) {
                    //both dates are in the same month
                    fee = (dailyFee * (dueDay - currentDay));
            }
        }
        //weekly quarterly and yearly
        else if(frequency == 0 || frequency == 2 || frequency == 3) {
            if(dueDay != currentDay && currentDay > dueDay){
                    fee = (fee / max) * (max - (currentDay - dueDay));
            } else if (dueDay != currentDay && currentDay < dueDay) {
                    fee = (fee / max) * (dueDay - currentDay);
            }
        }  
       
        return fee;
    }


}