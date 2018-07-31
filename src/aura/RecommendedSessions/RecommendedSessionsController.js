({
  doInit: function (component, event, helper) {
    var action = component.get("c.getRecommendations");

    action.setParams({
      contactId: component.get("v.recordId"),
      useLocation: component.get("v.useLocation")
    });

    action.setCallback(this, function (response) {
      var state = response.getState();
      if (state === "SUCCESS") {
        var value = JSON.parse(response.getReturnValue());;
        var recs = value.recommendations;
        component.set("v.sessionList", recs.slice(0, 3));
      } else if (state === "INCOMPLETE") {
        console.log(state);
      } else if (state === "ERROR") {
        var errors = response.getError();
        if (errors) {
          if (errors[0] && errors[0].message) {
            console.log("Error message: " +
              errors[0].message);
          }
        } else {
          console.log("Unknown error");
        }
      }
    });
    $A.enqueueAction(action);
  }
})