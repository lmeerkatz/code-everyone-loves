This repository holds demo code for Code Everyone Loves, a session at Dreamforce 2017 designed to help developers think about how to build flexibility into their code.

The code is derived from real code used to power [Volunteerforce](https://www.salesforce.com/blog/2017/11/app-helps-salesforce-employees-change-the-world.html), the employee engagement app Salesforce employees use to give back to organizations they care about. We've taken functionality used for recommending volunteer activities based on employee interests and used them to develop a component to recommend sessions for the Conference Management demo app from Trailhead. 

The session covers 4 ways to change how your code works without changing your code:
* Use formula fields to capture complex attributes
* Give admins control of variables through custom settings, custom metadata types, and design attributes
* Use object-oriented programming patterns to solve problems in a reusable way
* Use dynamic Apex to apply the same solution to multiple sObjects

Resources:
[Trailmix: Mix Everyone Loves](https://bit.ly/mix-everyone-loves) 

Following are summaries of each concept.

## Use formula fields to capture complex attributes

To make our recommendations, we'll take two steps. First, we'll query for all the sessions that might be eligible to be recommended, then we'll run each result through a scoring algorithm to determine which ones are the best fit for the given contact.

Here are two versions of queries to get the eligible sessions:
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

In each WHERE clause, we're filtering on whether a given session should be included in the pool of eligible recommendations. We could think of eligibility as an attribute of each session, but it's a compound attribute determined by other values on the record.

Which one would you rather work with? If you wanted to add another filter to strings that shouldn't be included in the name, which version would more easily allow you to make that change? Which approach would allow you to use this information in another context, like reporting?

Note: You may run into performance issues with either version. You can copy the formula field to a non-formula field using a [scheduled batch](https://github.com/lmeerkatz/df17-event-mgmt/blob/master/src/classes/Recommendations_BatchUpdateSession.cls), then [request a custom index](https://help.salesforce.com/articleView?id=000006007&type=1) on the field for the best performance.

## Give admins control of variables

### Use custom settings or custom metadata types to for variables in logic

After we have the records we might want to include in recommendations, we need to score them based on how well a session matches a contact's interests and other attributes.

We could have written something like this:

```
for (Session__c session : eligibleSessions) {
    if ( /* level matches */ ) {
        score += 5;
    }

    if ( /* topic matches */ ) {
        score += 15;
    }
    // and on and on ...
}
```

That would mean that if we found out later that getting recommendations for their level matters more to our attendees than we originally thought, we'd have to make a change to code.```

Instead we use a custom setting to track factors used in [scoring recommendations](https://github.com/lmeerkatz/df17-event-mgmt/blob/master/src/classes/Recommendations_Sessions.cls#L52). This gives us a flexible way for admins or our future selves to quickly and easily adjust how we weight each factor.

![Screenshot of Recommendation Factor custom settings](https://github.com/lmeerkatz/df17-event-mgmt/blob/master/screenshots/recommendation-factor-custom-setting.png)

Whenever you're working with complex logic that you expect to need to change, consider whether exposing variables via custom settings or custom metadata types. If you find yourself writing a long if/then statement with hard-coded values in each branch, that's a red flag.

### Use design variables to control display options

We also wanted to include distance as a factor in recommendations, but in our demo we hadn't yet set up geocoding on sessions so it didn't make sense to show it yet. So we used a design variable called [useLocation](https://github.com/lmeerkatz/df17-event-mgmt/blob/master/src/aura/RecommendedSessions/RecommendedSessions.design) to decide whether our recommendations component will display the distance between the user and use location as a factor in scoring.

Design variables makes attributes in Lightning Components editable in the Lighting App Builder. It's as easy as defining an attribute just as you normally would, then adding a few additional properties in the design file of your component.

### Use object-oriented programming patterns to solve problems in a reusable way

So now we're ready to set up geocoding. 

In this case, we wanted to use a geocoding service to get the latitude and longitude for our activities so we could factor in distance when making recommendations. But we also knew that we might want to swap out the service for something different in the future. So instead of solving the problem of implementing ABC Geocoding API, we tackled geocoding at a higher level of abstraction.

If you've ever worked with Java, you're likely familiar with interfaces and abstract classes. If you came to Apex through another background you may not be familiar with object-oriented patterns, but it's worth keeping the basics in mind when you're developing a solution that could have multiple variants.

[GEO_IGeocoder](https://github.com/lmeerkatz/df17-event-mgmt/blob/master/src/classes/GEO_IGeocoder.cls) is an interface that defines the basic contract of what a geocoder class should be able to do within our system. 

[GEO_Geocoder](https://github.com/lmeerkatz/df17-event-mgmt/blob/master/src/classes/GEO_Geocoder.cls) is a class that holds an instance of a class that fulfills that contract and contains methods that work with any geocoder class.

[Geocoding_Setting__c](https://github.com/lmeerkatz/df17-event-mgmt/blob/master/src/objects/Geocoding_Settings__c.object) is a custom setting that determines which specific class we want to call and holds settings related to the related service.

When we want to actually make a call for a record to be geocoded, we just call the methods in GEO_Geocoder.

```
public PageReference geocode(){
    (new GEO_Geocoder()).geocodeRecords(new List<Id>{ recordId });

    PageReference ref = new PageReference('/' + recordId);
    ref.setRedirect(true);
    return ref;
}
```

GEO_Geocoder then uses the custom setting to determine which geocoding class will actually make the call. 

```
Type classType = Type.forName(settings.Class__c);
Object classInstance = classType.newInstance();
return (GEO_IGeocoder)classInstance;
```

When we want to implement a class for a new geocoding service, we only have to write methods for the parts that are specific to that service. Those are the methods we defined placeholders for in our interface:

```
String getServiceName();
Boolean supportsBatch();
List<Geocoding_Result__c> geocodeAddresses(List<GEO_Address> addresses);
```
Everything else, like getting the address data to send to the service and saving the results, can be handled by a common utility class that works for all classes that implment GEO_IGeocoder. 

When we decide to swap out ABC Geocoding API for XYZ Geocoding API, we can make the change by switching out the value in the custom setting; references in code don't have to be changed.

Since we've implemented both a demo geocoder (that always returns the same latitude and longitude) and a real geocder that calls the HERE.com Geocoding API, we could update our settings to switch services without touching any of the code that asks for a record to be geocoded.

This pattern is particularly powerful for package developers, who might want to implement a solution for a certain service so their customers have a default option out of the box, but also leave room for a customer to swap out the default service for another service they prefer.

### Use dynamic Apex to apply the same solution to multiple sObjects

We already have geocoding in place for Contacts, but now we want to add it for Session__c. Since we've set up our geocoding logic using [dynamic Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_dynamic.htm), we can do that without making any changes to code.

Dynamic Apex allows us to reference fields by their name. 

For example:

```
Contact c = new Contact(FirstName = 'Amy', LastName = 'Anderson');
System.debug(c.FirstName); // prints Amy
System.debug((String)c.get('FirstName')); // prints Amy
```

This means that if we're doing the same sort of process on multiple objects, we can use dynamic Apex to reuse the code for that process. 

In our example, we have multiple objects that we want to get geolocation data for. Instead of writing different code to parse out address fields from each sObject, we use a custom setting to hold the map of where each part of the address lives on each object. 

```
Geocoding_Field_Map__c contactMap = new Geocoding_Field_Map__c(
    SObject_Name__c = 'Contact',
    Street_Field__c = 'MailingStreet',
    City_Field__c = 'MailingCity',
    State_Field__c = 'MailingState',
    Postal_Code_Field__c = 'MailingPostalCode',
    Country_Field__c = 'MailingCountry',
    Latitude_Field__c = 'Location__Latitude__s',
    Longitude_Field__c = 'Location__Longitude__s'
);

Geocoding_Field_Map__c sessionMap = new Geocoding_Field_Map__c(
    SObject_Name__c = 'Session__c',
    Street_Field__c = 'Street__c',
    City_Field__c = 'City__c',
    State_Field__c = 'State__c',
    Postal_Code_Field__c = 'Postal_Code__c',
    Country_Field__c = 'Country__c',
    Latitude_Field__c = 'Location__Latitude__s',
    Longitude_Field__c = 'Location__Longitude__s'
);
```

We reuse the same code to [get data out of each address field](https://github.com/lmeerkatz/df17-event-mgmt/blob/master/src/classes/GEO_GeocodingHelper.cls#L58) so we can pass it to the geocoder, then we [put the resulting latitude and longitude](https://github.com/lmeerkatz/df17-event-mgmt/blob/master/src/classes/GEO_GeocodingHelper.cls#L111) into the fields we've defined as the location for that data.
