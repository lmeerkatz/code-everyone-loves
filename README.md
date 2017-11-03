# 5 ways to build change how your code works without changing your code
* Use formula fields to capture complex attributes
* Use custom settings or custom metadata types for variables an admin should be able to control in backend logic
* Use design attributes for variables an admin should be able to control in the UI
* Use object-oriented programming patterns to solve problems in a reusable way
* Use dynamic Apex to apply the same solution to multiple sObjects

## Use formula fields to capture complex attributes

Here are two queries that do the same thing:
```
[
    SELECT Id, Name, Location__c, Location__Latitude__s, Location__Longitude__s,
        Number_of_Attendees__c, Maximum_Attendees__c, Session_Date__c,
        Topics__c, Roles__c, Levels__c, Description__c
    FROM Session__c
    WHERE Session_Date__c >= TODAY AND
        (Maximum_Attendees__c = null OR
            (Open_Slots__c != null AND Open_Slots__c > 0)) // <- this required creating a formula field
            // because we can't compare two fields in a query
        AND Topics__c != null
        AND Name != '%private%'
        AND Name != '%executive track%'
    ORDER BY CreatedDate DESC
    LIMIT 200
];
```
```
[ SELECT Id, Name, Location__c, Location__Latitude__s, Location__Longitude__s,
        Number_of_Attendees__c, Maximum_Attendees__c, Session_Date__c,
        Topics__c, Roles__c, Levels__c, Description__c
    FROM Session__c
    WHERE Include_in_Recommendations__c = true // formula field
    ORDER BY CreatedDate DESC
    LIMIT 200
];
```

Which one would you rather work with? If you wanted to add another filter to strings that shouldn't be included in the name, which version would more easily allow you to make that change?

Note: You may run into performance issues with either version. You can copy the formula field to a non-formula field using a scheduled batch, then request a custom index on the field for the best performance.

## Use custom settings or custom metadata types for variables an admin should be able to control in backend logic

Using a custom setting to track factors used in [scoring recommendations](https://github.com/lmeerkatz/df17-event-mgmt/blob/master/src/classes/Recommendations_Sessions.cls#L52) gives us a flexible way for admins to change the weights of each factor.

![Screenshot of Recommendation Factor custom settings](https://github.com/lmeerkatz/df17-event-mgmt/blob/master/screenshots/recommendation-factor-custom-setting.png)

