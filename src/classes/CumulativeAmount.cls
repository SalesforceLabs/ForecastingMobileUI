public class CumulativeAmount{
    // This class holds a forecast category and a cumulative attainment
    // amount. For example, if the forecast category is Commit, then 
    // the amount will have Closed + Commit
    public String category {get; set;}
    public Double amount {get; set;}
    public Double quota {get; set;}
    public String forecastTypeStr { get; set; }
   
}