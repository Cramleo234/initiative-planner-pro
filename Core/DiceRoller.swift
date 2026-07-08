import Foundation

public struct DiceRoll: Equatable {
    public var total: Int
    public var detail: String
    public var rolls: [Int]
}

public enum DiceRollerError: LocalizedError, Equatable {
    case invalidExpression
    case tooManyDice
    case invalidSides

    public var errorDescription: String? {
        switch self {
        case .invalidExpression: return "Ungültiger Würfelausdruck"
        case .tooManyDice: return "Zu viele Würfel in einem Ausdruck"
        case .invalidSides: return "Ungültige Würfelseiten"
        }
    }
}

public enum DiceRoller {
    public static func roll(_ expression: String, random: (Int) -> Int = { Int.random(in: 1...$0) }) throws -> DiceRoll {
        var input = expression.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "W", with: "d")
            .replacingOccurrences(of: "w", with: "d")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: " ", with: "")
        guard !input.isEmpty else { return DiceRoll(total: 0, detail: "0", rolls: []) }
        if let number = Int(input) { return DiceRoll(total: number, detail: "\(number)", rolls: []) }
        if !input.hasPrefix("+") && !input.hasPrefix("-") { input = "+" + input }

        let pattern = #"([+-])(?:(\d*)d(\d+)|(\d+))"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        let matches = regex.matches(in: input, range: nsRange)
        guard !matches.isEmpty else { throw DiceRollerError.invalidExpression }

        var cursor = input.startIndex
        var total = 0
        var details: [String] = []
        var allRolls: [Int] = []

        for match in matches {
            guard let fullRange = Range(match.range, in: input), fullRange.lowerBound == cursor else {
                throw DiceRollerError.invalidExpression
            }
            cursor = fullRange.upperBound

            let signText = String(input[Range(match.range(at: 1), in: input)!])
            let sign = signText == "-" ? -1 : 1

            if match.range(at: 3).location != NSNotFound {
                let countRange = Range(match.range(at: 2), in: input)
                let sidesRange = Range(match.range(at: 3), in: input)!
                let countText = countRange.map { String(input[$0]) } ?? ""
                let count = max(1, Int(countText) ?? 1)
                let sides = Int(String(input[sidesRange])) ?? 0
                guard count <= 500 else { throw DiceRollerError.tooManyDice }
                guard sides > 0 else { throw DiceRollerError.invalidSides }

                var local: [Int] = []
                for _ in 0..<count {
                    let roll = max(1, min(sides, random(sides)))
                    local.append(roll)
                    allRolls.append(sign * roll)
                    total += sign * roll
                }
                details.append("\(sign < 0 ? "-" : "+")\(count)d\(sides)[\(local.map(String.init).joined(separator: ","))]")
            } else if match.range(at: 4).location != NSNotFound {
                let valueRange = Range(match.range(at: 4), in: input)!
                let value = Int(String(input[valueRange])) ?? 0
                total += sign * value
                details.append("\(sign < 0 ? "-" : "+")\(value)")
            }
        }
        guard cursor == input.endIndex else { throw DiceRollerError.invalidExpression }
        return DiceRoll(total: total, detail: details.joined().replacingOccurrences(of: #"^\+"#, with: "", options: .regularExpression), rolls: allRolls)
    }
}
