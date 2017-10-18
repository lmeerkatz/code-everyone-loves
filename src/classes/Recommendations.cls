/**
* Copyright (c) 2017, Salesforce.org
* @author Laura Meerkatz
* @date 2017
* @description Base class for building recommendations for based generally on location, preferences,
* past interactions, or anything else that can be derived from data in Salesforce. This class contains core methods
* for scoring search results so we can rank recommendations, and getting weights and descriptions from custom settings
* so the weights for determining scoring can be edited by an admin.
*/
public abstract class Recommendations {
    private String callingClass;

    public Recommendations() {}

    public Recommendations(String callingClass) {
        this.callingClass = callingClass;
    }

    /**
    * @description Determines the score for a given record based on record data and distance from a location
    * @param record The record being scored
    * @param distance The distance between the record location and the given location (if available)
    * @return A Recommendation record, which includes the original record and distance, as well as a list of
    * factors that this record matched for scoring
    */
    public Recommendation scoreResult(SObject record, Decimal distance) {
        Recommendation rec = new Recommendation();
        rec.score = 0;
        rec.record = record;
        rec.distance = distance;
        rec.factors = new List<Recommendation_Factor__c>();

        if (factorsByName != null) {
            for (Recommendation_Factor__c factor : factorsByName.values()) {
                Boolean hasFactor = (distance == null && hasFactor(factor, record)) || hasFactor(factor, record, distance);
                if (hasFactor) {
                    rec.score += factor.Score__c;
                    rec.factors.add(factor);
                }
            }
        }
        return rec;
    }

    /**
    * @description Method to be implemented by the extending class that determines whether the given record
    * should be scored based on the given factor
    * @param factor The factor to consider, like whether this record is within a certain distance or the type
    * matches a preferred list of types
    * @param record The record under consideration
    * @return Boolean - true if the record meets the condition in the factor; false if it doesn't
    */
    public abstract Boolean hasFactor(Recommendation_Factor__c factor, SObject record);
    public abstract Boolean hasFactor(Recommendation_Factor__c factor, SObject record, Decimal distance);

    // for the current calling class
    @TestVisible
    private Map<String, Recommendation_Factor__c> factorsByName {
        get {
            factorsByName = new Map<String, Recommendation_Factor__c>();
            if (Recommendations.factorSettingsByClass != null) {
                for (Recommendation_Factor__c factor : Recommendations.factorSettingsByClass.get(callingClass)) {
                    factorsByName.put(factor.Name, factor);
                }
            }
            return factorsByName;
        }
        set;
    }

    private static Map<String, List<Recommendation_Factor__c>> factorSettingsByClass {
        get {
            if (factorSettingsByClass == null) {
                // get all the recommendations and map them by class name
                Map<String, Recommendation_Factor__c> factors = Recommendation_Factor__c.getAll();
                factorSettingsByClass = new Map<String, List<Recommendation_Factor__c>>();
                for (Recommendation_Factor__c factor : factors.values()) {
                    if (factorSettingsByClass.containsKey(factor.Class_Name__c)) {
                        factorSettingsByClass.get(factor.Class_Name__c).add(factor);
                    } else {
                        factorSettingsByClass.put(factor.Class_Name__c, new List<Recommendation_Factor__c>{factor});
                    }
                }
            }
            return factorSettingsByClass;
        }
        set;
    }

    public class Result {
        @AuraEnabled
        public List<Recommendation> recommendations { get; set; }
    }

    public class Recommendation implements Comparable {
        @AuraEnabled
        public SObject record { get; set; }
        @AuraEnabled
        public Decimal distance { get; set; }
        @AuraEnabled
        public Decimal score { get; set; }
        @AuraEnabled
        public List<Recommendation_Factor__c> factors { get; set; }

        //implement compareTo so we can sort by score
        //this will list the records with the highest score first
        public Integer compareTo(Object recordToCompare) {
            Recommendations.Recommendation compareToRecommendation =
                (Recommendations.Recommendation)recordToCompare;
            Integer returnValue = 0;
            if (this.score < compareToRecommendation.score) {
                return 1;
            } else if (this.score > compareToRecommendation.score) {
                return -1;
            }
            return returnValue;
        }
    }

    public class RecommendationsException extends Exception {}

}