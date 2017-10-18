/**
* Copyright (c) 2017, Salesforce.org
* @author Laura Meerkatz
* @date 2017
* @description Builds a list of recommended Session for a given contact based generally on location, preferences,
* and information about the session. Starts by querying for a list of session that are eligible for recommendations,
* then scores and sorts the results.
*/
public with sharing class Recommendations_Sessions extends Recommendations {
    public static final Decimal DEFAULT_SEARCH_RADIUS_MILES = 25;
    private Contact contact { get; set; }

    public Recommendations_Sessions() {
        super();
    }

    @AuraEnabled
    public static Recommendations.Result getRecommendations(Id contactId) {
        return getContactRecommendations(contactId, null);
    }

    @TestVisible
    private static Recommendations.Result getContactRecommendations(Id contactId, Location loc) {
        Recommendations_Sessions instance = new Recommendations_Sessions();
        instance.contact = getContactDetails(contactId);

        Recommendations.Result result = new Recommendations.Result();

        List<Session__c> eligibleSessions = Recommendations_SessionDemoData.getSessionsEligibleForRecommendations();
        List<SessionWrapper> sessionsWithDistance = wrapResults(eligibleSessions);

        List<Recommendation> recommendations = new List<Recommendation>();

        for (SessionWrapper session : sessionsWithDistance) {
            Recommendation rec = instance.scoreResult(session.record, session.distance);
            recommendations.add(rec);
        }
        recommendations.sort();

        result.recommendations = recommendations;
        return result;
    }

    public override Boolean hasFactor(Recommendation_Factor__c factor, SObject record, Decimal distance) {
        if (factor.Name.startsWith('distance')) {
            return hasFactorDistanceWithinNMiles(parseDistance(factor.Name), (Session__c)record);
        } else {
            return hasFactor(factor, record);
        }
    }

    public override Boolean hasFactor(Recommendation_Factor__c factor, SObject record) {
        if (factor.Name == 'popular') {
            return hasFactorPopular((Session__c)record);
        } else if (factor.Name.startsWith('next')) {
            return hasFactorNextNDays(parseNumberOfDays(factor.Name), (Session__c)record);
        } else if (factor.Name == 'topic') {
            return hasFactorPreferredTopic((Session__c)record);
        } else if (factor.Name == 'role') {
            return hasFactorPreferredRole((Session__c)record);
        } else if (factor.Name == 'level') {
            return hasFactorPreferredLevel((Session__c)record);
        } else if (factor.Name.startsWith('distance')) {
            // We're hitting this from the method that doesn't account for distance.
            // This shouldn't cause an exception because the factor name is valid, but this
            // will never return true here.
            return false;
        } else {
            throw new RecommendationsException('Unknown scoring factor: ' + factor.Name);
            return false;
        }
    }

    // A sesssion is considered popular if it is 50% full or more
    private Boolean hasFactorPopular(Session__c session) {
        if (session.Maximum_Attendees__c != null) {
            return (session.Number_of_Attendees__c / session.Maximum_Attendees__c) > .5;
        }
        return false;
    }

    private Boolean hasFactorNextNDays(Integer numberOfDays, Session__c session) {
        return session.Session_Date__c.date().daysBetween(System.today()) <= numberOfDays;
    }

    private Boolean hasFactorDistanceWithinNMiles(Decimal numberOfMiles, Session__c session) {
        if (session.Location__c == null || contact.Mailing_Location__c == null) {
            return false;
        } else {
            return Location.getDistance(session.Location__c, contact.Mailing_Location__c, 'mi') <= numberOfMiles;
        }
    }

    private Boolean hasFactorPreferredTopic(Session__c session) {
        if (session.Topics__c == null || contact.Preferred_Topics__c == null) {
            return false;
        } else {
            Set<String> sessionTopics = new Set<String>(session.Topics__c.split(';'));
            Set<String> preferredTopics = new Set<String>(contact.Preferred_Topics__c.split(';'));
            for (String topic : sessionTopics) {
                if (preferredTopics.contains(topic)) {
                    return true;
                }
            }
        }
        return false;
    }

    private Boolean hasFactorPreferredRole(Session__c session) {
        if (session.Roles__c == null || contact.Preferred_Roles__c == null) {
            return false;
        } else {
            Set<String> sessionRoles = new Set<String>(session.Roles__c.split(';'));
            Set<String> preferredRoles = new Set<String>(contact.Preferred_Roles__c.split(';'));
            for (String role : sessionRoles) {
                if (preferredRoles.contains(role)) {
                    return true;
                }
            }
        }
        return false;
    }

    private Boolean hasFactorPreferredLevel(Session__c session) {
        if (session.Levels__c == null || contact.Preferred_Levels__c == null) {
            return false;
        } else {
            Set<String> sessionLevels = new Set<String>(session.Levels__c.split(';'));
            Set<String> preferredLevels = new Set<String>(contact.Preferred_Levels__c.split(';'));
            for (String level : sessionLevels) {
                if (preferredLevels.contains(level)) {
                    return true;
                }
            }
        }
        return false;
    }

    private static Contact getContactDetails(Id contactId) {
        return [
            SELECT Id, Name
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
    }

    private Decimal parseDistance(String distanceString) {
        String value = distanceString.replaceAll('distance', '').replaceAll('miles', '').replaceAll('_', '.');
        try {
            return Decimal.valueOf(value);
        } catch (TypeException te) {
            throw new RecommendationsException('Can\'t parse distance from factor ' + distanceString);
        }
        return null;
    }

    private Integer parseNumberOfDays(String daysString) {
        String value = daysString.replaceAll('next', '').replaceAll('days', '');
        try {
            return Integer.valueOf(daysString);
        } catch (TypeException te) {
            throw new RecommendationsException('Can\'t parse days from factor ' + daysString);
        }
        return null;
    }

    public class SessionWrapper {
        @AuraEnabled
        public Session__c record { get; set; }

        @AuraEnabled
        public Decimal distance { get; set; }

        SessionWrapper(Session__c record) {
            this.record = record;
        }
    }

    private static List<SessionWrapper> wrapResults(List<Session__c> records) {
        List<SessionWrapper> wrappedRecords = new List<SessionWrapper>();
        for (Session__c record : records) {
            SessionWrapper wrappedRecord = new SessionWrapper(record);
            if (record.Location__Latitude__s != null && record.Location__Longitude__s != null) {
                wrappedRecord.distance = Location.getDistance(
                    Recommendations_SessionDemoData.defaultLocation,
                    Location.newInstance(record.Location__Latitude__s, record.Location__Longitude__s),
                    'mi'
                );
            }
            wrappedRecords.add(wrappedRecord);
        }
        return wrappedRecords;
    }

}
