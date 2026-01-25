import Foundation

/// Cron expression for schedule matching
enum CronExpr: Equatable {
    case any                    // "*"
    case exact(Int)             // "5"
    case range(Int, Int)        // "1-5"
    case list([Int])            // "0,15,30,45"
    case step(Int)              // "*/10"
    
    /// Parse a cron field from JSON value
    static func parse(_ value: Any, min: Int, max: Int) -> CronExpr {
        if let num = value as? Int {
            return .exact(num)
        }
        
        guard let str = value as? String else {
            return .any
        }
        
        let s = str.trimmingCharacters(in: .whitespaces)
        
        // Wildcard
        if s == "*" {
            return .any
        }
        
        // Step: "*/N"
        if s.hasPrefix("*/") {
            let stepStr = String(s.dropFirst(2))
            if let step = Int(stepStr), step > 0 {
                return .step(step)
            }
            return .any
        }
        
        // List: "0,15,30,45"
        if s.contains(",") {
            let values = s.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if !values.isEmpty {
                return .list(values)
            }
            return .any
        }
        
        // Range: "1-5"
        if s.contains("-") {
            let parts = s.split(separator: "-")
            if parts.count == 2,
               let start = Int(parts[0].trimmingCharacters(in: .whitespaces)),
               let end = Int(parts[1].trimmingCharacters(in: .whitespaces)),
               start <= end {
                return .range(start, end)
            }
            return .any
        }
        
        // Exact number
        if let num = Int(s) {
            return .exact(num)
        }
        
        return .any
    }
    
    /// Check if a value matches this expression
    func matches(_ value: Int) -> Bool {
        switch self {
        case .any:
            return true
        case .exact(let n):
            return value == n
        case .range(let start, let end):
            return value >= start && value <= end
        case .list(let values):
            return values.contains(value)
        case .step(let step):
            return value % step == 0
        }
    }
}
