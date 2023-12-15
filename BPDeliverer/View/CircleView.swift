//
//  UICircleView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/8.
//

import Foundation
import SwiftUI

struct CircleView: UIViewRepresentable {
    let progress: [Double]
    let colors: [UIColor]
    let lineWidth: Double
    func makeUIView(context: Context) -> some UIView {
        return CircleProgressView()
    }
    func updateUIView(_ uiView: UIViewType, context: Context) {
        if let view = uiView as? CircleProgressView {
            view.setColors(colors)
            view.setProgress(progress)
            view.setLineWidth(lineWidth)
        }
    }
}

class CircleProgressView: UIView {
    // 灰色静态圆环
    var staticLayer: CAShapeLayer!
    
    // 为了显示更精细，进度范围设置为 0 ~ 1000
    var progress: [Int] = [0]
    var colors: [UIColor] = [.black]
    
    var lineWidth = 4.0

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setProgress(_ progress: [Double]) {
        self.progress = progress.map({
            Int($0 * 1000)
        })
        setNeedsDisplay()
    }
    
    func setLineWidth(_ lineWidth: Double) {
        self.lineWidth = lineWidth
        setNeedsDisplay()
    }
    
    func setColors(_ colors: [UIColor]) {
        self.colors = colors
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        self.layer.sublayers?.forEach({$0.removeFromSuperlayer()})
        if staticLayer == nil {
            staticLayer = createLayer(1000, UIColor(named: "#EAF0F3")!)
        }
        self.layer.addSublayer(staticLayer)
        if colors.count != progress.count {
            return
        }
        var lastProgress = 0
        for index in colors.indices {
            if progress[index] == 0 {
                continue
            }
            let layer = createLayer(progress[index], offset: lastProgress, colors[index])
            self.layer.addSublayer(layer)
            lastProgress = progress[index] + lastProgress
        }
    }
    
    private func createLayer(_ progress: Int, offset: Int = 0, _ color: UIColor) -> CAShapeLayer {
        let of = (CGFloat.pi * 2) * CGFloat(offset) / 1000
        let endAngle = -CGFloat.pi / 2 + (CGFloat.pi * 2) * CGFloat(progress) / 1000  + of
        let startAngle = -CGFloat.pi / 2 + of
        let layer = CAShapeLayer()
        layer.lineWidth = self.lineWidth
        layer.strokeColor = color.cgColor
        layer.fillColor = UIColor.clear.cgColor
        let radius = self.bounds.width / 2 - layer.lineWidth
        let path = UIBezierPath.init(arcCenter: CGPoint(x: bounds.width / 2, y: bounds.height / 2), radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        layer.path = path.cgPath
        return layer
    }

}
