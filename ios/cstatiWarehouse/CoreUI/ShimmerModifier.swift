//
//  ShimmerModifier.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import SwiftUI

struct ShimmerModifier: ViewModifier {

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
            content
                .overlay {
                    GeometryReader { geo in
                        let width = max(geo.size.width, 1)
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.24),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: width * 0.5)
                        .offset(x: -width * 0.35 + CGFloat(t) * width * 1.7)
                        .blendMode(.plusLighter)
                    }
                    .mask(content)
                }
        }
    }
}

extension View {
    func shimmering(_ active: Bool = true) -> some View {
        Group {
            if active {
                modifier(ShimmerModifier())
            } else {
                self
            }
        }
    }
}
