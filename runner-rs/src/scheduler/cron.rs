use std::str::FromStr;
use thiserror::Error;

#[derive(Debug, Clone, PartialEq)]
pub enum CronExpr {
    /// Match any value: "*"
    Any,
    /// Match exact value: "5", "10"
    Exact(u32),
    /// Match range: "1-5"
    Range(u32, u32),
    /// Match list: "0,15,30,45"
    List(Vec<u32>),
    /// Match step: "*/10", "*/15"
    Step(u32),
}

#[derive(Debug, Error)]
pub enum CronParseError {
    #[error("Invalid number: {0}")]
    InvalidNumber(String),
    #[error("Invalid range: {0}")]
    InvalidRange(String),
    #[error("Invalid step: {0}")]
    InvalidStep(String),
    #[error("Value out of range: {value} (expected {min}-{max})")]
    OutOfRange { value: u32, min: u32, max: u32 },
}

impl CronExpr {
    /// Parse a cron expression string
    pub fn parse(s: &str, min: u32, max: u32) -> Result<Self, CronParseError> {
        let s = s.trim();
        
        // Wildcard: "*"
        if s == "*" {
            return Ok(CronExpr::Any);
        }
        
        // Step: "*/N"
        if s.starts_with("*/") {
            let step_str = &s[2..];
            let step: u32 = step_str
                .parse()
                .map_err(|_| CronParseError::InvalidStep(s.to_string()))?;
            if step == 0 {
                return Err(CronParseError::InvalidStep("Step cannot be 0".to_string()));
            }
            return Ok(CronExpr::Step(step));
        }
        
        // List: "0,15,30,45"
        if s.contains(',') {
            let values: Result<Vec<u32>, _> = s
                .split(',')
                .map(|v| {
                    let n: u32 = v.trim().parse()
                        .map_err(|_| CronParseError::InvalidNumber(v.to_string()))?;
                    if n < min || n > max {
                        return Err(CronParseError::OutOfRange { value: n, min, max });
                    }
                    Ok(n)
                })
                .collect();
            return Ok(CronExpr::List(values?));
        }
        
        // Range: "1-5"
        if s.contains('-') {
            let parts: Vec<&str> = s.split('-').collect();
            if parts.len() != 2 {
                return Err(CronParseError::InvalidRange(s.to_string()));
            }
            let start: u32 = parts[0].trim().parse()
                .map_err(|_| CronParseError::InvalidRange(s.to_string()))?;
            let end: u32 = parts[1].trim().parse()
                .map_err(|_| CronParseError::InvalidRange(s.to_string()))?;
            
            if start < min || start > max {
                return Err(CronParseError::OutOfRange { value: start, min, max });
            }
            if end < min || end > max {
                return Err(CronParseError::OutOfRange { value: end, min, max });
            }
            if start > end {
                return Err(CronParseError::InvalidRange(format!("Start {} > end {}", start, end)));
            }
            
            return Ok(CronExpr::Range(start, end));
        }
        
        // Exact number: "5"
        let n: u32 = s.parse()
            .map_err(|_| CronParseError::InvalidNumber(s.to_string()))?;
        if n < min || n > max {
            return Err(CronParseError::OutOfRange { value: n, min, max });
        }
        
        Ok(CronExpr::Exact(n))
    }
    
    /// Check if a value matches this expression
    pub fn matches(&self, value: u32) -> bool {
        match self {
            CronExpr::Any => true,
            CronExpr::Exact(n) => value == *n,
            CronExpr::Range(start, end) => value >= *start && value <= *end,
            CronExpr::List(values) => values.contains(&value),
            CronExpr::Step(step) => value % step == 0,
        }
    }
}

impl FromStr for CronExpr {
    type Err = CronParseError;
    
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        // Default range for generic parsing (will be validated elsewhere)
        CronExpr::parse(s, 0, 59)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_any() {
        assert_eq!(CronExpr::parse("*", 0, 59).unwrap(), CronExpr::Any);
    }

    #[test]
    fn test_parse_exact() {
        assert_eq!(CronExpr::parse("5", 0, 59).unwrap(), CronExpr::Exact(5));
        assert_eq!(CronExpr::parse("0", 0, 23).unwrap(), CronExpr::Exact(0));
        assert_eq!(CronExpr::parse("23", 0, 23).unwrap(), CronExpr::Exact(23));
    }

    #[test]
    fn test_parse_exact_out_of_range() {
        assert!(CronExpr::parse("24", 0, 23).is_err());
        assert!(CronExpr::parse("60", 0, 59).is_err());
    }

    #[test]
    fn test_parse_range() {
        assert_eq!(CronExpr::parse("1-5", 0, 6).unwrap(), CronExpr::Range(1, 5));
        assert_eq!(CronExpr::parse("9-17", 0, 23).unwrap(), CronExpr::Range(9, 17));
    }

    #[test]
    fn test_parse_range_invalid() {
        assert!(CronExpr::parse("5-1", 0, 6).is_err()); // start > end
        assert!(CronExpr::parse("1-7", 0, 6).is_err()); // end out of range
    }

    #[test]
    fn test_parse_list() {
        assert_eq!(
            CronExpr::parse("0,15,30,45", 0, 59).unwrap(),
            CronExpr::List(vec![0, 15, 30, 45])
        );
    }

    #[test]
    fn test_parse_list_out_of_range() {
        assert!(CronExpr::parse("0,15,60", 0, 59).is_err());
    }

    #[test]
    fn test_parse_step() {
        assert_eq!(CronExpr::parse("*/10", 0, 59).unwrap(), CronExpr::Step(10));
        assert_eq!(CronExpr::parse("*/15", 0, 59).unwrap(), CronExpr::Step(15));
    }

    #[test]
    fn test_parse_step_zero() {
        assert!(CronExpr::parse("*/0", 0, 59).is_err());
    }

    #[test]
    fn test_matches_any() {
        let expr = CronExpr::Any;
        assert!(expr.matches(0));
        assert!(expr.matches(30));
        assert!(expr.matches(59));
    }

    #[test]
    fn test_matches_exact() {
        let expr = CronExpr::Exact(15);
        assert!(!expr.matches(0));
        assert!(expr.matches(15));
        assert!(!expr.matches(30));
    }

    #[test]
    fn test_matches_range() {
        let expr = CronExpr::Range(9, 17);
        assert!(!expr.matches(8));
        assert!(expr.matches(9));
        assert!(expr.matches(13));
        assert!(expr.matches(17));
        assert!(!expr.matches(18));
    }

    #[test]
    fn test_matches_list() {
        let expr = CronExpr::List(vec![0, 15, 30, 45]);
        assert!(expr.matches(0));
        assert!(!expr.matches(10));
        assert!(expr.matches(15));
        assert!(expr.matches(30));
        assert!(expr.matches(45));
        assert!(!expr.matches(50));
    }

    #[test]
    fn test_matches_step() {
        let expr = CronExpr::Step(10);
        assert!(expr.matches(0));
        assert!(!expr.matches(5));
        assert!(expr.matches(10));
        assert!(!expr.matches(15));
        assert!(expr.matches(20));
        assert!(expr.matches(50));
    }

    #[test]
    fn test_matches_step_15() {
        let expr = CronExpr::Step(15);
        assert!(expr.matches(0));
        assert!(expr.matches(15));
        assert!(expr.matches(30));
        assert!(expr.matches(45));
        assert!(!expr.matches(10));
        assert!(!expr.matches(20));
    }
}
