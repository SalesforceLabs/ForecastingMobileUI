public with sharing class OppsInForecastCategoryController {
    
    String forecastingItemId = ApexPages.currentPage().getParameters().get('itemId');

    public List<Opportunity> getOppsInForecastingItem() {
        List<Opportunity> ret = [SELECT Id, Name, Amount, Account.Name FROM Opportunity WHERE Id IN 
                                 (select OpportunityId from ForecastingFact WHERE ForecastingItemId=:forecastingItemId)];
        return ret;
    }
    
    

}