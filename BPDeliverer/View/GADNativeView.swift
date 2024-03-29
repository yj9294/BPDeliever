//
//  GADNativeView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/20.
//

import Foundation
import GoogleMobileAds
import SwiftUI
import SnapKit

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
    
    lazy var bigImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .gray
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    lazy var playerView: GADMediaView = {
        let view = GADMediaView()
        return view
    }()
    
    lazy var rightView: UIView = {
        let view = UIView()
        return view
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
        label.textAlignment = .center
        return label
    }()
    
    lazy var subTitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10.0)
        label.textColor = .white
        label.numberOfLines = 1
        label.textAlignment = .center
        return label
    }()
    
    lazy var installLabel: UIButton = {
        let label = UIButton()
        label.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.setTitleColor(UIColor.white, for: .normal)
        label.layer.cornerRadius = 14
        label.layer.masksToBounds = true
        return label
    }()
}

extension UINativeAdView {
    func setupUI() {
        
        self.layer.cornerRadius = 12
        self.layer.masksToBounds = true
        self.backgroundColor = UIColor(named: "#F3F8FB")
        
        addSubview(bigImageView)
        bigImageView.snp.makeConstraints { make in
            make.left.bottom.top.equalToSuperview()
            make.width.equalTo(163)
        }
        
        addSubview(playerView)
        playerView.snp.makeConstraints { make in
            make.top.left.right.bottom.equalTo(bigImageView)
        }
        
        addSubview(rightView)
        rightView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.left.equalTo(bigImageView.snp.right).offset(28)
            make.right.equalToSuperview().offset(-28)
        }
        
        rightView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(9)
            make.width.height.equalTo(36)
        }
        
        rightView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(8)
            make.left.right.equalToSuperview()
        }
        
        rightView.addSubview(subTitleLabel)
        subTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.left.right.equalToSuperview()
        }
        
        rightView.addSubview(installLabel)
        installLabel.snp.makeConstraints { make in
            make.top.equalTo(subTitleLabel.snp.bottom).offset(11)
            make.centerX.equalToSuperview()
            make.width.equalTo(102)
            make.height.equalTo(28)
        }
        
        addSubview(adView)
        adView.snp.makeConstraints { make in
            make.top.right.equalToSuperview()
        }
    
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
        self.imageView = self.bigImageView
        self.mediaView = self.playerView
        self.callToActionView = self.installLabel
        self.installLabel.setTitle(ad?.callToAction, for: .normal)
        self.iconImageView.image = ad?.icon?.image
//        self.bigImageView.image = ad?.images?.first?.image
        self.titleLabel.text = ad?.headline
        self.subTitleLabel.text = ad?.body
        
        self.mediaView?.mediaContent = ad?.mediaContent
        
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
