/*
Copyright (c) 2014, salesforce.com, Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
public with sharing class QuotaAttainmentController {
    List<Period> periods = getCurrentPeriods();
    List<Id> periodIds = getPeriodIds(periods);
    Id userId = Id.valueOf(UserInfo.getUserId());
    Date today = Date.today();

    private List<ForecastingType> forecastingTypes = ForecastingTypeUtil.getActiveForecastingTypes();
    private List<ForecastingItem> forecastingItems = getForecastingItems();
    Map<PeriodFtypeKey,ForecastingQuota> forecastingQuotas = getForecastingQuotas();
    // Fetch the list of Forecast categories, starting with the end
    Map<String,Integer> forecastCategoryList = initForecastCategories();

    public QuotaAttainmentController() {
        ForecastingTypeUtil.initTypesMap();
    }
    
    public List<ForecastAttainmentModel> getAttainments() {

        List<ForecastAttainmentModel> attainments = new List<ForecastAttainmentModel>();
        Map<PeriodFtypeKey, ForecastAttainmentModel> attainsmentsByKey = new Map<PeriodFtypeKey, ForecastAttainmentModel>();

        System.debug(periods);
        System.debug(forecastingTypes);
        System.debug(forecastingQuotas);
        System.debug(forecastingItems);
        // Make an ordered set of Attainment records: by period, then by forecasting type 
        for (Period period : periods) {
            for (ForecastingType t : forecastingTypes) {
                for (String productFamily : getActiveProductFamilies()) {
                    // Create an attainment record per product family, but 
                    // only if this ForecastingType is related to product family.
                    
                    if (!isProductFamily(t) && !String.isEmpty(productFamily))
                        continue;
                    
                    PeriodFtypeKey key = new PeriodFtypeKey(period.Id, t.Id, productFamily);
                	ForecastAttainmentModel a = createAttainmentModel(t, period, productFamily);
                    
                    attainments.add(a);
                    attainsmentsByKey.put(key, a);
                    // If there's no associated quota, put in a blank
                    ForecastingQuota q = forecastingQuotas.get(key);
                    if (q != null) {
                        a.quota = q.IsAmount ? q.QuotaAmount : q.QuotaQuantity;
                    }   
                }                
            }
        }
        
        // Go through all the Forecasting Items. Match them to the right attainment
        for (ForecastingItem item : forecastingItems) {
            PeriodFtypeKey key;
            if (String.isEmpty(item.ProductFamily))
                key = new PeriodFtypeKey(item.PeriodId, item.ForecastingTypeId);
            else
                key = new PeriodFtypeKey(item.PeriodId, item.ForecastingTypeId, item.ProductFamily);
            ForecastAttainmentModel a = attainsmentsByKey.get(key);
            if (a == null)
                continue;
            
            Integer categoryPosition = forecastCategoryList.get(item.ForecastCategoryName);
            if (categoryPosition == null)
            continue;
            
            Decimal amount = item.IsAmount ? item.ForecastAmount : item.ForecastQuantity;
            System.debug('Item=' + item + '\nCorresponding attainment=' + a);
            
            if (categoryPosition == 0) {
                a.closedAmount = amount;
                a.closedForecastingItemId = item.Id;
            } else if (categoryPosition == 1) {
                a.commitAmount = amount;
                a.commitForecastingItemId = item.Id;
            } else if (categoryPosition == 2) {
                a.bestcaseAmount = amount;
                a.bestcaseForecastingItemId = item.Id;
            } else {
                continue;
            }
        }
                
        // Remove any blank attainments
        List<ForecastAttainmentModel> ret = new List<ForecastAttainmentModel>();
        for (ForecastAttainmentModel a : attainments) {
            if (a.sumPipeline() > 0 || a.quota > 0)
                ret.add(a);
        } 
        
        return ret;
    }
    
    
    private ForecastAttainmentModel createAttainmentModel(ForecastingType t, Period period, String productFamily) {
        ForecastAttainmentModel a = new ForecastAttainmentModel();
        a.forecastTypeStr = t.MasterLabel;
        if (!String.isEmpty(productFamily))
            a.forecastTypeStr += ' - ' + productFamily;
        else if (isProductFamily(t))
            a.forecastTypeStr += ' - Uncategorized';
             
        a.timeRemainingInPeriod = timeBetweenTwoDates(today, period.EndDate);
        a.unitsPrefix = t.IsAmount ? '$' : '';

        for (String catName : forecastCategoryList.keySet()) {
            Integer catNumber = forecastCategoryList.get(catName);
            if (catNumber == 0) {
                a.closedCategoryStr = catName;                
            } else if (catNumber == 1) {
                a.commitCategoryStr = catName;
            } else if (catNumber == 2) {
                a.bestcaseCategoryStr = catName;
            }
        }
        
        return a;
    }
    
    
    private Map<PeriodFtypeKey, ForecastingQuota> getForecastingQuotas() {
        List<ForecastingQuota> quotas = [SELECT PeriodId, ForecastingTypeId, QuotaAmount, QuotaQuantity, 
                                         IsAmount, IsQuantity, ProductFamily FROM ForecastingQuota
                                         WHERE QuotaOwnerId=:userId AND PeriodId IN :periodIds];
        
        Map<PeriodFtypeKey,ForecastingQuota> ret = new Map<PeriodFtypeKey,ForecastingQuota>();
        for (ForecastingQuota q : quotas) {
            PeriodFtypeKey key;
            if (String.isEmpty(q.ProductFamily))
                key = new PeriodFtypeKey(q.PeriodId, q.ForecastingTypeId);
            else
                key = new PeriodFtypeKey(q.PeriodId, q.ForecastingTypeId, q.ProductFamily);
            
            ret.put(key, q);
        }
        return ret;
    }
        
    private List<ForecastingItem> getForecastingItems() {
        // TODO: Handle adjusted value, owner-only
        
        List<ForecastingItem> items = [SELECT PeriodId, ForecastCategoryName, ForecastingTypeId, IsAmount, 
                                       ForecastAmount, ForecastQuantity, HasAdjustment, ProductFamily
                                       FROM ForecastingItem where OwnerId=:userId AND 
                                       PeriodId IN :periodIds];

         return items;
    }
     
    private List<Period> getCurrentPeriods() {
        List<Period> periods = [SELECT Id, EndDate FROM Period Where Type IN ('Month', 'Quarter') AND 
                                EndDate >= TODAY AND StartDate <= TODAY ORDER BY StartDate];
        return periods;
    }
    
    private List<Id> getPeriodIds(List<Period> periods) {
        List<Id> ret = new List<Id>();
        for (Period p : periods) {
            ret.add(p.Id);
        }
        return ret;
    }
    
    private String timeBetweenTwoDates(Date first, Date second) {
        Integer numberDays = first.daysBetween(second);
        if (numberDays >= 21) {
            return (numberDays/7) + ' weeks left in this period';
        }
        else if (numberDays >= 2) {
            return numberDays + ' days left in this period';
        }
        else if (numberDays == 1) {
            return 'Period ends tomorrow!';
        }
        return 'Period ends today!';
    }
    
    private List<String> getActiveProductFamilies() {
        Schema.DescribeFieldResult f = Schema.sObjectType.Product2.fields.Family;
        List<Schema.PicklistEntry> entries = f.getPicklistValues();
        List<String> ret = new List<String>();
        
        ret.add('');
        
        for (Schema.Picklistentry entry : entries) {
            ret.add(entry.getValue());
        }
        
        return ret;
    }    
    
    private Boolean isProductFamily(ForecastingType t) {
        return t.DeveloperName.contains('LineItem');
    }
    
    private Map<String,Integer> initForecastCategories() {        
      Map<String,Integer> ret = new Map<String,Integer>();
        
      Schema.DescribeFieldResult f = Schema.sObjectType.ForecastingItem.fields.ForecastCategoryName;
      List<Schema.PicklistEntry> picklist = f.getPicklistValues();
      // Sort in reverse order
      Integer found = 0;
      for (Integer i = 1; found<3 && i<picklist.size(); i++) {
          Schema.PicklistEntry p = picklist.get(picklist.size()-i);
          if (p.isActive()) {
              ret.put(p.getLabel(),found++);
          }
      }
        
      return ret;
    }
    
    public class PeriodFtypeKey {
        String code;
        
        public PeriodFtypeKey(Id periodId, Id forecastingTypeId) {
            code = String.valueOf(periodId) + String.valueOf(forecastingTypeId);
        }
        
        public PeriodFtypeKey(Id periodId, Id forecastingTypeId, String productFamily) {
            this(periodId, forecastingTypeId);
            code += productFamily;
        }
        
        public Boolean equals(Object obj) {
            if (obj instanceof PeriodFtypeKey) {
                PeriodFtypeKey p = (PeriodFtypeKey)obj;
                return (p.code.equals(this.code));
            }
            return false;
        }
        
        public Integer hashCode() {
            return (code.hashCode());
        }
    }
    
}