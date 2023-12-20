//
//  GADNativeView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/20.
//

import Foundation
import GoogleMobileAds
import SwiftUI

struct GADNativeView: UIViewRepresentable {
    let model: GADNativeViewModel?
    func makeUIView(context: Context) -> some UIView {
        return UINativeAdView()
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        if let uiView = uiView as? UINativeAdView {
            uiView.refreshUI(ad: model?.model?.nativeAd)
        }
    }
}

struct GADNativeViewModel: Identifiable, Hashable, Equatable {
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
    
    let id: String = UUID().uuidString
    var model: GADNativeModel?
    
    static let none = GADNativeViewModel.init()
}

class UINativeAdView: GADNativeAdView {

    init(){
        super.init(frame: UIScreen.main.bounds)
        setupUI()
        refreshUI(ad: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var adView: UIImageView = {
        let image = UIImageView(image: UIImage(named: "ad_tag"))
        return image
    }()
    
    lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .gray
        imageView.layer.cornerRadius = 6
        imageView.layer.masksToBounds = true
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()
    
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
        label.textColor = .white
        label.numberOfLines = 1
        label.textAlignment = .left
        return label
    }()
    
    lazy var subTitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10.0)
        label.textColor = .white
        label.numberOfLines = 1
        label.textAlignment = .left
        return label
    }()
    
    lazy var installLabel: UIButton = {
        let label = UIButton()
        label.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.setTitleColor(UIColor.white, for: .normal)
        label.layer.cornerRadius = 18
        label.layer.masksToBounds = true
        return label
    }()
}

extension UINativeAdView {
    func setupUI() {
        
        self.layer.cornerRadius = 12
        self.layer.masksToBounds = true
        
        addSubview(installLabel)
        installLabel.frame = CGRectMake(self.bounds.width - 68 - 12, 14, 68, 34)

        addSubview(iconImageView)
        iconImageView.frame = CGRectMake(12, 14, 34, 34)
        
        let width = self.bounds.width - installLabel.bounds.width - 12 - iconImageView.frame.maxX - 8 - 8
        addSubview(subTitleLabel)
        subTitleLabel.frame = CGRectMake(iconImageView.frame.maxX + 8, 36, width, 12)
        
        addSubview(titleLabel)
        titleLabel.frame = CGRectMake(iconImageView.frame.maxX + 8, 14, width - 21 - 10 - 10, 14)

        
        addSubview(adView)
        adView.frame = CGRectMake(titleLabel.frame.maxX + 10, 15, 21, 12)

        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setupUI()
    }
    
    func refreshUI(ad: GADNativeAd? = nil) {
        self.nativeAd = ad
        self.backgroundColor = .white
        self.adView.image = UIImage(named: "ad_tag")
        self.installLabel.setTitleColor(.white, for: .normal)
        self.installLabel.backgroundColor = UIColor(named: "#3654FF")
        self.subTitleLabel.textColor = UIColor(named: "#899395")
        self.titleLabel.textColor = UIColor(named: "#14162C")
        
        self.iconView = self.iconImageView
        self.headlineView = self.titleLabel
        self.bodyView = self.subTitleLabel
        self.callToActionView = self.installLabel
        self.installLabel.setTitle(ad?.callToAction, for: .normal)
        self.iconImageView.image = ad?.icon?.image
        self.titleLabel.text = ad?.headline
        self.subTitleLabel.text = ad?.body
        
        self.hiddenSubviews(hidden: self.nativeAd == nil)
        
        if ad == nil {
            self.isHidden = true
        } else {
            self.isHidden = false
        }
    }
    
    func hiddenSubviews(hidden: Bool) {
        self.iconImageView.isHidden = hidden
        self.titleLabel.isHidden = hidden
        self.subTitleLabel.isHidden = hidden
        self.installLabel.isHidden = hidden
        self.adView.isHidden = hidden
    }
}
