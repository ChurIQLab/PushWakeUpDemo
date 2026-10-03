import UIKit

/// Как событие журнала выглядит на экране.
extension AppEvent.Kind {

    var symbolName: String {
        switch self {
        case .launch: return "power"
        case .push: return "bell.badge.fill"
        case .tap: return "hand.tap.fill"
        case .answer: return "phone.fill"
        case .decline: return "phone.down.fill"
        case .dismiss: return "hand.draw.fill"
        case .screen: return "rectangle.portrait.on.rectangle.portrait"
        case .token: return "key.fill"
        case .permission: return "checkmark.shield.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .launch: return .systemOrange
        case .push: return .systemBlue
        case .tap: return .systemGreen
        case .answer: return .systemGreen
        case .decline: return .systemRed
        case .dismiss: return .systemGray
        case .screen: return .systemTeal
        case .token: return .systemPurple
        case .permission: return .systemGreen
        case .warning: return .systemYellow
        case .error: return .systemRed
        case .info: return .systemGray
        }
    }

    /// Белый символ на цветной плашке — как иконки в «Настройках».
    var badgeImage: UIImage {
        let size = CGSize(width: 30, height: 30)
        let symbol = UIImage(systemName: symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))?
            .withTintColor(.white, renderingMode: .alwaysOriginal)

        return UIGraphicsImageRenderer(size: size).image { _ in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 7).fill()
            if let symbol {
                let origin = CGPoint(x: (size.width - symbol.size.width) / 2, y: (size.height - symbol.size.height) / 2)
                symbol.draw(at: origin)
            }
        }
    }
}
