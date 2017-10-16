global with sharing class DescribeUtil {
    global static Boolean isValidFieldName(String objectName, String fieldName) {
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
        if (objectType == null) {
            return false;
        } else {
            return objectType.getDescribe().fields.getMap().containsKey(fieldName);
        }
    }

}