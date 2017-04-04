//
//  FrequencyView.swift
//  CAMixer
//
//  Created by Matthew S. Hill on 4/3/17.
//  Copyright © 2017 Matthew S. Hill. All rights reserved.
//

import UIKit

class FrequencyView : UIView {
    var barGraphViews: [UIView] = []
    var labelView:UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        self.initializeViews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.initializeViews()
    }
    
    func initializeViews() {
        self.setupBarViews()
        
        self.translatesAutoresizingMaskIntoConstraints = false;
        
        self.labelView = UILabel(frame: CGRect.zero)
        self.labelView.text = "FFT Frequency Spectrum (Guitar)"
        self.labelView.textColor = UIColor.black
        self.labelView.backgroundColor = UIColor.clear
        self.labelView.font = UIFont.systemFont(ofSize: 10.0)
        self.labelView.textAlignment = NSTextAlignment.center
        self.addSubview(self.labelView)
    }
    
    var frequencyValues: Array<Float> = [] {
        didSet(freqVals) {
            updateBarFrames()
        }
    }
    
    func setupBarViews() {
        for _ in 0...256 {
            let view = UIView(frame: CGRect.zero)
            view.backgroundColor = UIColor.black
            barGraphViews.append(view)
            self.addSubview(view)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.labelView.frame = CGRect(x: 0.0, y:0.0, width: self.frame.size.width, height: 20.0)
        updateBarFrames()
    }
    
    func updateBarFrames() {
        //Layout the bars based on the update view frame
        let barWidth = self.frame.size.width / CGFloat(barGraphViews.count)
        
        for i in 0 ..< barGraphViews.count {
            let barView = barGraphViews[i]
            
            var barHeight = CGFloat(0)
            let viewHeight = self.frame.size.height
            if frequencyValues.count > i {
                barHeight = viewHeight * CGFloat(self.frequencyValues[i])
            }
            
            barView.frame = CGRect(x: CGFloat(i) * barWidth, y: viewHeight - barHeight, width: barWidth, height: barHeight)
        }
    }
}
