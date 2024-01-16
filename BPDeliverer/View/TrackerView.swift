//
//  TrackerView.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import SwiftUI
import Combine
import ComposableArchitecture
import AppTrackingTransparency

struct TrackerReducer: Reducer {
    struct State: Equatable {
        @UserDefault("guide", defaultValue: false)
        var isGuide: Bool
        
        @UserDefault("measures", defaultValue: [])
        var measures: [Measurement]
        
        @UserDefault("top.mode", defaultValue: .last)
        var topMode: MeasureTopMode
        
        var filterDuration: DateDuration = .init()
        
        var adModel: GADNativeViewModel = .none
    }
    enum Action: Equatable {
        case guide
        case filterDateLastTapped
        case filterDateNextTapped
        case filterDateMinTapped
        case filterDateMaxTapped
        case itemSelected(Measurement)
        case addButtonTapped
        case showAD
        case showGuideAD
        case updateTopMode(MeasureTopMode)
    }
    var body: some Reducer<State, Action> {
        Reduce{ state, action in
            switch action{
            case .guide:
                state.isGuide = true
            case .filterDateLastTapped:
                state.lastFilterDate()
            case .filterDateNextTapped:
                state.nextFilterDate()
            case .addButtonTapped:
                return .run { send in
                    await send(.guide)
                }
            case .showGuideAD:
                let publisher = Future<Action, Never> { promiss in
                    GADUtil.share.load(.guide)
                    GADUtil.share.show(.guide) { _ in
                        promiss(.success(.addButtonTapped))
                    }
                }
                return .publisher {
                    publisher
                }
            case let .updateTopMode(mode):
                if mode != state.topMode {
                    GADUtil.share.load(.trackerExchange)
                    GADUtil.share.show(.trackerExchange)
                    Request.tbaRequest(event: .trackerExchange)
                }
                state.topMode = mode
            default:
                break
            }
            return .none
        }
    }
}

extension TrackerReducer.State {
    
    var filterMeasures: [Measurement] {
        measures.filter { measure in
            measure.date > filterDuration.min.exactlyDay && measure.date < filterDuration.max.exactlyDay
        }
    }
    
    var lastMeasure: Measurement? {
        topMode == .last ? measures.first : avgMeasure
    }
    
    var avgMeasure: Measurement {
        let measures = measures.filter { measure in
            Date().timeIntervalSince1970 -  measure.date.timeIntervalSince1970 < 30 * 24 * 3600
        }
        let sys = measures.map({$0.systolic}).reduce(0, +)
        let dia = measures.map({$0.diastolic}).reduce(0, +)
        let pul = measures.map({$0.pulse}).reduce(0, +)
        if measures.isEmpty {
            return Measurement(systolic: 0, diastolic: 0, pulse: 0)
        } else {
            return Measurement(systolic: sys / measures.count, diastolic: dia / measures.count, pulse: pul / measures.count)
        }
    }
    
    var hasAD: Bool {
        adModel != .none
    }
    
    mutating func lastFilterDate() {
        filterDuration.max = filterDuration.max.addingTimeInterval(-.weak)
        filterDuration.min = filterDuration.min.addingTimeInterval(-.weak)
    }
    mutating func nextFilterDate() {
        filterDuration.max = filterDuration.max.addingTimeInterval(.weak)
        filterDuration.min = filterDuration.min.addingTimeInterval(.weak)
    }
}


struct TrackerView: View {
    let store: StoreOf<TrackerReducer>
    var body: some View {
        WithViewStore(store, observe: {$0}) { viewStore in
            ZStack{
                VStack{
                    MeasureListView(store: store)
                    if viewStore.hasAD {
                        HStack{
                            GADNativeView(model: viewStore.adModel)
                        }.frame(height: 62).padding(.horizontal, 20)
                    }
                }
                AddButtonView(action: {
                    viewStore.send(.addButtonTapped)
                    Request.tbaRequest(event: .trackAdd)
                })
                // 方案判定
                if CacheUtil.shared.getMeasureGuide() == .a {
                    // a 方案是 一次安装首次打开
                    if !viewStore.isGuide {
                        GuideView {
                            viewStore.send(.showGuideAD)
                            Request.tbaRequest(event: .guideAdd)
                            Request.tbaRequest(event: .guideAd)
                        }
                    }
                } else {
                    // b 方案是每次打开判定是否有记录 没得记录都要弹出
                    if viewStore.measures.count == 0 {
                        GuideView {
                            viewStore.send(.showGuideAD)
                            Request.tbaRequest(event: .guideAdd)
                            Request.tbaRequest(event: .guideAd)
                        }
                    }
                }
            }.onAppear {
                viewStore.send(.showAD)
                Request.tbaRequest(event: .track)
            }
        }.background(Color("#F3F8FB")).onAppear {
            ATTrackingManager.requestTrackingAuthorization { _ in
            }
        }
    }
    
