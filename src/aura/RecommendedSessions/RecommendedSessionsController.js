({
	doInit : function(component, event, helper) {
		var action = component.get("c.getRecommendations");
        action.setParams({
            contactId : component.get("v.recordId")
        });
        action.setCallback(this, function(response){
            var recs = response.getReturnValue().recommendations;
            component.set("v.sessionList", recs.slice(0, 3));
        });
        $A.enqueueAction(action);
	}
})