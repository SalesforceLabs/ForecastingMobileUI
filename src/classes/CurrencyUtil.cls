public with sharing class CurrencyUtil {
    public static String getCurrencyIsoCode(SObject someObject){
        String currencyIso = UserInfo.isMultiCurrencyOrganization() ? (String) someObject.get('CurrencyIsoCode') : UserInfo.getDefaultCurrency();
        return currencyIso;
    }
    
    public static String getCurrencySymbol(SObject someObject) {
        return getCurrencySymbolFromIso(getCurrencyIsoCode(someObject));
    }
     
    public static String getCurrencySymbolFromIso(String ISO) {
        String currencySymbol = ('USD' == ISO ? '$' : 
        				 ('CAD' == ISO ? '$' : 
        				 ('EUR' == ISO ? '€' : 
        				 ('GBP' == ISO ? '£' : 
        				 ('CNY' == ISO ? '元' : 
        				 ('JPY' == ISO ? '¥' : ISO
        			     ))))));
        return currencySymbol;
    }
    

}