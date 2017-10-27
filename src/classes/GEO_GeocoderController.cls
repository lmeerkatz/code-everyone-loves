/**
* Copyright (c) 2017, Salesforce.org
* @author Laura Meerkatz
* @date 12/28/2016
* @description Page controller for manually requesting that a record be geocoded
*/
public with sharing class GEO_GeocoderController {
    private Id recordId;

    public GEO_GeocoderController() {
        recordId = (Id)ApexPages.currentPage().getParameters().get('id');
    }

    public PageReference geocode(){
        (new GEO_Geocoder()).geocodeRecords(new List<Id>{ recordId });

        PageReference ref = new PageReference('/' + recordId);
        ref.setRedirect(true);
        return ref;
    }

}