    struct MeasureListView: View {
        let store: StoreOf<TrackerReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                ScrollView{
                    VStack(spacing: 0){
                        TopView(store: store).shadow.padding(.horizontal, 20)
                        DateView(store: store).padding(.vertical, 30)
                        LazyVGrid(columns: [GridItem(.flexible())]) {
                            ForEach(viewStore.filterMeasures, id: \.self) { item in
                                VStack{
                                    Button {
                                        viewStore.send(.itemSelected(item))
                                    } label: {
                                        TrackerCell(measure: item, topMode: viewStore.topMode, isTop: false).shadow
                                    }
                                }.padding(.horizontal, 20)
                            }
                        }
                    }.padding(.vertical, 40)
                }
            }
        }
    }
    
    struct AddButtonView: View {
        let action: ()->Void
        var body: some View {
            VStack{
                Spacer()
                HStack{
                    Spacer()
                    Button {
                        action()
                    } label: {
                        Image("tracker_add_1")
                    }.padding(.bottom, 88).padding(.trailing, 24)
                }
            }
        }
    }
    
    struct GuideView: View {
        let action: ()->Void
        var body: some View {
            ZStack{
                Color.black.opacity(0.3).ignoresSafeArea()
                VStack(spacing: 30){
                    HStack{Spacer()}
                    Spacer()
                    VStack(spacing: 0){
                        Image("tracker_guide")
                        Text(LocalizedStringKey("Record blood pressure status")).foregroundStyle(.white).font(.system(size: 17))
                    }
                    Button(action: action) {
                        HStack{
                            Image("tracker_add")
                            Text(LocalizedStringKey("Add")).foregroundStyle(.white).font(.system(size: 16))
                        }.padding(.vertical, 15).padding(.horizontal, 75)
                    }.background(.linearGradient(colors: [Color("#42C3D6"), Color("#5AE9FF")], startPoint: .leading, endPoint: .trailing)).cornerRadius(24)
                    Spacer()
                }
            }.onAppear {
                Request.tbaRequest(event: .guide)
            }
        }
    }
    
    struct TopView: View {
        let store: StoreOf<TrackerReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                if let measure = viewStore.lastMeasure {
                    Button {
                        if viewStore.topMode == .last { 
                            viewStore.send(.itemSelected(measure))
                        }
                    } label: {
                        TrackerCell(measure: measure, topMode: viewStore.topMode, isTop: true) { mode in
                            viewStore.send(.updateTopMode(mode))
                        }
                    }
                }
            }
        }
    }
    
    struct DateView: View {
        let store: StoreOf<TrackerReducer>
        var body: some View {
            WithViewStore(store, observe: {$0}) { viewStore in
                HStack(spacing: 10){
                    Button(action: {viewStore.send(.filterDateLastTapped)}, label: {Image("tracker_last")})
                    HStack(spacing: 0){
                        Button(action: {viewStore.send(.filterDateMinTapped)}, label: {
                            Text(viewStore.filterDuration.min.day)
                        })
                        Text(" ~ ")
                        Button(action: {viewStore.send(.filterDateMaxTapped)}, label: {
                            Text(viewStore.filterDuration.max.day)
                        })
                    }.font(.system(size: 12)).foregroundColor(Color("#BBCDD9")).padding(.all, 10).shadow
                    Button(action: {viewStore.send(.filterDateNextTapped)}, label: {Image("tracker_next")})
                }
            }
        }
    }
    
    struct TrackerCell: View {
        let measure: Measurement
        let topMode: MeasureTopMode
        let isTop: Bool
        var action: ((MeasureTopMode)->Void)? = nil
        
        var body: some View {
            VStack(spacing: 0){
                HStack{
                    if isTop, topMode == .avg {
                        Text("48 Hours average").foregroundStyle(Color.white).font(.system(size: 14.0))
                    } else {
                        HStack(spacing: 8){
                            Image(isTop ? "tracker_date_top" : "tracker_date")
                            Text(measure.date.detail).foregroundStyle(isTop ? Color.white : Color("#BBCDD9")).font(.system(size: 12))
                        }
                    }
                    Spacer()
                    if isTop {
                        TopButtonView(mode: topMode, action: action)
                    }
                }.padding(.all, 14).background(LinearGradient.linearGradient(colors: [Color("#42C3D6"), Color("#5AE9FF")], startPoint: .leading, endPoint: .trailing).clipShape(CustomRoundedRectangle(topLeftRadius: 8, topRightRadius: 8, bottomLeftRadius: 0, bottomRightRadius: 0)).opacity(isTop ? 1.0 : 0.0))
                Color("#E9F0F5").frame(height: 1).padding(.horizontal, 12)
                VStack(spacing: 4){
                    HStack{
                        HStack(alignment: .bottom, spacing: 6){
                            Text(verbatim: "\(measure.systolic)/\(measure.diastolic)").font(.system(size: 32)).foregroundStyle(Color("#194D54"))
                            Text("mmHg").foregroundStyle(Color("#BBCDD9")).font(.system(size: 11)).padding(.bottom, 6)
                        }
                        Spacer()
                        HStack(spacing: 6){
                            Image("tracker_heart")
                            HStack(alignment: .bottom){
                                Text(verbatim: "\(measure.pulse)").font(.system(size: 32)).foregroundStyle(Color("#194D54"))
                                Text("BPM").foregroundStyle(Color("#BBCDD9")).font(.system(size: 11)).padding(.bottom, 6)
                            }
                        }
                    }
                    if isTop, topMode == .avg {
                        Spacer().frame(height: 1)
                    } else {
                        HStack{
                            Text(LocalizedStringKey(measure.status.title)).padding(.vertical,4).padding(.horizontal, 9).background(.linearGradient(colors: [Color(uiColor: measure.status.color), Color(uiColor: measure.status.endColor)], startPoint: .leading, endPoint: .trailing)).cornerRadius(13).foregroundColor(.white).font(.system(size: 14.0))
                            Spacer()
                            HStack(spacing: 0){
                                ForEach(measure.posture, id:\.self) { item in
                                    if case let Measurement.Posture.feeel(feel) = item {
                                        Image(feel.icon)
                                    }
                                    if case let Measurement.Posture.arm(feel) = item {
                                        Image(feel.icon)
                                    }
                                    if case let Measurement.Posture.body(feel) = item {
                                        Image(feel.icon)
                                    }
                                }
                            }
                        }
                    }
                }.padding(.vertical, (isTop && topMode == .avg) ? 25 : 12).padding(.horizontal, 14)
            }
        }
    }
    
    struct TopButtonView: View {
        let mode: MeasureTopMode
        var action: ((MeasureTopMode)->Void)? = nil
        var body: some View {
            HStack(spacing: 0){
                ItemButtonView(title: MeasureTopMode.last.title, isSelected: mode == .last) {
                    action?(.last)
                }
                ItemButtonView(title: MeasureTopMode.avg.title, isSelected: mode == .avg) {
                    action?(.avg)
                }
            }.padding(.all, 2).background(Color("#FFEFE3").cornerRadius(16.0))
        }
        
        struct ItemButtonView: View {
            let title: String
            let isSelected: Bool
            let action: ()->Void
            var body: some View {
                Button(action: action, label: {
                    Text(title).foregroundStyle(isSelected ? Color.white : Color("#C8B8AC")).font(.system(size: 12)).padding(.vertical, 7).padding(.horizontal, 12)
                }).background(isSelected ? Color("#F89042").cornerRadius(14) : Color.clear.cornerRadius(0))
            }
        }
    }
}

enum MeasureTopMode: String,Codable {
   case last, avg
    
    var title: String {
        return self.rawValue.capitalized
    }
}
